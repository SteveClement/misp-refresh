#!/bin/bash

# This script was written for ubuntu 18.04
# The goal is to delete oldest records in the logs' table on a misp instance.


folder_dest=/var/logs/misp
dbname=misp
# Minimum security, for avoiding password in clear text in the process. 
# One short tutorial on this method: https://easyengine.io/tutorials/mysql/mycnf-preference/
dbfile=/home/misp/.my.cnf

# get today minus 6 month
dateforcleaning=$(date +'%Y-%m-%d' --date='-6 month')
#now=$(date +'%Y-%m-%d %')

# purge logs
query1='select count(*) from logs where date(created) <"'$dateforcleaning'";'
query2='delete from logs where date(created) < "'$dateforcleaning'";'
#echo $query

tmp=$(mysql --defaults-file=$dbfile $dbname -N -e "$query1")
mysql --defaults-file=$dbfile $dbname -N -e "$query2"
if [[ $? != 0 ]]
then
    echo "Error in log purge"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $tmp lines in logs table before $dateforcleaning - ERROR during deletion" >> $folder_dest/cleaning_6month.log
    exit 1
else
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $tmp lines in logs table before $dateforcleaning - Record deleted" >> $folder_dest/cleaning_6month.log
    exit 0
fi
             
