#!/bin/sh

cd /data/backup

DIRS="/apps/prod/tomcat5_indaba/ /data/http_root/html /data/prod/images/ /data/prod/upload/"

# take a db dump first
mysqldump -u root -S /data/prod/mysql/mysql.sock indaba > /data/backup/indaba.sql.backup
gzip indaba.sql.backup

# take a daily incremental for files
find $DIRS -mtime -1  -and ! -name \*\.log*  -and ! -name logs -and ! -name \*\.out* | tar czvf incr.tgz -T -

date=`date "+%Y%m%d"`
mon=`date "+%Y%m"`
#mkdir -p /data/s3_backups/$mon

case $(date "+%d") in
	01)	#cp -p /data/backup/indaba.sql.backup.gz /data/backup/indaba.sql.backup.month
		# copy db backup to S3
		aws s3 cp  /data/backup/indaba.sql.backup.gz s3://indaba_backups/db/indaba.sql.${date}.gz
		# create monthly full backup
		find $DIRS ! -name \*\.log*  -and ! -name logs -and ! -name \*\.out* | tar czvf - -T - | aws s3 cp - s3://indaba_backups/$mon/full.tar.gz
		;;
	*)	break;;
esac

case $(date "+%u") in
	7)	#cp -p /data/backup/indaba.sql.backup /data/backup/indaba.sql.backup.week
		# weekly incremental backup
		find $DIRS -mtime -7 -and ! -name \*\.log*  -and ! -name logs -and ! -name \*\.out* |tar czvf - -T - | aws s3 cp - s3://indaba_backups/$mon/incr.$date.tgz
		;;
	*)	break;;
esac

# Now move the daily backup to daily
aws s3 mv /data/backup/indaba.sql.backup.gz s3://indaba_backups/daily/indaba.sql.backup.${date}.gz

aws s3 mv /data/backup/incr.tgz s3://indaba_backups/daily/incr.${date}.tgz

find /data/s3_backups/daily -type f -and -mtime +30 -exec rm -fr {} \;