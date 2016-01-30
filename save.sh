#/bin/bash

mix clean
set -x
cdate=$(date +"%Y%m%d_%H%M")
tar -cf /media/francois/SD\ BACKUP/andycot_phoenix_${cdate}_$1.tar .
