#!/bin/bash
#
# Requires: ffmepg w/ flac support
# Purpose: Convert (wav) to flac and add appropriate metadata based on
# 	   file naming convention:
# 	   <Artist> - <Track> - <Title>

usage(){
	cat <<-EOF
	    usage: $(basename $0) <input file> <album> <4-digit year> 
	EOF
	exit $1
}

[[ "x$1" = 'x' ]] && usage 1
[[ "x$2" = 'x' ]] && usage 1
[[ "x$3" = 'x' ]] && usage 1

E=flac
C=$E
I="$1"
N="${1%.*}"
O="${N}.${E}"

TITLE=$(awk -F" - " '{print $3}' <<< "$N")
ARTIST=$(awk -F" - " '{print $1}' <<< "$N")
ALBUM="$2"
#GENRE
TRACK=$(sed 's/^.*0//' <<< $(awk -F" - " '{print $2}' <<< "$N"))
DATE=$(date --date="Jan 1 $3" +"%FT00:00:00")

testprint(){
	echo "input: $I"
	echo "output: $O"
	echo "filename: $N"
	echo "-------"
	echo "title: $TITLE"
	echo "artist: $ARTIST"
	echo "album: $ALBUM"
	echo "track: $TRACK"
	echo "date: $DATE"
	echo "-------"
	exit 0
}

run(){
	ffmpeg -i "$I" -c:a "$C" -metadata title="$TITLE" -metadata artist="$ARTIST" -metadata album="$ALBUM" -metadata date="$DATE" -metadata track="$TRACK" "${O}"
}

[[ "x$4" = 'x' ]] && testprint 

case $4 in
	run|r) run;;
	dry|d|t) testprint;;
esac
