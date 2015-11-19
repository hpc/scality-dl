#!/bin/bash

# 2014-09-22 : 17:00 CEST
# Version 1.7
# 2014-09-22 - fix for -m option and mkFsOptionMountOptions not being used
# 
# - dwyart

dryRun="true"; 
size="unset"; 
detectDrives="false"; 
mountPrefix="/scality/disk";
ignoreDisks="sda1\|sda2\|sda3\|sda4\|sda5\|c0d0\|dm-";
dateStamp=`date +%d-%m-%y-%s`;
logFile="/tmp/scality-auto_build_disks.log.$dateStamp"; 
assumeYes="false";
partNumber="1"
batchSize=16
mountByPart="false" 
configSingleDrive="false"; 
configSingleDriveNumber="null";
configSingleDriveOpt="null"; 

mountPointStart="1";
mkdirTotal="0"
autoDriveCountMinimum=2; 
safetyCheckOverride="false"; 
zeroDrive="false";  

# FSTAB Options 
mkFsOptionType="ext4";

# filesystem specific defaults are only set if -t option is used, otherwise mkFsOptionMountOptions is used by default. 
# SSD defaults
mkFsOptionMountOptionsSSDEXT4="data=ordered,noauto,noatime,barrier=1,discard"; 
mkFsOptionMountOptionsSSDEXT3="data=ordered,noauto,noatime,barrier=1,discard";
mkFsOptionMountOptionsSSDXFS="noauto,logbsize=256k,logbufs=8,noatime,barrier=1"; 
# rotational defaults
mkFsOptionMountOptionsEXT4="data=ordered,noauto,noatime,barrier=1";
mkFsOptionMountOptionsEXT3="data=ordered,noauto,noatime,barrier=1";
mkFsOptionMountOptionsXFS="noauto,logbsize=256k,logbufs=8,noatime,barrier=1";
# catch all defaults (assumes ext, since ext is default if not specified). 
mkFsOptionMountOptions="data=ordered,noauto,noatime,barrier=1";
mkFsOptionMountOptionsOverride=0

mkFsOptionMountOptionsFsckOrder="0";
mkFsOptionMountOptionsDump="0";
mkFsOptionXFSOptions=""; 

usageText() { 
echo "Options";
echo "-------";
echo "-s integer| Set size in bytes: example: -s 3298534883328, or multiple disks \"3298534883328\|322122547200\""; 
echo "-X option | Execute the config, default operation is a dry run with no action taken for safety"; 
echo "-i string | Ignore disks - seperated by standard regex seperator \| example: \"sda\|cisso\|md0\" default:($ignoreDisks)"; 
echo "-d        | Debug";  
echo "-y option | Assume yes to all questions, exit during safety checks - (see -o option)";
echo "-t string | Mount FS type supported:(ext3, ext4, xfs) default:($mkFsOptionType)";
echo "-m string | Mount FS options default: ($mkFsOptionMountOptions)";
echo "-F string | FSCK Order (when primary fsck is required post primary OS containers) ex: 0";
echo "-D string | FS DUMP options ex: 0";
echo "-p string | mount point prefix, default: $mountPrefix";
echo "-P option | mount by partition rather than UUID if there is an issue with UUID"; 
echo "-A option | Attempt to detect drives automatically";
echo "-M string | (mount point e.g. /scality/diskNN) Configure or RE-Configure Single Disk Mount Point"; 
echo "-S string | (device ID e.g. /dev/sdb, UUID label) Configure or Re-Configure Single Disk device"; 
echo "-U integer| Start mountpoint at number"; 
echo "-B integer| Set Batch size"; 
echo "-c integer| Set minimum number of drives required for automated drive detection (default 2)"; 
echo "-x string | Set the XFS mkfs options (example: \"-l\")"; 
echo "-o option | Set safety check override even if assume yes to all options is selected"; 
echo "-z string | Set the SSD prefix"; 
echo "-Z option | Enable data zeroing option"; 
echo "-L option | Enabled Lazy initialization when possible, e.g. speed up relative format time"; 
echo "-h        | Help"; 
}

