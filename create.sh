#!/bin/sh

#paratmers: machine name (required), CPU (number of cores), RAM (memory size in MB), HDD Disk size (in GB), ISO (Location of ISO image, optional)
#default params: CPU: 2, RAM: 4096, DISKSIZE: 20GB, ISO: 'blank'

phelp() {
	echo "Script for automatic Virtual Machine creation for ESX"
	echo "Usage: $(basename $0) options: n <|c|i|r|s|N>"
	echo "Where n: Name of VM (required), c: Number of virtual CPUs, i: location of an ISO image, r: RAM size in MB, s: Disk size in GB, N: Network name (can be specified multiple times)"
	echo "Default values are: CPU: 2, RAM: 4096MB, HDD-SIZE: 20GB, no network connection"
}

#Setting up some of the default variables
CPU=2
RAM=4096
SIZE=20
ISO=""
FLAG=true
ERR=false

ethernet_idx=0

#Error checking will take place as well
#the NAME has to be filled out (i.e. the $NAME variable needs to exist)
#The CPU has to be an integer and it has to be between 1 and 32. Modify the if statement if you want to give more than 32 cores to your Virtual Machine, and also email me pls :)
#You need to assign more than 1 MB of ram, and of course RAM has to be an integer as well
#The HDD-size has to be an integer and has to be greater than 0.
#If the ISO parameter is added, we are checking for an actual .iso extension
while getopts n:c:i:r:s:N: option
do
        case $option in
                n)
					NAME=${OPTARG};
					FLAG=false;
					if [ -z $NAME ]; then
						ERR=true
						MSG="$MSG | Please make sure to enter a VM name."
					fi
					;;
                c)
					CPU=${OPTARG}
					if [ `echo "$CPU" | egrep "^-?[0-9]+$"` ]; then
						if [ "$CPU" -le "0" ] || [ "$CPU" -ge "32" ]; then
							ERR=true
							MSG="$MSG | The number of cores has to be between 1 and 32."
						fi
					else
						ERR=true
						MSG="$MSG | The CPU core number has to be an integer."
					fi
					;;
				i)
					ISO=${OPTARG}
					if [ ! `echo "$ISO" | egrep "^.*\.(iso)$"` ]; then
						ERR=true
						MSG="$MSG | The extension should be .iso"
					fi
					;;
                r)
					RAM=${OPTARG}
					if [ `echo "$RAM" | egrep "^-?[0-9]+$"` ]; then
						if [ "$RAM" -le "0" ]; then
							ERR=true
							MSG="$MSG | Please assign more than 1MB memory to the VM."
						fi
					else
						ERR=true
						MSG="$MSG | The RAM size has to be an integer."
					fi
					;;
                s)
					SIZE=${OPTARG}
					if [ `echo "$SIZE" | egrep "^-?[0-9]+$"` ]; then
						if [ "$SIZE" -le "0" ]; then
							ERR=true
							MSG="$MSG | Please assign more than 1GB for the HDD size."
						fi
					else
						ERR=true
						MSG="$MSG | The HDD size has to be an integer."
					fi
					;;
                N)
					NET_NAME=${OPTARG}
					# Create a network record
					NET_DEFS="$NET_DEFS\nethernet${ethernet_idx}.present = \"TRUE\"\nethernet${ethernet_idx}.virtualDev = \"vmxnet3\"\nethernet${ethernet_idx}.networkName = \"${NET_NAME}\"\nethernet${ethernet_idx}.generatedAddressOffset = \"0\""
					ethernet_idx=$(($ethernet_idx + 1))
					;;
				\?) echo "Unknown option: -$OPTARG" >&2; phelp; exit 1;;
        		:) echo "Missing option argument for -$OPTARG" >&2; phelp; exit 1;;
        		*) echo "Unimplimented option: -$OPTARG" >&2; phelp; exit 1;;
        esac
done

if $FLAG; then
	echo "You need to at least specify the name of the machine with the -n parameter."
	exit 1
fi

if $ERR; then
	echo $MSG
	exit 1
fi

if [ -d "$NAME" ]; then
	echo "Directory - ${NAME} already exists, can't recreate it."
	exit
fi

#Creating the folder for the Virtual Machine
mkdir ${NAME}

#Creating the actual Virtual Disk file (the HDD) with vmkfstools
# Create the VMDK only when it doesn't exist yet
vmkfstools -c "${SIZE}"G -a lsilogic $NAME/$NAME.vmdk

#Creating the config file
touch $NAME/$NAME.vmx

#writing information into the configuration file
cat << EOF > $NAME/$NAME.vmx

config.version = "8"
virtualHW.version = "13"
vmci0.present = "TRUE"
displayName = "${NAME}"
floppy0.present = "FALSE"
numvcpus = "${CPU}"
scsi0.present = "TRUE"
scsi0.sharedBus = "none"
scsi0.virtualDev = "lsilogic"
memsize = "${RAM}"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "${NAME}.vmdk"
scsi0:0.deviceType = "scsi-hardDisk"
ide1:0.present = "TRUE"
ide1:0.fileName = "${ISO}"
ide1:0.deviceType = "cdrom-image"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"
guestOS = "other26xlinux-64"
EOF

echo -e "$NET_DEFS" >> $NAME/$NAME.vmx

#Adding Virtual Machine to VM register - modify your path accordingly!!
MYVM=`vim-cmd solo/registervm /vmfs/volumes/datastore1/${NAME}/${NAME}.vmx`
#Powering up virtual machine:
vim-cmd vmsvc/power.on $MYVM

echo "The Virtual Machine is now setup & the VM has been started up. Your have the following configuration:"
echo "Name: ${NAME}"
echo "CPU: ${CPU}"
echo "RAM: ${RAM}"
echo "HDD-size: ${SIZE}"
if [ -n "$ISO" ]; then
	echo "ISO: ${ISO}"
else
	echo "No ISO added."
fi
echo "Thank you."
exit
