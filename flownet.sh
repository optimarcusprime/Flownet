#!/bin/bash
#
# Alex Marcus
# Flownet : Automated Networked Backup and Restoration
# Fall 2009
# Connecticut College Computer Science 495
# amarcus@conncoll.edu


#### Flowlog method
# flowlog message
flowout () {
    echo $1 >>/home/flownet/flowlog.txt
}

#### Backup method
# backup servername
backup() {
    flowout "Attempting to backup ${1}..."

    # Possible first-ever backup, attempt to create backup folder (suppressing output)
    mkdir ./backups/ 2>/dev/null
    
    # Set date as the current date in the format MM-DD-YYYY-HH:MM:SS
    date=`date +%m-%d-%Y-%T`

    # Set BACKUPTO as location of backup folder
    BACKUPTO=./backups/backup-$1.$date
    
    # Check if prior backup folder exists
    ls ./backups/backup-$1.* 2>/dev/null
    if [ $? -eq 0 ]
    then
	# Set LASTBACKUP as last modified backup directory
	LASTBACKUP=`ls -t -r -1 -d ./backups/*/ | tail -n 1`

	flowout "Prior backup for ${1} exists at ${LASTBACKUP}!"
	
	flowout "Creating new backup folder for ${1} at ${BACKUPTO}..."

	# Create server.date folder with previous backup data
        cp -rf --preserve=all $LASTBACKUP $BACKUPTO
	
	flowout "Syncing remote data at ${1}:${BACKUP} with previous backup..."

	# rsync previous backup directory with files in desired backup folder
	# -a = archive mode for symbolic link, devices, attributes, permissions, and ownership preservation, same as -rlptgoD (no -H)
	# -q = quiet mode, no output exept errors
	# -z = compression to reduce size of data portions
	# --delete = delete files that were removed from source
	rsync -aqz --delete $1:$BACKUP $BACKUPTO

	if [ $? -eq 0 ] # This checks the exit code of rsync, 0 = OK
	then
	    
	    flowout "Backup of ${1}:${BACKUP} to ${BACKUPTO} was successful!  Moving to next server..."
	    
	else

	    flowout "Backup of ${1}:${BACKUP} to ${BACKUPTO} failed with error code ${?}!  Moving to next server..."
	fi

    else
	flowout "Prior backup for ${1} does not yet exist!  Creating backup folder ${BACKUPTO}"

	# Create backup folder
	mkdir $BACKUPTO

        # rsync to new backup directory with files in desired backup folder
	# -a = archive mode for symolic link, devices, attributes, permissions, and ownership preservation, same as -rlptgoD (no -H)
	# -r = recursive mode
	# -q = quiet mode, no output exept errors
	# -z = compression to reduce size of data portions
	rsync -arqz $1:$BACKUP $BACKUPTO
	
	if [ $? -eq 0 ] # This checks the exit code of rsync, 0 = OK
	then
	    
	    flowout "Backup of ${1}:${BACKUP} to ${BACKUPTO} was successful!  Moving to next server..."
	    
	else

	    flowout "Backup of ${1}:${BACKUP} to ${BACKUPTO} failed with error code ${?}!  Moving to next server..."
	fi

    fi
}


#### Restore method
# restore servername
restore() {
    flowout "Attempting to restore ${1}..."

    # Check if prior backup folder exists (suppressing output)
    ls ./backups/backup-$1.* >/dev/null
    if [ $? -eq 0 ]
    then
	# Set lastbackup as last modified backup directory
	LASTBACKUP=`ls -t -r -1 -d ./backups/backup-${1}.* | tail -n 1`

	flowout "Prior backup for ${1} exists at ${LASTBACKUP}!"
    
	flowout "Attempting to restore files from ${LASTBACKUP} to remote location ${1}:${RESTORE}..."

	# rsync previous backup directory with desired location on remote server
	# -a = archive mode for symolic link, devices, attributes, permissions, and ownership preservation, same as -rlptgoD (no -H)
	# -r = recursive mode
	# -q = quiet mode, no output exept errors
	# -z = compression to reduce size of data portions
	rsync -arqz $LASTBACKUP/* flownet@$1:$RESTORE

	if [ $? -eq 0 ] # This checks the exit code of rsync, 0 = OK
	then
	    
	    flowout "Restore of ${1}:${RESTORE} from ${LASTBACKUP} was successful!  Moving to next server..."
	    
	else

	    flowout "Restore of ${1}:${RESTORE} from ${LASTBACKUP} failed with error code ${?}!  Moving to next server..."
	fi

    else

	flowout "No valid previous backup was found for ${1}!  Moving to next server..."

    fi
}


#### Main Flownet

# Import settings from local flownet.conf
. /home/flownet/flownet.conf

# Loop this script forever
while [ 1 ]
do
    # Count up to WAIT, then execute server check
    WAITCOUNT=0
    while [ $WAITCOUNT != $WAIT ]
    do
	sleep 1
	let WAITCOUNT++
    done
    
    flowout "Time to start the flow..."
    
    # Loop through servers, executing server checks
    len=${#SERVERS[@]}
    i=0
    while [ $i -lt $len ]
    do
	# Ping SERVERS[i] 5 times
	flowout "Trying to ping server ${SERVERS[$1]}"
	ping -q -c 5 ${SERVERS[$i]}
	if [ $? -eq 0 ] # This checks the exit code of the ping command, 0 = good pings
	then
	    flowout "Server ${SERVERS[$i]} appears to be up, attempting to download configuration file..."
	    scp flownet@${SERVERS[$i]}:/home/flownet/flownet.conf flownet-${SERVERS[$i]}.conf

	    # Check if scp worked and flownet-SERVERS[i].conf exists
	    if [ $? -eq 0 ] # Again, 0 = good
	    then
		# Import settings from flownet-SERVERS[i].conf
		. flownet-${SERVERS[$i]}.conf
		flowout "Flownet configuration file from ${SERVERS[$i]} successfully acquired!"

		flowout "Attempting to lock Flownet installation at ${SERVERS[$i]}..."
		scp flowlock.conf flownet@${SERVERS[$i]}:/home/flownet/flownet.conf

		# Check if locking scp worked
		if [ $? -eq 0 ] # 0 = good
	        then
		    flowout "Flownet installation at ${SERVERS[$i]} was successfully locked!"
		    # Call appropriate action function
		    case $ACTION in
			backup)
		            flowout "Backup action is set!"
			    backup ${SERVERS[$i]}
			    ;;
			restore)
			    flowout "Restore action is set!"
		            restore ${SERVERS[$i]}
			    ;;
			*)
		            flowout "Invalid action switch set for ${SERVERS[$i]}, moving to next server..."
			    ;;
		    esac
		
		    # Restore remote server's configuration file
		    scp flownet-${SERVERS[$i]}.conf flownet@${SERVERS[$i]}:/home/flownet/flownet.conf
		    # Clean up
		    rm flownet-${SERVERS[$i]}.conf
		
		    let i++
		else
		    flowout "Unable to lock ${SERVERS[$i]} Flownet installation!  Moving to next server..."

		    # Clean up
		    rm flownet-${SERVERS[$i]}.conf
		    
		    let i++
		fi
	    else
		flowout "Unable to acquire ${SERVERS[$i]} configuration file!  Moving to next server..."
		let i++
	    fi  

	else
	    flowout "Server ${SERVERS[$i]} isn't responding, moving to next server..."
	    let i++
	fi

    done
done