while getopts ":S:M:z:x:c:B:U:i:s:t:m:F:D:p:dXyhPAoZL" opt; do

        case $opt in
        d)
            echo "Debugging enabled" >&2;
            echo ""; 
			debugBool=0;
            set -x
			;;
		X)
			echo "Executing config" >&2;
			echo "";
			dryRun="false"
			;;
		s)
			echo "Size set to $OPTARG" >&2;  
			echo ""; 
			size=$OPTARG;
			;;
		i)
			echo "Ignoring disks $OPTARG" >&2;
			echo ""; 
			ignoreDisks=$OPTARG;
			;;
		y)
			echo "Assuming yes to all options" >&2;
			echo "Note: if -y is used, program will exit during safety check" >&2; 
			assumeYes="true";
			;;
		t)
			echo "FS Option type set to $OPTARG" >&2; 
			mkFsOptionType=$OPTARG; 
			if [ $mkFsOptionType = "ext4" ]; then 
				mkFsOptionMountOptions=$mkFsOptionMountOptionsEXT4;
			fi
                        if [ $mkFsOptionType = "ext3" ]; then 
				mkFsOptionMountOptions=$mkFsOptionMountOptionsEXT3;
			fi
                        if [ $mkFsOptionType = "xfs" ]; then 
				mkFsOptionMountOptions=$mkFsOptionMountOptionsXFS;
			fi
			echo "Setting default $OPTARG filesystem options to $mkFsOptionMountOptions"; 
			;;
		m)
			echo "FS Mount Option set to $OPTARG" >&2;
			mkFsOptionMountOptions=$OPTARG;
			mkFsOptionMountOptionsOverride=1;
			;;
		F)
			echo "FS FSCK Order set to $OPTARG" >&2; 
			mkFsOptionMountOptionsFsckOrder=$OPTARG;	
			;;
		D)
			echo "FS Dump set to $OPTARG" >&2; 
			mkFsOptionMountOptionsDump=$OPTARG; 
                	;;
		p)
			echo "Mount prefix set to $OPTARG" >&2; 
			mountPrefix=$OPTARG; 
                	;;
		P)
			echo "Mounting by partition" >&2;
			mountByPart="true"; 
			;;
		A)	
			echo "Attempting to detect drives automatically" >&2;
			detectDrives="true"; 
			;;
		M)
			echo "Configuring Single Drive by mount $OPTARG" >&2;
			configSingleDrive="true"; 
			configSingleDriveOpt=$OPTARG;
			configSingleDriveBy="mount"; 
			;;
		U)
			echo "Configuring Starting mountpoint at $OPTARG" >&2;
			mountPointStart=$OPTARG; 
			configMountPointStart="true"; 
			;;
		B)
			echo "Configuring Batch size to $OPTARG" >&2; 
			batchSize=$OPTARG; 
			;;
		c)
			echo "Set minimum number of drives required for automated drive detection to $OPTARG" >&2; 
			autoDriveCountMinimum=$OPTARG; 
			;;
		x)
			echo "Set the XFS mkfs options to $OPTARG" >&2; 
			mkFsOptionXFSOptions=$OPTARG; 
			;;

		o)
			echo "Overridding safety check exit during assume yes" >&2; 
			safetyCheckOverride="true"; 
			;;
		z)
            echo "SSD Mount prefix set to $OPTARG" >&2;
            ssdMountPrefix=$OPTARG;
            ;;
		Z) 
			echo "Enabling drive data wipe" >&2; 
			zeroDrive="true"; 
			;;
		S)
			echo "Configuring Single Disk Device $OPTARG" >&2; 
			configSingleDriveOpt=$OPTARG; 
                        configSingleDrive="true";
			configSingleDriveBy="device"; 
			;; 
		L)	
			echo "Enabled Lazy Initialization" >&2; 
			configEnableLazyInit="true"; 
			;;
		h)
			echo "Printing Help" >&2; 
			usageText
			exit
			;;
		\?)
            echo "Invalid option: -$OPTARG" >&2;
			echo ""; 
            usageText
            exit
            ;;
        esac
done

which kpartx  >/dev/null 2>&1 || { echo "kpartx is not installed, Aborting." >&2; exit 1; }
which parted  >/dev/null 2>&1 || { echo "parted is not installed, Aborting." >&2; exit 1; }

function sizeDrivesCheck() {
if [ $size = "unset" ]; then
        echo "Size not set. There is no default value, please specify with -s";
        echo "";
        usageText
        exit 1;
fi 
} # END sizeDrivesCheck

function sortSSDFirst() {
    for d in $* ; do
        isSSD $d
        is=$?
        echo "$is $d"
    done | sort | cut -f 2 -d ' '
}

