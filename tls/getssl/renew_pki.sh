#! /bin/bash
# Purpose: Run GETSSL unprivileged copy files to desired location
# requires: webserver: python3
# WEBSERVER can be any webserver, default: python3 built-in
#
# Configure GETSSL array to your needs
# Configure APPLICATION array to your needs
# Configure FIREWALL array to your needs
# Configure WEBSERVER[port] to your needs 

# Some structures are bound which should be unbound, principally
#   APPLICATION[name] should be split from its service control
# It's sloppy and wanting for logging and failure notices, but it's tested and works


# NOTES
#   GETSSL[email_domain] must be tuned for specific domain/host

#  Needs tuning
# NOTES

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

declare -A FIREWALL 
declare -A GETSSL
declare -A APPLICATION 
declare -A WEBSERVER 

[ "x$1" = 'x' ] && echo error: missing user && exit 1
PKI_BASE='/etc/pki/tls'

APPLICATION[name]=${3:-postfix}
APPLICATION[user]=root
APPLICATION[cert]="${PKI_BASE}/certs/${APPLICATION[name]}.pem"
APPLICATION[key]="${PKI_BASE}/private/${APPLICATION[name]}.key"
#APPLICATION[cert_type]='PEM certificate' # $(which file)
#APPLICATION[key_type]='PEM RSA private key' # $(which file)

# GETSSL
GETSSL[target]=${2:-$(hostname)}
GETSSL[user]=${1} # Unprivileged 
GETSSL[home]=$(grep ${GETSSL[user]} /etc/passwd |cut -f6 -d':')
GETSSL[conf]=${GETSSL[home]}/.getssl/${GETSSL[target]}/getssl.cfg
GETSSL[bin]=${GETSSL[home]}/.bin/getssl
#echo $(ls -l $GETSSL[conf]) #--debug
#exit 0 #--debug
# GETSSL[email_domain]
#  may need more concise filter depending on number of subdomains and
#  desired target (sub)domain for email delivery, perhaps awk
GETSSL[email_domain]=$(rev <<< ${GETSSL[target]} |cut -f1,2 -d'.'|rev)
GETSSL[CA]="https://acme-v02.api.letsencrypt.org"
GETSSL[private_key_alg]="rsa"
GETSSL[email]="support@${GETSSL[email_domain]}"
GETSSL[acl_base_dir]="/var/www/${GETSSL[target]}/web"
GETSSL[acl_location]="${GETSSL[acl_base_dir]}/.well-known/acme-challenge"
GETSSL[cert]="${GETSSL[home]}/.getssl/${GETSSL[target]}/${GETSSL[target]}.crt" 
GETSSL[chain]="${GETSSL[home]}/.getssl/${GETSSL[target]}/chain.crt" 
GETSSL[key]="${GETSSL[home]}/.getssl/${GETSSL[target]}/${GETSSL[target]}.key" 
GETSSL[server_type]="smtps"

# WEBSERVER 
WEBSERVER[bin]="/usr/bin/python3 -m http.server"
WEBSERVER[directory]="--directory ${GETSSL[acl_base_dir]}" # do not modify
WEBSERVER[port]='80'
WEBSERVER[exec]="${WEBSERVER[bin]} ${WEBSERVER[directory]} ${WEBSERVER[port]}"
WEBSERVER[pid]='' # Do not set

# FIREWALL
FIREWALL[zone]=public
FIREWALL[service]=http

# FUNCTIONS
warning(){
	local CODE=${2:-1}
	echo "$(date +'%F %t') $CODE warning: ${1:-"Warning message not configured"}"
	return $CODE 
}

error(){
	local CODE=${2:-1}
	echo "$(date +'%F %t') $CODE error: ${1:-"Error message not configured"}"
	exit $CODE 
}

backup_pki(){
	local PKI_FILE="$1"
	local DATE="$(date +"%F%T")"

	[[ -f ${PKI_FILE} ]] && cp -p ${PKI_FILE}{,.${DATE}} && return 0
         warning "$FUNCNAME: ${APPLICATION[cert]} not backed up" 2
}

manifest_pki_files(){ # UNUSABLE
	# Under SELinux both instances of cert&key default to 
	#  context:  unconfined_u:object_r:cert_t:s0

	# Default root owns cert & ${GETSSL[user]} owns key.
	#  caused by initial run of getssl by CLI as $GETSSL[user]}.
	if [ ! -f ${GETSSL[cert]} ]; then
		touch ${GETSSL[cert]} 
	fi
	# constitute GETSSL[cert] from APPLICATION[cert]?
	# simple cat
	chown ${GETSSL[user]}: ${GETSSL[cert]} 
	chmod 0644 ${GETSSL[cert]} 


	if [ ! -f ${GETSSL[key]} ]; then
		touch ${GETSSL[key]} 
	fi
	# constitute GETSSL[key] from APPLICATION[key]?
	# simple cat
	chown ${GETSSL[user]}: ${GETSSL[key]} 
	chmod 0600 ${GETSSL[key]} 

	# Default root owns cert & key.
	if [ ! -f ${APPLICATION[cert]} ]; then
		touch ${APPLICATION[cert]} 
	fi
	chown ${APPLICATION[user]}: ${APPLICATION[cert]} 
	chmod 0644 ${APPLICATION[cert]} 

	if [ ! -f ${APPLICATION[key]} ]; then
		touch ${APPLICATION[key]} 
	fi
	chown ${APPLICATION[user]}: ${APPLICATION[key]} 
	chmod 0600 ${APPLICATION[key]} 
}

