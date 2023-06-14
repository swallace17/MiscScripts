#!/bin/bash

# Install ntfs-3g package if not already installed
if ! dpkg -s ntfs-3g >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install ntfs-3g
fi

# Get a list of NTFS drives
ntfs_drives=$(lsblk -rpo "name,mountpoint,fstype" | awk '$3=="ntfs"{print $1}')

# Variable to store the identified Windows boot disk
boot_disk=""

# Variable to store the identified Windows boot partition
boot_partition=""

# Check each NTFS drive for the presence of Windows system files
for drive in $ntfs_drives; do
    # Mount the drive temporarily
    mount_point=$(mktemp -d)
    sudo mount -o ro "$drive" "$mount_point"

    # Check if Windows system files are present
    if [[ -d "$mount_point/Windows" && -d "$mount_point/Program Files" ]]; then
        echo "Standard Windows boot drive found: $drive"
        echo "Mount point: $mount_point"
        boot_disk="$drive"

        # Get a list of NTFS partitions on the boot disk
        boot_disk_partitions=$(lsblk -rpo "name,mountpoint,fstype" | awk '$1 ~ /'$boot_disk'$/ && $3 == "ntfs" {print $1}')

        # Check each NTFS partition on the boot disk for the presence of Windows system files
        for partition in $boot_disk_partitions; do
            # Mount the partition temporarily
            partition_mount_point=$(mktemp -d)
            sudo mount -o ro "/dev/$partition" "$partition_mount_point"

            # Check if Windows system files are present
            if [[ -d "$partition_mount_point/Windows" && -d "$partition_mount_point/Program Files" ]]; then
                echo "Windows boot partition found: $partition"
                echo "Mount point: $partition_mount_point"
                boot_partition="$partition"
                break
            fi

            # Unmount the partition
            sudo umount "$partition_mount_point"
            rm -r "$partition_mount_point"
        done

        break
    fi

    # Unmount the drive
    sudo umount "$mount_point"
    rm -r "$mount_point"
done

# Check if a Windows boot disk and partition were identified
if [ -z "$boot_disk" ]; then
    echo "Error: No Windows boot disk found. Aborting."
    exit 1
fi

if [ -z "$boot_partition" ]; then
    echo "Error: No Windows boot partition found on the boot disk. Aborting."
    exit 1
fi

# Percentage of free space on the boot partition to be removed. Default=80 (If boot partition has 100GB free, it will be reduced by 80GB)
freeSpacePercentage=80

# Mount the Windows boot partition to a temporary directory
mountDir="/mnt/windows"
sudo mkdir -p "$mountDir"
sudo mount -t ntfs-3g "/dev/$boot_partition" "$mountDir"

# Get the current free space on the boot partition using ntfsinfo
freeSpaceBytes=$(sudo ntfsinfo --query-freespace "/dev/$boot_partition" | grep "Total free space" | awk '{print $4}')

# Convert free space from bytes to megabytes (MB)
freeSpaceMB=$((freeSpaceBytes / 1024 / 1024))

# Check if desired shrink size is less than 1 GB (1024 MB) - less than 1GB and it's not worth shrinking
if [ $freeSpaceMB -lt 1024 ]; then
    echo "Error: The desired shrink size is less than 1 GB. To shrink further, create more free disk space by deleting unnecessary files. Aborting."
    exit 1
fi

# Calculate the desired shrink size in megabytes by multiplying free space by the decimal form of the specified percentage
# and rounding to the nearest whole number
desiredShrinkSizeMB=$((freeSpaceMB * freeSpacePercentage / 100))

# Shrink the boot partition using parted
parted "/dev/$boot_disk" resizepart "$boot_partition" ${desiredShrinkSizeMB}MB

# Calculate the amount by which the boot partition was reduced
reductionAmount=$((desiredShrinkSizeMB / 1024))
echo "Shrink completed successfully. Boot partition reduced by ~$reductionAmount GB"

# Unmount the Windows boot partition
sudo umount "$mountDir"
sudo rmdir "$mountDir"

# Exit the script without error
exit 0
