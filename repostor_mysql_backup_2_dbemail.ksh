#!/bin/ksh
# ++++++   /home/ccspsql/scripts/repostor_mysql_backup.ksh   ++++++ #
# Backup all MySQL databases.
#
# History
# 27-Jul-17 VV: Create the script for backup of ALL MySQL dbs to TSM.
#
# Start
SERVER=$(hostname | sed s/[.].*$//)
NOTIFY=$HOME/scripts/${SERVER}.txt
export INDEXFILE=/data/mysql/mysql-5.index
echo "========================="
echo "=========================" > $NOTIFY
echo "Start of mysql_backup.ksh on ${SERVER}"
echo "Start of mysql_backup.ksh on ${SERVER}" >> $NOTIFY
date  
date     >> $NOTIFY
echo " "
echo " " >> $NOTIFY
#
# Initialise
EMAIL_VV=uczmvvi@live.ucl.ac.uk
EMAIL_DBA=ms.dbas@live.ucl.ac.uk
SUBJECT="MySQL backup on ${SERVER}"
# WHERE="/data/mysql/mysql-5.6/backup"
WHERE="/home/ccspsql/scripts"
DBLIST=""
#
# ------   Start of procedures   --------------------------- #
#
othererrorproc() {
  if [ $? != "0" ];then
    echo "Error: $1";
    echo "Error: $1" >> $NOTIFY; 
    mailx -s "FAILED: $SUBJECT" $EMAIL_DBA < $NOTIFY
  fi
}
#
errorproc() {
  if [ $? != "0" ];then
    echo "Error: $1";
    echo "Error: $1" >> $NOTIFY; 
    mailx -s "FAILED: $SUBJECT" $EMAIL_DBA < $NOTIFY
    exit $2;
  fi
}
#
CP=/bin/cp
cpfile() {
  if [ $# != "2" ]; then
    othererrorproc "cpfile proc called with $# args. INTERNAL ERROR" 1;
  fi
  "${CP}" "$1" "$2"
}
#
MV=/bin/mv
GZIP=/bin/gzip
mvfile() {
  if [ $# != "2" ]; then
    othererrorproc "mvfile proc called with $# args. INTERNAL ERROR" 1;
  fi
  if [ -f "$1" ]; then
    "${MV}" "$1" "$2"
    "${GZIP}" "$2"
  fi
}
#
backupfiles()
{
  echo "Entering backup 1..."
  "${MYSQL}"  -u tsmbkup -p"${PASSWD}" <<EOF
  flush logs;
  flush query cache;
  flush tables;
EOF

  echo "Entering backup 2..."
  DBLIST=`mysql -u tsmbkup -p"${PASSWD}" -e "show databases \G" | grep '^Database:' | awk '{ print $2 }'`
   
  for i in $DBLIST; do
    if [[ "$i" != "information_schema" || "$i" != "courses-dev" ]]; then
       echo "Entering run..."
       ${DUMP} ${DUMPOPT} -s $i &
       echo "Entering run 2..."
       while true; do
	  PRCCNT=`pgrep mysqlbackup | wc -l` 
          echo $PRCCNT
          if [ "$PRCCNT" -le 6 ];
          then
            break
          else
            sleep 6
          fi
       done
    fi
#  errorproc "using mysqlbackup to create backup with ${DUMP} ${DUMPOPT} > ${CURRENTBACKUPFILE}" 1;

#  ${DUMP} ${DUMPOPTLOGS}  
#  errorproc "using mysqlbackup to create backup with ${DUMP} ${DUMPOPT} > ${CURRENTBACKUPFILE}" 1;
  done
  while true; do
    if [ "`ps -ef | grep -i mysqlbackup | grep -v 'grep'`" = "" ]; then
      ${DUMP} ${DUMPOPT} -l
      break;
    fi
    echo "Backup running ..."
    sleep 2
  done

  echo "Entering backup 3..."
  echo "  " >> $NOTIFY
  ls -al ${CURRENTBACKUPFILE}
  ls -al ${CURRENTBACKUPFILE} >> $NOTIFY 
  echo End of Repostor mysqlbackup at: `date`
  echo End of Repostor mysqlbackup at: `date` >> $NOTIFY

#  rotatebackups;

#  echo "  " >> $NOTIFY
#  ls -alt $WHERE | head -6 | tail -4 
#  ls -alt $WHERE | head -6 | tail -4   >> $NOTIFY 
#  echo End of rotatebackups at: `date`
#  echo End of rotatebackups at: `date` >> $NOTIFY

}


#
# ------   End of procedures   ----------------------------- #
#
# Get root password
# /usr/bin/gpg --passphrase passwd --output ${WHERE}/passwd --decrypt ${WHERE}/password.gpg
echo passwd | /usr/bin/gpg --output ${WHERE}/passwd --batch --passphrase-fd 0 --decrypt ${WHERE}/password.gpg
PASSWD=`/bin/cat ${WHERE}/passwd`
/bin/rm ${WHERE}/passwd
#
# Set parameters.
DATE=/bin/date
CURRENTBACKUPFILE=/home/ccspsql/log/mysqlbackup.log

#
MYSQL=/usr/bin/mysql
DUMP=/opt/repostor/rdp4MySQL/bin/mysqlbackup
DUMPOPT=" -u tsmbkup -p ${PASSWD} -S `hostname`"
# DUMPOPT=" -u tsmbkup -p ${PASSWD} -a"
DUMPOPTLOGS=" -u tsmbkup -p ${PASSWD} -S mysql -l"
#
# ======   Really do the stuff   ====== #
echo "before backupfiles"
backupfiles >>  $NOTIFY  2>>$NOTIFY
echo "after backupfiles"
# ===================================== #
#
echo " "
echo " " >> $NOTIFY
date
date     >> $NOTIFY
echo "End of mysql_backup.ksh"
echo "End of mysql_backup.ksh"   >> $NOTIFY
echo "========================="
echo "=========================" >> $NOTIFY
# mailx -s "$SUBJECT" $EMAIL_VV < $NOTIFY
#
# Transfer files
cd  $HOME/scripts
grep ':Backup of database'  $HOME/scripts/${SERVER}.txt > $HOME/scripts/${SERVER}_send.txt
# mailx -s "$SUBJECT" $EMAIL_VV < $HOME/scripts/${SERVER}_send.txt

success=`grep ':Backup of database'  $HOME/scripts/${SERVER}.txt | grep 'completed succesfully:' | wc -l`
fail=`grep ':Backup of database'  $HOME/scripts/${SERVER}.txt | grep 'failed:' | wc -l`
notknown=`grep ':Backup of database'  $HOME/scripts/${SERVER}.txt | grep -v 'failed:' |  grep -v 'completed succesfully:' | wc -l`
echo "BACKUP OK                       : " $success  > $HOME/scripts/${SERVER}_send2.txt
echo "BACKUP FAILURES                 : " $fail  >> $HOME/scripts/${SERVER}_send2.txt
echo "BACKUP STATUS NOT KNOWN         : " $notknown  >> $HOME/scripts/${SERVER}_send2.txt
if [ $fail -gt 0 ]; then
     SUBJECT2='FAILURES: '$SUBJECT
elif [ $notknown -gt 0 ]; then
     SUBJECT2='UNKNOWN STATUS OF CERTAIN BACKUPS: '$SUBJECT
else
     SUBJECT2='SUCCESSFUL: '$SUBJECT
fi
mv $HOME/scripts/${SERVER}.txt $HOME/scripts/DETAILED_${SERVER}.txt
mv $HOME/scripts/${SERVER}_send.txt $HOME/scripts/SUMMARY_${SERVER}.txt
# mailx -a $HOME/scripts/DETAILED_${SERVER}.txt -a $HOME/scripts/SUMMARY_${SERVER}.txt -s "$SUBJECT2" $EMAIL_DBA < $HOME/scripts/${SERVER}_send2.txt
mailx -a $HOME/scripts/DETAILED_${SERVER}.txt -a $HOME/scripts/SUMMARY_${SERVER}.txt -s "$SUBJECT2" $EMAIL_VV < $HOME/scripts/${SERVER}_send2.txt
mv $HOME/scripts/DETAILED_${SERVER}.txt $HOME/log/DETAILED_${SERVER}_`date +\%d\%b`.txt
#
# ------   /home/ccspsql/scripts/mysql_backup.ksh   ------ #
