#!/bin/bash
#
# Usage: ./MySQL_Backup.sh -u root -p Your-pass -h localhost -d my_db -b /mnt/nfs/backup/dbs
#

# Get supplied arguments
while getopts u:p:h:d:b: option
do
case "${option}"
in
u) USER=${OPTARG};;
p) PASSWORD=${OPTARG};;
h) HOST=${OPTARG};;
d) DATABASE=${OPTARG};;
b) BACKUP_PATH=${OPTARG};;

esac
done

date=$(date +"%d-%b-%Y")

# Set default file permissions
umask 177

# Dump database into SQL file
mysqldump --user=$USER --password=$PASSWORD --host=$HOST $DATABASE > $BACKUP_PATH/$DATABASE-$date.sql

# Delete files older than 30 days
find $BACKUP_PATH/* -mtime +30 -exec rm {} \;
