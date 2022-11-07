#!/bin/bash
# https://www.ibm.com/docs/en/hpvs/1.2.x?topic=reference-openssl-configuration-examples
# Basic, works, but features are wanting needs more work.


CONF='openssl.conf'

COUNTRY='US'
STATE='VA'
LOCALITY='Richmond'
ORG='IT'
ORGUNIT='Web'
CN='myserver.domain.org'
EMAIL='your@emailhere.org'


usage(){
	cat <<-EOFusage
	Usage: $(basename $0) <command> <command args>
	    Commands:
	    ca	        - Certificate Authority Menu

	    csr 	- Certificate Signing Request
	        csr <client|server> <fqdn> <ip address>

	    keypair         - Generate RSA keypair
	        keypair <DNS or key name without .key> <genrsa> <key bits>
	EOFusage
}

cl_str(){
	local LEN=$2
	[[ "$LEN" = '' ]] && local LEN=2
	if [ "$LEN" -ne "${#1}" ]; then
		echo "error: $(basename $0): $FUNCNAME(): '$1' is '${#1}' character(s) must be '$LEN' character(s)" >&2
		exit 1
	fi
}

gen_root_ca(){
	local CA_NAME="${1:-'root_ca'}"
	[[ ! -d ${CA_NAME} ]] && mkdir ${CA_NAME}

	cat <<-EOFcaconf > ${CONF}
	[ ca ]
	default_ca = CA_LOC

	[ CA_LOC ]
	prompt            = no
	dir               = ${PWD}/${CA_NAME}
	certs             = \$dir/certs
	crl_dir           = \$dir/crl
	new_certs_dir     = \$dir/newcerts
	database          = \$dir/index.txt
	serial            = \$dir/serial
	RANDFILE          = \$dir/private/.rand
	private_key       = \$dir/private/myrootCA.key
	certificate       = \$dir/certs/myrootCA.crt
	crlnumber         = \$dir/crlnum
	crl               = \$dir/crl/mycrl.pem
	default_crl_days  = ${DEFAULT_CRL_DAYS:-30}
	preserve          = no
	policy            = policy
	default_days      = ${DEFAULT_DAYS:-365}

	[ policy ]
	commonName              = supplied
	stateOrProvinceName     = supplied
	countryName             = supplied
	emailAddress            = supplied
	organizationName        = supplied
	organizationalUnitName  = supplied

	[ req ]
	default_bits        = 4096
	distinguished_name  = req_distinguished_name

	string_mask         = utf8only
	default_md          = sha256
	x509_extensions     = v3_ca

	[ req_distinguished_name ]
	countryName                     = ${COUNTRY:-US}
	stateOrProvinceName             = ${STATE:-VA} 
	localityName                    = ${LOCALITY:-'undisclosed'} 
	organizationName                = ${ORG:-'undisclosed'} 
	organizationalUnitName          = ${ORGUNIT:-'undisclosed'} 
	commonName                      = ${CN}
	emailAddress                    = ${EMAIL}

	[ v3_ca ]
	subjectKeyIdentifier = hash
	authorityKeyIdentifier = keyid:always,issuer
	basicConstraints = critical, CA:true
	keyUsage = critical, digitalSignature
	EOFcaconf
}

gen_csr_conf(){
	local type=$1 # Can only be client || server
	cat <<-EOFcsrconf > ${CONF} 
	[ req ]
	prompt                 = no
	days                   = ${DEFAULT_DAYS:-365}
	distinguished_name     = req_distinguished_name
	req_extensions         = v3_req


	[ req_distinguished_name ]
	countryName            = ${COUNTRY:-US} 
	stateOrProvinceName    = ${STATE:-VA}
	localityName           = ${LOCALITY:-'undisclosed'} 
	organizationName       = ${ORG:-'undisclosed'}
	organizationalUnitName = ${ORGUNIT:-'undisclosed'} 
	commonName             = ${CN:-test} 
	emailAddress           = ${EMAIL} 

	[ v3_req ]
	basicConstraints       = CA:false
	extendedKeyUsage       = ${type}Auth
	subjectAltName         = @alt_names

	[ alt_names ]
	IP.0 = ${IP}
	DNS.1 = ${DNS} 
	EOFcsrconf
}


gen_keypair(){
	local name=${1:-emptyname}
	local type=${2:-genrsa}
	local bits=${3:-4096}
	openssl ${type} -out "${name}.key" "${bits}" 
	#openssl genpkey -out "${name}.key" -outform PEM "${bits}" 
}

gen_csr(){
	local name=${1:test}

	if [ "$2" = 'client' ] || [ "$2" = 'server' ]; then
		local type=${2}
	else
		echo "error: $FUNCNAME: invalid certificate type '$2'" >&2;
		exit 1;
	fi
	gen_csr_conf ${type}
	openssl req -new -config ${CONF} -key "${name}.key" -out "${name}.${type}.csr"
}


build_conf(){
	echo
}


[[ "x$1" = 'x' ]] && usage && exit 1;
COMMAND=$1

case $COMMAND in
	keypair) DNS=$2; TYPE=${3:-genrsa}; BITS=${4:-4096};
	gen_keypair ${DNS} ${TYPE} ${BITS};
	;;
	csr) TYPE=$2; DNS=$3; IP=$4;
	     gen_csr ${DNS} ${TYPE};
	;;
	ca) gen_root_ca
	;;
	*) usage; exit 0;
	;;
esac

#disable(){
#while getopts "c:s:l:o:u:d:e:" arg; do
#	case "${arg}" in
#		c) COUNTRY=${OPTARG}; # 2Char
#			cl_str $COUNTRY 2;;
#		s) STATE=${OPTARG} #2Char
#			cl_str $STATE 2;;
#		l) LOCALITY=${OPTARG}
#		;;
#		o) ORG=${OPTARG}
#		;;
#		u) ORGUNIT=${OPTARG}
#		;;
#		d) DOMAIN=${OPTARG}
#		;;
#		e) EMAIL=${OPTARG}
#		;;
#		a) SANS="${OPTARG}"
#		;;
#	esac
#done
#}
#
