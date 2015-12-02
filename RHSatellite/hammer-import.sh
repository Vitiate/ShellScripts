#!/bin/bash
#
# Username and password must be configured in:  /etc/hammer/cli_config.yml
#
# Imports all the subfolders it can find into RHSatellite via the Hammer utility.
# Checks to see if the items it is creating and importing exist prior to importing them.
#
# Jeremy Tirrell 2015-12-02
#
# :foreman:
#   :username: 'admin'
#   :password: 'Water123'

arraySuffix=(".as5" ".el5" ".el6")			# Array of Suffix to remove from string
arrayIgnore=("rhel5as" "rhel6")				# Array of folders to ignore
releaseID="EL5"								# Identifies the version of the product
organization="AU"

IFS=$'/\n' arrayFolder=($(ls -d */))		# Get an array of folders
IFS=''										# Return IFS to original settings

echo Creating Folder list
i=0
for item in "${arrayFolder[@]}"; do 		# Clean up the folder list
	skip=false
	for ignored in ${arrayIgnore}; do 		# Remove all ignored folders from the list
		if [[ $ignored == $item ]]; then
			skip=true
		fi
	done
	if [[ $skip == false ]]; then 			# If the folder is flagged to be skipped ignore it.
		newItem=$item
		for suffix in "${arraySuffix[@]}"	# Remove all the suffix's from the foldername
		do
			newItem=${newItem%$suffix}
		done
		arrayCleanFolders[$i]=$newItem		# Create a new array containing our cleaned up folders
		arrayOriginalFolders[$i]=$item 		# Store the original foldername as well, we need it to upload to the repo
		let i=i+1
	fi

done

i=0
for folder in ${arrayCleanFolders[@]}; do 	# Process all the folders
	echo "==================================================================="
	echo "Checking to see if the \"$organization $releaseID $folder\" product exists:"
	if [[ $(hammer product list --organization "$organization" |grep "$organization $releaseID $folder") ]]; then
    	echo "	The \"$organization $releaseID $folder\" product exists"
	else
		echo "	Creating Product \"$organization $releaseID $folder\":"
		echo 	hammer product create --name=\"$organization $releaseID $folder\" --organization=\"$organization\"
		hammer product create --name="$organization $releaseID $folder" --organization="$organization"
	fi

	newRepo=false
	echo "Checking to see if the \"$organization $releaseID $folder\" repository exists:"
	if [[ $(hammer repository list --organization "$organization" |grep "$organization $releaseID $folder") ]]; then
    	echo "	The \"$organization $releaseID $folder\" repository exists"
	else
		newRepo=true
		echo "	Creating Repository \"$organization $releaseID $folder\":"
		echo 	hammer repository create --name=\"$organization $releaseID $folder\" --organization=\"$organization\" --product=\"$organization $releaseID $folder\" --content-type=\"yum\" --publish-via-http=true
		hammer repository create --name="$organization $releaseID $folder" --organization="$organization" --product="$organization $releaseID $folder" --content-type="yum" --publish-via-http=true
	fi
	
	if [[ $newRepo == false ]]; then	# If this is an existing repository get a list of the packages to test against, this process takes a while so we store it in a tmp file.
		echo "	Obtaining a list of packages from the existing \"$organization EL5 $folder\" repository:"
		tempFile=$(mktemp)	# Setup a temp file to dump the repo contents into
		hammer package list --organization="$organization" --product="$organization $releaseID $folder" --repository="$organization $releaseID $folder" > $tempFile	# Dump the package list to the temp file
		echo "	Obtaining list of packages from ./${arrayOriginalFolders[$i]}/"
		IFS=$'\n' arrayPackages=($(ls ./${arrayOriginalFolders[$i]}/*.rpm | xargs -n 1 basename)) # Get a list of files in the folder
		IFS=''		# Revert to old IFS
		for package in ${arrayPackages[@]}; do 	# For each package in the directory, compare it to the temp file, if it is in the tempfile ignore it, otherwise upload it.
			if $(grep -q "$package" "$tempFile");then
				echo "	$package exists in $organization $releaseID $folder not uploading"
			else
				echo " 	$package does not exist in $organization $releaseID $folder uploading"
				echo 		hammer repository upload-content --name \"$organization $releaseID $folder\" --path \"./${arrayOriginalFolders[$i]}/$package\" --product \"$organization $releaseID $folder\" --organization \"$organization\"
				hammer repository upload-content --name "$organization $releaseID $folder" --path "./${arrayOriginalFolders[$i]}/$package" --product "$organization $releaseID $folder" --organization "$organization"
			fi
		done
		unset arrayPackages 	# Unset the array
	else	# This is a new repository, commence uploading of all files
		echo "Uploading Content to Repository \"$organization $releaseID $folder\""
		echo 	hammer repository upload-content --name \"$organization $releaseID $folder\" --path \"./${arrayOriginalFolders[$i]}/\" --product \"$organization $releaseID $folder\" --organization \"$organization\"
		hammer repository upload-content --name "$organization $releaseID $folder" --path "./${arrayOriginalFolders[$i]}/" --product "$organization $releaseID $folder" --organization "$organization"
		echo \n
	fi
	let i=i+1
done