function setupDevices() {
	if [ $detectDrives = "true" ]; then
        	autoDetectDrives
	fi

	if [ $configSingleDrive = "true" ]; then
		batchSize=1; 
		unusedDisks=`fdisk -l 2>/dev/null | grep $configSingleDriveOpt | awk '{print $2}' | grep "$ignoreDisks" | sed s/://g | sort`
		if [ $configSingleDriveBy = "device" ]; then 
			systemDevices=$configSingleDriveOpt; 
	                systemDevicesPart=`fdisk -l 2>/dev/null | grep $configSingleDriveOpt | grep Disk | awk '/\/mapper\// {print $2"p1"} !/\/mapper\// {print $2"1"}' | grep -v "$ignoreDisks" | sed s/://g | sort`
		else
	                systemDevices=`fdisk -l 2>/dev/null | grep $configSingleDriveOpt | awk '{print $2}' | grep -v "$ignoreDisks" | sed s/://g | sort `
	                systemDevicesPart=`fdisk -l 2>/dev/null | grep $configSingleDriveOpt | awk '/\/mapper\// {print $2"p1"} !/\/mapper\// {print $2"1"}' | grep -v "$ignoreDisks" | sed s/://g | sort`
                systemDevicesTotal=`echo "$systemDevices" | wc -l`
		# add part here to grep the device from the fstab and get it's mount number and then set a system wide parameter for this to override. 
		#fix this to escape the mountpoint variable it's wrong 
		fi 	
	
		configSingleDriveNumber=$((mountPointStart - 1));  
	else
	# Run standard routine for all disks if were not configuring a single disk
		sizeDrivesCheck

        	unusedDisks=`fdisk -l 2>/dev/null | grep $size | awk '{print $2}' | grep "$ignoreDisks" | sed s/://g | sort`
	        systemDevices=`fdisk -l 2>/dev/null | grep $size | awk '{print $2}' | grep -v "$ignoreDisks" | sed s/://g | sort `
		systemDevicesPart=`fdisk -l 2>/dev/null | grep $size | awk '/\/mapper\// {print $2"p1"} !/\/mapper\// {print $2"1"}' | grep -v "$ignoreDisks" | sed s/://g | sort`
		systemDevicesTotal=`echo "$systemDevices" | wc -l`
	fi

    systemDevicesPart=$(sortSSDFirst $systemDevicesPart)

# need to find somewhere better for this. 
	if [ $configSingleDrive = "true" ] ; then 
		echo "Single drive configuration: attempting to unmount $systemDevicesPart" ; 
		umount $systemDevicesPart; 
	fi

} # end setupDevices

function bannerText() {
	echo "Device Configuration Report"; 
	echo "===========================";
	echo "";
	echo "Ignored Disks"; 
	echo "---------------------------"
	echo "$unusedDisks"; 
	echo "";
	echo "Using $systemDevicesTotal disks";
	echo "---------------------------" ;
	echo "";
	echo "Configured Disks"; 
	echo "---------------------------";
	echo "$systemDevices"; 
	echo ""; 
	echo "Configured Partitions"; 
	echo "---------------------------";
	echo "$systemDevicesPart"; 
	echo ""; 
	echo "Log File"; 
	echo "---------------------------"; 
	echo "$logFile"; 
	echo ""; 
	echo ""; 
	echo "End Configuration Report"; 
	echo ""; 
} # end bannerText

function userAuth() {
if [ "$assumeYes" = "true" ]; then 
        isAuthed="Y"; 
	echo "*** Assuming yes to all options ***"; 
	echo ""; 
else
        echo -n "Are you sure (Y/N)? :";
        read isAuthed;
fi

if [ "$isAuthed" != "Y" ]; then exit 1; fi 
} # end userAuth

function runMkPart() {
	echo "Creating Partitions" 
	
	for i in $systemDevices; do 
		echo "Running Disk $i"; 
		parted $i --script -- mklabel gpt 2>&1>>$logFile 
	# try alternative alignment technique 
	#	parted $i --script -- mkpart primary 1 -1 2>&1>>$logFile
		parted $i --script -- mkpart primary 0% 100% 2>&1>>$logFile 
		parted $i --script print 2>&1>>$logFile
		kpartx -s -a $i\1 2>&1>>$logFile
	done;
	echo "Completed partitions";
	echo "";   
} # end runMkPart 	

