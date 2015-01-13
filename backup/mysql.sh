#!/bin/bash

## This file is part of the ServerHelper package.
## For the full copyright and license information, please view the LICENSE
## file that was distributed with this source code.

## @author Ansas Meyer <webmaster@ansas-meyer.de>
## @license MIT License

############################################################
## BACKUP CONFIGURATION - EDIT THESE LINES AS YOU LIKE IT ##
############################################################

## variables
SCRIPTDIR=$(cd "$(dirname "$0")" ; pwd -P)
HOMEDIR=${SCRIPTDIR%/script}

SKIP_DATABASES="information_schema mysql performance_schema"

MYSQLDUMP_OPTS="--defaults-file=/etc/mysql/debian.cnf --opt --skip-lock-tables"
GZIP_OPTS="-q -9"

BACKUP_DIR=$HOMEDIR/backup/mysql
BACKUP_SUFFIX=".sql.gz"

############################################################
## YOU SHOULD NOT HAVE TO EDIT ANYTHING BELOW THESE LINES ##
############################################################

## set priority to minimum
renice -19  -p $$ 1>> /dev/null
ionice -c 3 -p $$ 1>> /dev/null

## output functions
log() {
	echo $*
}
die() {
	log "error: $*"
	log "abording!"
	exit 1
}

## checks
if [ $(id -u) -ne 0 ]; then
    die "you have to be root to install project into system"
fi

if [ ! -d $BACKUP_DIR ]; then
	mkdir -p $BACKUP_DIR || die "cannot create directory $BACKUP_DIR"
	chmod 700 $BACKUP_DIR
fi

# get mysql databases
DATABASES=`echo "SHOW DATABASES" | mysql --defaults-file=/etc/mysql/debian.cnf --batch | sed "/^Database$/d;"`

# create backups
for DATABASE in $DATABASES; do
	if [[ $SKIP_DATABASES =~ $DATABASE ]]; then
		continue
	fi

	log "creating backup of database $DATABASE"

	mysqldump $MYSQLDUMP_OPTS $DATABASE \
		| gzip $GZIP_OPTS \
		> ${BACKUP_DIR}/${DATABASE}${BACKUP_SUFFIX} \
	;

	chmod 600 ${BACKUP_DIR}/${DATABASE}${BACKUP_SUFFIX}
done