update_pki(){
	case $1 in
		cert) cat ${GETSSL[cert]} > ${APPLICATION[cert]}; 
			cat ${GETSSL[chain]} >> ${APPLICATION[cert]}
			;;
		key) cat ${GETSSL[key]} > ${APPLICATION[key]}; 
			;;
		*) echo "$FUNCNAME: error: invalid parameter \"$1\"";
			;;
	esac
}

revoke_pki(){
	#getssl -r path/to/cert path/to/key [CA_server]
	sudo -u ${GETSSL[user]} ${GETSSL[bin]} -r #<if application service has new cert, determine latest APPLICATION[cert&key]>
	#INCOMPLETE - not required
}

configure_getssl(){
	if [ ! -f ${GETSSL[bin]} ]; then
		if [ ! -d $(dirname ${GETSSL[bin]}) ]; then
			sudo -u ${GETSSL[user]} mkdir -p $(dirname ${GETSSL[bin]})
		fi
		curl --silent https://raw.githubusercontent.com/srvrco/getssl/latest/getssl > ${GETSSL[bin]};
		chown ${GETSSL[user]}: ${GETSSL[bin]}
		chmod 700 ${GETSSL[bin]}
	fi
}

getssl_conf(){
	local CONF="${GETSSL[conf]}"
	local ACL_LOCATION="${GETSSL[acl_location]}"
	local PRIVATE_KEY_ALG="${GETSSL[private_key_alg]}"
	local CA="${GETSSL[CA]}"
	local EMAIL="${GETSSL[email]}"
	local DOMAIN_CERT_LOCATION="${GETSSL[cert]}"
	local DOMAIN_KEY_LOCATION="${GETSSL[key]}" 
	local SERVER_TYPE="${GETSSL[server_type]}"
	local DATE=$(date +'%F%T')

	if [ -f ${CONF} ]; then
		cp -p ${CONF}{,.${DATE}}

	elif [ ! -d $(dirname ${CONF}) ]; then
		mkdir -p $(dirname ${CONF})

		chown ${GETSSL[user]}: $(dirname ${CONF}) $(dirname $(dirname ${CONF}))
		chmod 0775 $(dirname ${CONF}) $(dirname $(dirname ${CONF}))
	fi

	cat <<-EOFconf > ${CONF}
	CA="${CA}"
	PRIVATE_KEY_ALG="${PRIVATE_KEY_ALG}"
	ACCOUNT_EMAIL='${EMAIL}'
	ACL=('${ACL_LOCATION}')
	USE_SINGLE_ACL="true"
	DOMAIN_CERT_LOCATION="${DOMAIN_CERT_LOCATION}" # this is domain cert
	DOMAIN_KEY_LOCATION="${DOMAIN_KEY_LOCATION}" # this is domain key
	SERVER_TYPE="${SERVER_TYPE}"
	EOFconf
}

getssl_exec(){
	configure_getssl
	if [ -d ${GETSSL[home]}/.getssl ]; then
		sudo -u ${GETSSL[user]} ${GETSSL[bin]} -c "${GETSSL[target]}"
	fi
	getssl_conf
	sudo -u ${GETSSL[user]} ${GETSSL[bin]} "${GETSSL[target]}"
}

toggle_firewall(){
	local ZONE=${2:-${FIREWALL[zone]}}
	local SERVICE=${3:-${FIREWALL[service]}}

	case $1 in 
		open) firewall-cmd --zone ${ZONE} --add-service=${SERVICE} --permanent;
			;;
		close) firewall-cmd --zone ${ZONE} --remove-service=${SERVICE} --permanent;
			;;
		*) echo "$FUNCNAME: error: invalid parameter: \"$1\"";
			;;
	esac

	firewall-cmd --reload
}

start_webserver(){
	if [ ! -d ${GETSSL[acl_location]}} ]; then
		mkdir -p ${GETSSL[acl_location]};
	fi
	chown ${GETSSL[user]}: -R ${GETSSL[acl_base_dir]}

	( toggle_firewall open ) &
	sleep .1
	( ${WEBSERVER[exec]} ) &
	WEBSERVER[pid]="$!" 
}

stop_webserver(){
	( toggle_firewall close ) &
	kill -9 ${WEBSERVER[pid]:-$(ps -ef |grep ${WEBSERVER[bin]} |grep ${WEBSERVER[directory]} |grep -v grep |awk '{print $2}')}
}

ss -anop |grep -q ":${WEBSERVER[port]}"
[[ $? -eq 0 ]] && echo "error: webserver port \"${WEBSERVER[port]}\" in use" && exit 1
start_webserver

backup_pki "${APPLICATION[cert]}" 
backup_pki "${APPLICATION[key]}"

##manifest_pki_files # this may be destructive

getssl_exec

update_pki cert
update_pki key

systemctl restart ${APPLICATION[name]}

stop_webserver
