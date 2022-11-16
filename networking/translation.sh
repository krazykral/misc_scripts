#!/bin/bash

to_ptr(){
	[ "x$1" = 'x' ] && echo 'error: please provide and ip address' >&2 && exit 1
	local ip=($(tr -t '.' ' ' <<< "$1"))
	#echo -n "$(printf '%s\n' "${ip[@]}"| tac| tr '\n' '.'|sed 's/\.$//').in-addr.arpa"
	echo -n "$(printf '%s\n' "${ip[@]}"| tac| xargs |sed 's/ /./g').in-addr.arpa"
}
