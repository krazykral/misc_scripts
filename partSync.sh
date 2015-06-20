#! /bin/sh
# Author: krazyral
# Title: partSync.sh
# Requires: rsync
# Purpose: sync $sDir to partition $mUUID

# Originally used to sync /boot to an equal size partition on another disk
# Run it as a cron job or whenever you like
# as root#: crontab -e
#           @reboot /root/.cron/.bootSync.sh

# UUID of the partition you want to mount and mirror
mUUID='abcdefgh-1234-5678-90ab-c1d2e3f4g5h6'; # UUID for Target partition
sDir='/boot'; # Source directory/partition for sync					


# Verify $mUUID exists
verifyUUID() { 
if [ -z $(blkid | grep "${mUUID}"| tr -d \" |tr   -t = ' ' |  cut -d \  -f3) ]; then
  echo "UUID: ${mUUID}  not found";
  exit 1;
else
  uPart=$(blkid | grep "${mUUID}" | tr -d : | cut -d \  -f1);
fi
}

# mount $mUUID 
mkmount() {
  tDir="/tmp/.$(tr -dc [:alnum:] < /dev/urandom | head -c 8 |xargs -0)";
  mkdir -p "${tDir}";
  mount "${uPart}" "${tDir}";
}

# mirror $sDir
mirrorPart() {
  rsync --checksum --quiet -aAXx --delete "${sDir}" "${tDir}";
  sync;
}

# unmount $mirrorPart
rmmount() {
  umount --force --lazy "${uPart}";
  rmdir "${tDir}"; 
}

verifyUUID ;
mkmount ;
mirrorPart ;
sync;sync;
rmmount ;

