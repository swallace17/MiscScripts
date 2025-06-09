#################################################################################################################
#The purpose of this script is to shrink the C drive by X percent of it's remaining free space using diskpart.
#(The script will not run if the free space being removed is less than 1Gb)
#################################################################################################################

#Percentage of free space on C drive to be removed. Default=80 (If C drive has 100Gb free, C drive will be reduced by 80Gb)
$freeSpacePercentage = 80

#Get the current free space on the C drive
$driveInfo = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq 'C' }
$freeSpace = $driveInfo.Free #Amount of free space on C drive, in bytes

#Calculate the desired shrink size in megabytes by multiplying free space by the decimal form of the specified percentage (and rounding to the nearest whole numeber)
#then converts from bytes to kilobytes, and kilobytes to megabytes (dividing by 1024 twice)
$desiredShrinkSize = [math]::Round(($freeSpace * ($freeSpacePercentage / 100)) / 1024 / 1024, 0)

#Check if desired shrink size is less than 1 GB (1024 MB) - less than 1GB and its not worth shrinking
if ($desiredShrinkSize -lt 1024) {
    Write-Host "Error: The desired shrink size is less than 1 GB. To shrink further, create more free disk space by deleting unnecessary files. Aborting."
    exit 1
}

# Create a temporary script file for diskpart commands
$scriptFile = Join-Path -Path $env:TEMP -ChildPath "shrink_c_drive_script.txt"

# Get the drive letter of the C drive
$driveLetter = $driveInfo.Name

# Generate the diskpart script contents
$diskpartCommands = @"
select volume $driveLetter
shrink desired=$desiredShrinkSize
"@

# Write the diskpart commands to the script file
$diskpartCommands | Out-File -FilePath $scriptFile -Encoding ASCII

# Run diskpart with the script file
Start-Process -FilePath "diskpart.exe" -ArgumentList "/s `"$scriptFile`"" -WorkingDirectory $env:TEMP -WindowStyle Hidden -Wait

# Clean up the temporary script file
Remove-Item -Path $scriptFile -Force

# Calculate the amount by which the C drive was reduced
$reductionAmount = [math]::Round(($desiredShrinkSize / 1024),0) #Convert shrink size to GB
Write-Host "Shrink completed successfully. C drive reduced by ~$reductionAmount GB"

# Exit the script without error
exit 0
