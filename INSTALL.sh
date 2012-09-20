#! /usr/bin/env bash
#
# Script to install all of the correct symlinks (syncing 
#
#

# Define constants
CONFIGDIR='./config-rc'

# Declare variables
possibleParameters="v"
verbose=false;

# Let's set some values based on the parameters
while getopts "$possibleParameters" opt; do
	case $opt in
		v)	verbose=true;;
		\?)	echo "Invalid option: -$OPTARG"; exit 1;;
	esac
done

# Get the current directory
gitboxDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define an array of files/directories
filesDirectories=(
	"/etc/bash_completion.d"
	"$HOME/.ssh/config"
	"$HOME/.vim"
	"$HOME/local"
);

# Define an array for all of the config-rc files
configFiles=()
# Let's go through all of the files in the config-rc directory
shopt -s dotglob # Allow * to match hidden files
for filename in $CONFIGDIR/*
do
	configFiles+=($filename)
done;
shopt -u dotglob # Undo the allowing of * to match hidden files

# Define an array of Windows/Cygwin ONLY files/directories
cygFileLocations=(
	"$HOME/_vimrc"
	"$HOME/vimfiles"
);

# Define an array containing the destination of the Windows/Cygwin ONLY files/directories for linking
# MUST ALIGN WITH cygFilesSources
cygFileDestinations=(
	"$CONFIGDIR/.vimrc"
	".vim"
);

# Create a function to echo out errors
function error() {
	# Let's get our arguments
	local message=$1

	# Echo out our message
	echo -e "\033[00;31mERROR:\033[00m $message"
}

# Create a function to remove the passed target
function removeTarget() {
	# The target should be the first (only) argument
	local target=$1

	# Define some local variables
	local status=1 # Let's have a variable to hold the return status
	local possible=false # Keep track of whether its possible to remove
	local message="" # Hold our message here

	# Let's make SURE that we have write permissions
	if [ -w "$target" ] ; then
		# If the target is a symlink
		if [ -L "$target" ] ; then
			# Remove the original file... we're gonna link it instead
			possible=true

			# Set the message
			message="symlink \t$target removed"

			# If we DON'T have access to the symlink's parent directory
			if [ ! -w `dirname "$target"` ]; then
				# Don't allow the file to be removed
				possible=false

			# If the target doesn't actually exist
			elif [ ! -e "$target" ] ; then
				# Set the message
				message="broken link \t$target removed"

			fi

		# If the target is a file
		elif [ -f "$target" ] ; then
			# Remove the original file... we're gonna link it instead
			possible=true

			# Set the message
			message="file \t\t$target removed"

		# If the target is a directory
		elif [ -d "$target" ] ; then
			# Remove the original directory... we're gonna link it instead
			possible=true

			# Set the message
			message="directory \t$target removed"

		fi
	fi

	# If its possible to make the delete
	if $possible ; then
		# Remove the target
		rm $target

		# Save the return status
		status=$?

		# Verbose info
		if $verbose && [ $status == 0 ] ; then
			echo -e $message
		fi
	# I guess its not possible
	else
		# Display an error
		error "insufficient permissions to delete $target"
	fi

	# Give a return code as an exit status
	return $status
}

# Create a function to symbolically link the passed source to the passed target
function symLink() {
	# Let's have a variable to hold the return status
	local status=1

	# Let's get our arguments
	local source=$1
	local target=$2

	# Let's make SURE that the target doesn't already exist... or we might make a recursive symlink (AH!)
	if [ ! -e "$target" ] ; then
		# Let's symbolically link them
		ln -s $1 $2

		# Save the return status
		status=$?

		# Verbose info
		if $verbose && [ $status == 0 ] ; then
			echo -e "  $source has been linked to $target"
		fi
	# The target must already exist
	else
		# Display an error
		error "location $target already exists"
	fi

	# Give a return code as an exit status
	return $status
}

# Let's loop through each file/directory
for target in "${filesDirectories[@]}"
do
	# Get the basename
	baseName=$(basename "$target")

	# Use the removeTarget function and pass the target as an argument
	removeTarget $target #&& echo 'success!' || echo 'nope'; exit;

	# Relink the file
	symLink $gitboxDir/$baseName $target

done;

# Let's loop through each config file
for target in "${configFiles[@]}"
do
	# Get the basename
	baseName=$(basename "$target")

	# Use the removeTarget function
	removeTarget $HOME/$baseName

	# Relink the file
	symLink $gitboxDir/$target $HOME/$baseName

done;

# Check if we're running CYGWIN
if [[ $OSTYPE == "cygwin" ]] ; then
	# Get the windows style home directory
	windowsStyleHome=$(cygpath -w $HOME);

	# Create a quick counter, to keep our two cygFile arrays aligned
	count=0

	# Let's loop through each file/directory
	for cygTarget in "${cygFileLocations[@]}"
	do
		# Get the windows target path
		windowsTargetPath=$(cygpath -w $cygTarget);

		# Get the windows destination path
		windowsDestinationPath=$(cygpath -w $gitboxDir\\${cygFileDestinations[$count]});

		# Use the removeTarget function and pass the target as an argument
		removeTarget $cygTarget

		# Verbose info
		if [ $verbose != true ] ; then
			# Suppress the output
			outputSuppressor='>nul'
		fi

		# Use cmd (windows native command prompt) to setup Windows NT Symbolic Links
		cmd /c mklink "$windowsTargetPath" "$windowsDestinationPath" $outputSuppressor

		# Increment the counter
		count=$[$count+1]
	done;
fi

# Let's change the permissions of some files
chmod 600 ./config

# We're using Git Submodules now, so let's start those up
git submodule init
git submodule update

# Exit gracefully (positive/good exit code)
exit 0
