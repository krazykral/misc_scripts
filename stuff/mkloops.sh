#! /bin/bash
# Purpose: create additional loop devices
# 

usage() {
local self__=`basename $0`;
cat <<-EOFusage
# Create additional Loop devices. 
Usage:
       $self__ <x>               # Will add x number of loop devices after
                                      the highest loop device present.
       $self__  <Start> <Final>  # Takes a range number range. \$1 must be < \$2.

EOFusage
}

devPerms() {
	chown --reference=/dev/loop0 /dev/loop${newDev}; 
	chmod --reference=/dev/loop0 /dev/loop${newDev};
	echo "/dev/loop${newDev}: created successfully";
}

devcount() {
local count="$1"
local lastDev=`for i in /dev/loop*; do echo $i ; done |tr -d '/dev/loop'| sort -nr |head -n 1`
newDev=$lastDev;

while [ $newDev -le $((lastDev + count)) ]; do
	newDev=$((newDev + 1 ));
	local dev="/dev/loop${newDev}"
	mknod -m 0660 "${dev}" b 7 ${newDev};
	devPerms;
done
}

devrange() {
#for newDev in $(seq $1 $2); do
#for newDev in $(eval echo {$1..$2}); do
# belowdoes not work with variable which is why we would use the above
#for newDev in {1..5}; do  
for (( newDev=$1; newDev<=$2; newDev++ )); do
    local dev="/dev/loop${newDev}"
    if [[ ! -e $dev ]]; then
        mknod -m 0660 "${dev}" b 7 ${newDev} ;
        devPerms;
    else
        echo -e "$dev exists.  Skipping!";
    fi
done
}


if  [[ $1 = *[!0-9]* ]] || [[ $2 = *[!0-9]* ]]; then
	echo "Argument(s) must be integers. Try again."
	exit 2;
elif [[ -z $1 ]]; then
	usage;
	exit 0;
elif [[ -n $2 ]]; then
	devrange $1 $2;
else
	devcount $1;
fi

