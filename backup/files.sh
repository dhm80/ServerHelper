#!/bin/sh

## This file is part of the ServerHelper package.
## For the full copyright and license information, please view the LICENSE
## file that was distributed with this source code.

## @author Ansas Meyer <webmaster@ansas-meyer.de>
## @license MIT License

############################################################
## BACKUP CONFIGURATION - EDIT THESE LINES AS YOU LIKE IT ##
############################################################

## target base path (will contain folders "daily.{0,x}" and "log" later!)
TARGET_PATH="/path/to/backup/files/in/"

## number of rotations to keep (usualy number of days)
## note that you have to delete older versions manually if you descrese amount
ROTATIONS_TO_KEEP="7"

SOURCE_HOST="my-server.com"
SOURCE_PORT="22"
SOURCE_USER="root"
SOURCE_PATH="/"

## private backup rsa key (public part of this key must be put in authorized_keys on source server)
SSH_KEY_FILE="/path/to/ssh/key/private.key"

## rsync parameters (only set pure rsync args telling what you want to sync here)
## note that source, target & ssh connection will be set in backup part later
RSYNC_ARGS=" \
	--archive \
	--delete \
	--delete-excluded \
	--numeric-ids \
	--include="/etc" \
	--include="/home" \
	--include="/root" \
	--exclude="/*" \
	--exclude="*.log" \
	--exclude="**/log/*" \
	--exclude="**/tmp/*" \
	--compress \
"

############################################################
## YOU SHOULD NOT HAVE TO EDIT ANYTHING BELOW THESE LINES ##
############################################################

## helper function to keep time tracking of backups
log() {
	echo "[$(date +%Y-%m-%d\ %H:%M:%S)]: $*"
}

############################################################

## sanitize paths (remove trailing slashes)
TARGET_PATH=${TARGET_PATH%/}
SOURCE_PATH=${SOURCE_PATH%/}

## set log path & file
LOG_PATH="${TARGET_PATH}/log"
LOG_FILE="${LOG_PATH}/backup.log"

## create log directory (if not exists)
if [ ! -d $LOG_PATH ]; then
	mkdir $LOG_PATH
	chmod 777 $LOG_PATH
fi

############################################################

## redirect all output to log file (stdout & stderr)
exec 1>>$LOG_FILE
exec 2>&1

log "starting backup"

## change to target path
log "switching into backup target directory $TARGET_PATH"
cd $TARGET_PATH || exit 1;

############################################################

## rotate part (executed if arg "rotate" is set at any point of script call)
if echo $* | grep -iq rotate; then

	log "performing 'rotate'"

	## delete backup that is too old
	if [ -d daily.$ROTATIONS_TO_KEEP ]; then
		log "deleting oldest backup daily.$ROTATIONS_TO_KEEP"
		rm -rf daily.$ROTATIONS_TO_KEEP || exit 1
	fi

	## rotate
	for old in `seq $ROTATIONS_TO_KEEP -1 0`; do
		## check if dir we want to move exists
		[ ! -d "daily.$old" ] && continue;

		new=$(($old + 1));

		log "rotating daily.$old to daily.$new"
		mv daily.$old daily.$new || exit 1
	done

	## create new backup copy to sync in later (daily.0)
	## create hardlinks for all files to save disk space
	if [ -e daily.1 ]; then
		log "preparing new current backup directory daily.0"
		cp -al daily.1 daily.0 || exit 1
		touch daily.0
	fi
fi

############################################################

## backup part (executed if arg "backup" is set at any point of script call)
if echo $* | grep -iq backup; then

	log "performing 'backup'"

	FINAL_TARGET_PATH=${TARGET_PATH}/daily.0

	## create directory to sync in if not exists (daily.0)
	if [ ! -d "daily.0" ]; then
		log "creating current backup directory daily.0 (initial backup)"
		mkdir $FINAL_TARGET_PATH || exit 1
		chmod 777 $FINAL_TARGET_PATH || exit 1
		touch $FINAL_TARGET_PATH
	fi

	## sync
	log "syncing into daily.0"
	/usr/syno/bin/rsync \
		--rsh="ssh -p $SOURCE_PORT -i $SSH_KEY_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error" \
		$RSYNC_ARGS \
		$SOURCE_USER@$SOURCE_HOST:$SOURCE_PATH/ \
		$FINAL_TARGET_PATH
fi

############################################################

log "backup completed"
echo "************************************************************"