function runMkfs() {
	echo "Creating Filesystems"

	# batch
	date
	set -- $systemDevicesPart
	while [ $# -gt 0 ]; do
		for i in $(seq $batchSize); do
			if [ "$1"0 != 0 ]; then
				echo "Running Disk $1"; 
				export systemDevicesExport="$1"
				echo "*** Creating filesystem on $systemDevicesExport"

				if [ "$zeroDrive" = "true" ]; then 
					echo "Zeroing out data on drive $systemDevicesExport"; 
					dd if=/dev/zero of=$systemDevicesExport bs=102400 2>>$logFile 1>>$logFile 
				fi; 

				if [ "$mkFsOptionType" = "ext4" ]; then
					if [ "$configEnableLazyInit" = "true" ]; then
                                        	echo "*** Running lazy initialization ***";
                                        	echo "*** Ensure the system remains up during this period ***";
                                        	mke2fs -t $mkFsOptionType -F -E lazy_itable_init=1 -m0 $systemDevicesExport 2>&1>>$logFile & 

	                                else   
						mke2fs -t $mkFsOptionType -F -m0 $systemDevicesExport 2>&1>>$logFile & 
					fi 
				elif [ "$mkFsOptionType" = "ext3" ]; then
					mke2fs -t $mkFsOptionType -F -j -m0 $systemDevicesExport 2>&1>>$logFile &
				elif [ "$mkFsOptionType" = "xfs" ]; then
					mkfs.xfs $systemDevicesExport $mkFsOptionXFSOptions 2>&1>>$logFile &
				fi; 

				shift;
			fi;
		done;
		# wait for this batch to finish
		while true; do
	        	sleep 30;
	        	mkfsCountCurrent=`ps -ef | grep mke2fs | grep -v grep | wc -l`;
	        	if [ $mkfsCountCurrent = 0 ] ; then break; fi
		done
		date
	done
	echo "Completed creating filesystems"; 
	echo ""; 
} # end runMkfs

function setFSParams() {
	echo "Setting filesystem parameters"
	for i in $systemDevicesPart; do 
		echo " --- Setting tuning for $i"; 
		echo " --- Setting tuning for $i" 2>&1>>$logFile 
		tune2fs -m0 -c0 -C0 -i0 $i 2>>$logFile 1>>$logFile 
	done; 
	echo ""; 
	echo "Tuning Complete"; 
	echo ""; 
} # end setFSParams

function isSSD() {
    local dev=$(basename $1 | sed -r -e 's/[[:digit:]]+$//g')

    local rotational=$(cat /sys/block/$dev/queue/rotational 2>/dev/null)
    test "$rotational" == "0"

    return $?
}

function mountPointFor() {
    local part=$1
    local nr=$2

    if isSSD $part ; then
        echo ${ssdMountPrefix}${nr}
    else
        echo ${mountPrefix}${nr}
    fi
}

function makeMountPoints() {

	fstabBackup="/etc/fstab.prescality.backup.$dateStamp"; 
	echo "FSTAB Backup: $fstabBackup" 2>&1>>$logFile; 
	scalityFstabTmp="/etc/fstab.scality.tmp.$dateStamp"; 


	mkdirTotal=$((mountPointStart + systemDevicesTotal));		

	if [ $mountPointStart = "0" ]; then mountPointStart=$((mountPointStart++)); fi; 

	echo "Making mountpoints"
	for driveCount in `seq $mountPointStart $mkdirTotal`; do 
		mkdir -p $mountPrefix$driveCount; 
	done; 

	echo "Backing up fstab" 
	cp -fv /etc/fstab $fstabBackup;  

	echo "Editing fstab"
	echo "### SCALITY NODE Data Drives *** Do Not Modify *** ### "> $scalityFstabTmp; 

	diskCount=$mountPointStart; 
        ssdDiskCount=$mountPointStart;

	for currentSystemDevice in $systemDevicesPart; do
		# assign a UUID if blkid does not report one
		blkid $currentSystemDevice|grep -q UUID || tune2fs -U random $currentSystemDevice

		systemDevicesPartByUuid=`blkid  $currentSystemDevice | awk '{print $2}'`; 

        if isSSD $currentSystemDevice ; then
		if [ "$mkFsOptionType" = "ext4" ]; then
			mountOptions="$mkFsOptionMountOptionsSSDEXT4"
			mountPoint=$(mountPointFor $currentSystemDevice $ssdDiskCount)
			ssdDiskCount=$(($ssdDiskCount+1));
		fi
		if [ "$mkFsOptionType" = "ext3" ]; then
            mountOptions="$mkFsOptionMountOptionsSSDEXT3"
            mountPoint=$(mountPointFor $currentSystemDevice $ssdDiskCount)
            ssdDiskCount=$(($ssdDiskCount+1));
		fi
		if [ "$mkFsOptionType" = "xfs" ]; then
           mountOptions="$mkFsOptionMountOptionsSSDXFS"
           mountPoint=$(mountPointFor $currentSystemDevice $ssdDiskCount)
           ssdDiskCount=$(($ssdDiskCount+1));
		fi
        else
		if [ "$mkFsOptionType" = "ext4" ]; then 
			mountOptions="$mkFsOptionMountOptionsEXT4"
			mountPoint=$(mountPointFor $currentSystemDevice $diskCount)
			diskCount=$(($diskCount+1)); 
		fi
        if [ "$mkFsOptionType" = "ext3" ]; then 
            mountOptions="$mkFsOptionMountOptionsEXT3"
            mountPoint=$(mountPointFor $currentSystemDevice $diskCount)
            diskCount=$(($diskCount+1));
        fi 
        if [ "$mkFsOptionType" = "xfs" ]; then 
            mountOptions="$mkFsOptionMountOptionsXFS"
            mountPoint=$(mountPointFor $currentSystemDevice $diskCount)
            diskCount=$(($diskCount+1));
        fi 
        fi
        if [ "$mkFsOptionMountOptionsOverride" -eq 1 ]; then
            mountOptions="$mkFsOptionMountOptions"
        fi

        mkdir -p $mountPoint

	if [ $configSingleDrive = "true" ] ; then 
		
		echo "Doing single drive stuff!";
		grep -v $mountPoint /etc/fstab  > $fstabBackup 
		echo "$systemDevicesPartByUuid	$mountPoint	$mkFsOptionType	$mountOptions	$mkFsOptionMountOptionsDump	$mkFsOptionMountOptionsFsckOrder" >> $scalityFstabTmp; 
	else
		if [ mountByPart = "true" ] ; then 
                        echo "$systemDevicesPart  $mountPoint  $mkFsOptionType $mountOptions $mkFsOptionMountOptionsDump     $mkFsOptionMountOptionsFsckOrder" >> $scalityFstabTmp;
		else 		 
			echo "$systemDevicesPartByUuid	$mountPoint	$mkFsOptionType	$mountOptions	$mkFsOptionMountOptionsDump	$mkFsOptionMountOptionsFsckOrder" >> $scalityFstabTmp; 
		fi; 	

	fi; 

	done; 		

        echo "Displaying /etc/fstab edit, please verify";
        echo "";

        diff $fstabBackup $scalityFstabTmp;

        userAuth

        cat $fstabBackup $scalityFstabTmp > /etc/fstab;
} # end makeMountPoints 

function mountFileSystems() {
	echo "Mounting filesystems";
	echo "- Mounting all automatic filesystems" ;
	echo "";
	echo "";
	mount -a;
	mount | grep $mountPrefix; 
	echo "- Manually mounting scality filesystems for verification"; 
	grep $mountPrefix /etc/fstab | awk '{print $2}'	| xargs -n1 mount; 
	echo "";
	echo ""; 
	mount | grep $mountPrefix; 	
	echo ""; 
	echo "Completed mounting filesystems";
	echo ""; 
} # end mountFileSystems

function autoDetectDrives() {
	echo "Detecting Drives";
	echo "===========================";

	let autoDriveCount=`fdisk -l 2>/dev/null | grep Disk | grep -v mapper | grep bytes | awk '{print $5}' | sort -nr | uniq -c | head -n 1 | awk '{print $1}'`;
	echo "Detected Drive count: $autoDriveCount"; 
	
	autoDriveSize=`fdisk -l 2>/dev/null | grep Disk | grep -v mapper | grep bytes | awk '{print $5}' | sort -nr | uniq -c | head -n 1 | awk '{print $2}'`;
	echo "Detected Drive Size: $autoDriveSize"; 

	echo ""; 
	
	if (( "$autoDriveCount" < "$autoDriveCountMinimum" )) ; then 
		echo "Not enough drives detected, exiting"; 
		exit 2; 
	else  
		echo "Setting Drive Size to $autoDriveSize"; 
		echo "";
		size=$autoDriveSize; 		
	fi	
} # end autoDetectDrives

safetyCheck() {
	echo ""; 
	echo "Verifying that system configuration is safe to continue"; 
	echo "======================================================="; 
	echo ""; 

	echo "Checking for /scality disks in /etc/fstab";  
	echo "========================================="; 

	grep -q scality /etc/fstab;

	if [ "$configSingleDrive" = "true" ] ; then 
		echo "Skipping fstab safetycheck due to single drive configuration"
	else

	if [ $? = 0 ]; then 
                echo "WARNING!!! :: $mountPrefix disks found in /etc/fstab."; 
                if [ "$assumeYes" = "true" ]; then
			echo ""; 
			echo "Exiting due to failed safety check"; 
		
                        if [ "$safetyCheckOverride" = "true" ] ; then
                                        echo "Safety Overridde enabled, continuing anyway. ";
                                        continue 1;
                                else
                                        exit 1;
                        fi
		else 
			echo "Do you want to continue"; 
			userAuth;
		fi;  
	else
		echo " *** No scality drives found in fstab... continuing";
	fi; 
	fi; 

        echo "";
        echo "";

	echo "Checking for $mountPrefix in /etc/fstab"; 
	echo "======================================="; 

        if [ "$configSingleDrive" = "true" ] ; then
                echo "Skipping fstab safetycheck due to single drive configuration"
        else
        
	mount | grep -q $mountPrefix; 
	if [ $? = 0 ]; then 
		echo "WARNING!!! :: $mountPrefix disks found in mounted filesystmes."; 
		if [ "$assumeYes" = "true" ]; then 
			echo ""; 
			echo "Exiting due to failed safety check!"; 
				if [ "$safetyCheckOverride" = "true" ]; then
					echo "Safety Overridde enabled, continuing anyway. "; 
					#continue 1; 
				else 
					exit 1; 
			fi  
			else
				echo "Do you want to continue"; 
			userAuth;
		fi  
	else 
		echo " *** No $mountPrefix disks found in mounted filesystems... continuing"; 
		echo ""; 
	fi; 
	fi; 

	echo "Checking for LVM on configured drives"; 
	echo "====================================="; 

	for deviceInstance in $systemDevices; do 
		echo " --- Checking device $deviceInstance"; 
		pvs | grep $deviceInstance;
		
		if [ $? = 0 ]; then
			echo "WARNING!!! :: $deviceInstance found in LVM physical device setup, can not continue!"; 
	                if [ "$assumeYes" = "true" ]; then
        	           	echo ""; 
			        echo "Exiting due to failed safety check!";
                	        if [ "$safetyCheckOverride" = "true" ]; then 
					echo "Safety Overridde enabled, continuing anyway. "; 
					continue 1; 
				else 
					exit 1;
				fi 
               		 else
                        	echo "Do you want to continue";
                        	userAuth;
               		 fi
		fi;
	done  	
        echo " *** No LVM configurations found, continuing.";   
	echo ""; 

	echo "Checking that mkfs can complete successfully"; 
	echo "============================================"; 

	for deviceInstance in $systemDevices; do
		echo " --- Checking device $deviceInstance"; 

		if [ "$mkFsOptionType" = "ext3" ]; then
			mke2fs -F -n $deviceInstance 1>/dev/null 2>/dev/null ;
			exitStatus=$?; 
		elif [ "$mkFsOptionType" = "ext4" ]; then
			mke2fs -F -n $deviceInstance 1>/dev/null 2>/dev/null ;
			exitStatus=$?;
		elif [ "$mkFsOptionType" = "xfs" ]; then
			mkfs.xfs -N $deviceInstance 1>/dev/null 2>/dev/null ; 
			exitStatus=$?; 
		fi 

		if [ $exitStatus = 1 ]; then
			echo "WARNING!!! :: $deviceInstance failed mkfs check, check dmsetup to ensure the kernel does not have the block device open, can not continue!";
			if [ "$assumeYes" = "true" ]; then
				echo ""
				echo "Exiting due to failed safety check!";
			
				if [ "$safetyCheckOverride" = "true" ]; then 
                                        echo "Safety Overridde enabled, continuing anyway. "; 
                                        continue 1; 
                                else 
                                        exit 1; 
                                fi  
				
			else
				echo "Do you want to continue";
				userAuth;
			fi
		fi; 
	done 
	echo " *** mkfs testing successfull, continuing.";
	echo "";

	echo "End of safety checks";
	echo "===================="; 
	echo ""; 

} # end safetyCheck

function buildFilesystems() {
setupDevices
safetyCheck
bannerText
userAuth
runMkPart
runMkfs
setFSParams
makeMountPoints
mountFileSystems
} # end buildFilesystems


if [ "$dryRun" = "true" ]; then
        setupDevices
        bannerText
        exit 0
else
	buildFilesystems
fi

