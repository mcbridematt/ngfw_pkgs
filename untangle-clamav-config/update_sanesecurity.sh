#!/bin/bash
#
# $Id: update_sanesecurity.sh 494 2007-09-26 13:46:51Z mendel $
#
# A Modified version of the update script originally written by
# Bill Landry
#
# Modified by Rick Cooper: Contact sanescript@dwford.com
#
# Modified by Norbert Buchmuller <norbi@nix.hu>
#
# Last updated Sep 26, 2007
#	FIX 09/26/2007
#	Fixed a bug: now it passes the log levels to the unprivileged child.
#	Fixed a bug: now the unprivileged child does not attempt to reload ClamAV db.
#	Prints usage message if asked for.
#
#	FIX 09/21/2007
#	Added SELinux support.
#		Thanks Andrew Colin Kissa <kissaa@sentech.co.za>.
#	Added support to run the script as root (the superuser privileges are only used
#		when changing the owner:group and security context of the signature files,
#		and when reloading clamd).
#
#	FIX 09/20/2007
#	Fixed a bug introduced by the 08/28/2007 change: the "SPAM.ndb" file was saved
#		(incorrectly) with the name "SPAM.hdb" and thus ClamAV refused to load it.
#		Thanks Keith Brazington <keith@quetz.co.uk>.
#
#	FIX 08/28/2007
#	Refactored logging to avoid code/text duplication.
#	Refactored downloading to avoid code duplication.
#	Split up the main function into smaller ones.
#	Should be started as the clamav user, not root to avoid
#		security implications.
#	Uses proper temporary dir creation method (mktemp(1)) to avoid
#		security implications.
#	It is assured that a non-zero exit status is used when exiting because of an error.
#	Uses 'mail' syslog facility.
#	Different syslog log priorities are used for messages with different severity.
#	Diagnostic messages (incl. debug messages) go to stderr instead of stdout.
#	More careful quoting to allow spaces or other unexpected chars in variables.
#	Checking carefully for the exit status of all the important commands.
#	Rsync downloads the new signature file to a temporary directory
#		and only installs it after it is verified that ClamAV accepts
#		the signature file. (Note: This requires a relatively new version of Rsync
#		because versions older than cca. 2.6.9 unconditionally download the file, even
#		if it did not change.)
#	Uses '-p' option of 'cp' to preserve modification times.
#	No separate log files for each command, instead their output is logged if
#		they return a non-zero exit status.
#	PATH is appended to, not overwritten.
#	Use 'type -P' instead of 'which'.
#	Fixed a few typos.
#
#	FIX 08/13/2007
#	Using new SaneSecurity URLs
#
#	FIX 06/30/2007
#	Removed the -h (human readable) option from the rsync command line
#		as this was for the help option in older versions of rsync, and
#		it's not worth maintaining two versions of the command based on
#		rsync version. Thanks for the bug report Chris
#	Changed the SCAM_SIGS_URL variable to point to the proper URL. The old one
#	worked but this one is the correct/desired URL Thanks Steve Basford.
#
#	FIX 06/27/2007
#	Fixed incorrect check on CURL return code in phish.db section
#		causing it to consider a success as a failure. Thanks
#		Leonardo Rodrigues Magalhães
#
#	FIX 05/16/2007
#	Fixed a bug where downloading phish.ndb.gz for the first time results
#		in an error and the downloaded file removed (Thanks Gary V)
#
#	NEW 05/15/2007
#	Now have option to log to system logger (notify)
#		If you do not wish to use this logging function look below for
#		SYSLOG_ON=1 and set to SYSLOG_ON=0. This also will not function
#		if logger is not installed on your system for some reason
#
#	Now logs each download stats regardless of debug status, but only outputs
#		to console if in debugging mode, or error and doesn't output
#		to system logger.
#		               (as suggested by Gary V)
#	Changed the clamdb grep to use extended pattern matching as suggested
#		by Gary V
#	Altered the rsync portions to use --stats instead of --progress and
#		look for number of files transfered for confirmation of an update
#
#	NEW 05/08/2007
#	Updated the MSRBL-* files to update vi rsync (tested version 2.6.9)
#		the current db(s) will be saved before the update and if there is a
#		problem with the download or clam db tests the old version is
#		moved back into place, an error message is produced and the
#		corrupt file is moved to filename.bad for the operator to look into
#	Changed the detection of the clam db directory it's now very fast
#		and will accommodate trailing slash (ie. /usr/local/share/clamav/) and
#		will also check for main.cvd as well as the *.inc directories since
#		apparently it's possible to have an install with only the main.cvd,
#		at least temporarily
#
#	NEW 05/05/2007
#	Fixed a potential problem with the downloaded file size being zero
#	Now test a small txt file using the downloaded sig file, if clam doesn't
#		like it we don't move it or use it. Throw an error to the operator
#	Fixed a possible issue with the log size being very large if the site is
#		busy, now only return the last line from the transmission progress
#	Changed the operation to find the clam database dir to checking for
#		the standard /usr/local/share/clamav location first, and if not there
#		ask clamscan. (save a few seconds)
#
#

# Make sure the path to your ClamAV binaries is in here, it should
# cover all normal installations
export PATH="$PATH":/bin:/usr/bin:/usr/local/bin

# The file names and URLs of the scam and phish signature files from SaneSecurity
SCAM_SIGS="scam.ndb"
SCAM_SIGS_URL="http://www.sanesecurity.com/clamav/scamsigs/scam.ndb.gz"
PHISH_SIGS="phish.ndb"
PHISH_SIGS_URL="http://www.sanesecurity.com/clamav/phishsigs/phish.ndb.gz"

# The URLs of the spam and image-spam signature files from MSRBL
MSRBL_SPAM_SIGS="MSRBL-SPAM.ndb"
MSRBL_SPAM_SIGS_URL="rsync://rsync.mirror.msrbl.com/msrbl/MSRBL-SPAM.ndb"
MSRBL_IMAGE_SIGS="MSRBL-Images.hdb"
MSRBL_IMAGE_SIGS_URL="rsync://rsync.mirror.msrbl.com/msrbl/MSRBL-Images.hdb"

# Log messages with this or greater severity to syslog
syslog_loglevel=error

# Log messages with this or greater severity to standard error
stderr_loglevel=none

# Use this syslog facility
syslog_facility=mail

# The script will sleep for a random amount of time before starting the
# actual update, unless '--sleep' is used and in this case it will sleep
# the given amount of time. This evens out the load on the update servers 
# when people # have a tendency to set cron jobs on the hour, half hour or 
# quarter hour.  The extra padding keeps the servers from being hammered 
# all at once.  These are the minimum and maximum sleep times in seconds.
sleep_time=0
min_sleep_time=30
max_sleep_time=600

# Should the script reload the clamd service
# (Should not be necessary if you have "SelfCheck" enabled in clamd.conf
# and "NotifyClamd" enabled in freshclam.conf.)
reload_clamd=0

# If the script is run as root, change the owner and group of
# the signature files to this user and group. (The username
# and group name should be separated by a colon.)
sigfile_owner_and_group=clamav:clamav

# If the script is run as root, perform downloading, checking and
# installation of the signature files as this user. (The SELinux
# security context fixing and the clamd reload need superuser
# privileges, so these will be performed as root.)
# Note: This user must be able to read and write signature files
# in ClamAV db dir.
unprivileged_user=${sigfile_owner_and_group%:*}

# Whether to preserve the temporary directory (for debugging purposes)
# on exit instead of deleting it (the default)
keep_temp_dir=0

####################################################################
# No user tunable variables below
####################################################################

####################################################################
# Logging functions
#

# Return the numeric constant associated with the given
# severity name.
#
# Usage: numeric_loglevel=`numeric_log_severity $loglevel_name`
#
numeric_log_severity()
{
	local name="$1"

	# The severity names (same as in syslog)
	local -a severity_names=(
		debug,deb,dbg
		info,inf
		notice
		warning,warn,wrn
		err,error
		crit,critical
		alert
		emerg,emergency,panic
		none,off
	)

	local i=0
	local numeric_level
	while [ -n "${severity_names[i]}" ]; do
		for levelname in ${severity_names[i]//,/ }; do
			if [ "$name" == "$levelname" ]; then
				numeric_level=$i
				break 2
			fi
		done
		let i++
	done
	if [ -z "$numeric_level" ]; then
		numeric_level=`numeric_log_severity debug`
	fi

	echo $numeric_level
}

# Log the given message with the given priority.
# Logging includes printing to stderr and sending the message to
# syslog, depending on the debug level and syslog loglevel settings.
#
# Usage: log level message [message_continuation [...]]
#
log()
{
	local level="$1"
	local -a message_parts='("${@:2}")'

	local message=`echo -e "${message_parts[@]}"`

	if [ $(numeric_log_severity $level) -ge $(numeric_log_severity $stderr_loglevel) ]; then
		echo "$program_invocation_short_name: [$level] $message" >&2
	fi
	if [ $(numeric_log_severity $level) -ge $(numeric_log_severity $syslog_loglevel) ]; then
		if [ -n "$logger" ]; then
			"$logger" -p ${syslog_facility}.${level} -i -t "$program_invocation_short_name" -- "${message//$'\n'/\\n}"
		fi
	fi
}

####################################################################
# Utility functions
#

# Run the command silently. If the command exits with a
# non-zero exit status, log an error message including the command run,
# the exit status and and the collected output, otherwise swallow the output.
#
# Usage: run_cmd "$cmd" ["$arg1" [...]]
#
run_cmd()
{
	local -a cmd_and_args='("${@}")'

	local output=`"${cmd_and_args[@]}" 2>&1`
	local exit_status=$?
	if [ $exit_status -ne 0 ]; then
		log err "Error executing command <<<${cmd_and_args[*]}>>>, exit status: $exit_status, output: <<<$output>>>"
	fi

	return $exit_status
}

# Push one or more elements to the end of the array.
#
# Usage: push array_name "$elem1" [...]
#
push()
{
	local -a array="$1" elems='("${@:2}")'

	local len=`eval echo \\\${#$array[@]}`
	for elem in "${elems[@]}"; do
		eval "$array[$len]=$elem"
		let len++
	done
}

####################################################################
# Signature file download/test/installation functions
#

# Check if ClamAV accepts the signature file,
# and moves it to the database dir if so.
# Exit status:
#	0   - sigfile was updated successfully
#	1   - sigfile was up-to-date or an error occurred
#
# Usage: check_and_install_sigfile "$file_basename"
#
check_and_install_sigfile()
{
	local filename="$1"

	local sigfile="$clam_db_dir/$filename"
	local new_sigfile="$tmp_dir/$filename"

	local sigfile_updated=0

	if [ -s "$new_sigfile" ]; then
		# First we do a quick test of the downloaded file. If ClamAV doesn't
		# like it we won't use it and issue an error to the operator
		# renaming the file so they can inspect it themselves.
		run_cmd "$clamscan" --quiet -d "$new_sigfile" "$test_file"
		local exit_status=$?
		if [ $exit_status -eq 0 ]; then
			if [ -s "$sigfile" ]; then
				run_cmd cp -pf "$sigfile" "${sigfile}.bak"
			fi
			run_cmd mv -f "$new_sigfile" "$sigfile"
			exit_status=$?
			if [ $exit_status -eq 0 ]; then
				sigfile_updated=1
			else
				log err "Cannot move '$new_sigfile' to '$sigfile', 'mv' exit status: $exit_status"
			fi
		else
			log err "ClamAV had a problem using '$new_sigfile' (exit status: $exit_status)."
			log err "We will NOT install '$new_sigfile' into the database directory."
			run_cmd mv -f "$new_sigfile" "${sigfile}.bad"
			exit_status=$?
			if [ $exit_status -eq 0 ]; then
				log err "Preserving the corrupt file as '${sigfile}.bad' for you to check."
			else
				log err "Cannot move the corrupt file from '$new_sigfile' to '${sigfile}.bad', 'mv' exit status: $exit_status."
			fi
		fi
	elif [ -e "$new_sigfile" ]; then
		log warning "'$new_sigfile' was zero bytes and will not be used!"
	fi

	local ret_val=1
	if [ $sigfile_updated -ne 0 ]; then
		log info "'$sigfile' was updated"
		ret_val=0
	else
		log info "'$sigfile' was NOT updated"
		ret_val=1
	fi

	return $ret_val
}

# Update/download a gzip-compressed signature file using CURL,
# uncompress it, check if ClamAV accepts it, and install it in
# the database directory.
# Exit status:
#	0   - sigfile was updated successfully
#	1   - sigfile was up-to-date or an error occurred
#
# Usage: update_sigfile_with_curl "$url" "$file_basename"
#
update_sigfile_with_curl()
{
	local url="$1" filename="$2"

	if [ -z "$url" ]; then
		log info "Skipping '$filename' because no URL is configured for it"
		return 1
	fi

	local sigfile_gz="$clam_db_dir/${filename}.gz"
	local new_sigfile_gz="$tmp_dir/${filename}.gz"
	local sigfile="$clam_db_dir/$filename"
	local new_sigfile="$tmp_dir/$filename"

	local sigfile_gz_updated=0

	declare -a curl_additional_flags

	# If something happend to the sig file, or this is the first time
	# this script has been run then we can't do the date test on the
	# current file so we just grab what ever is current on the site
	if [ -s "$sigfile_gz" ]; then
		log debug "Checking for newer version of '$sigfile_gz'"
		push curl_additional_flags "-z" "$sigfile_gz"
	else
		log debug "'$sigfile_gz' does not exist, so doing initial download"
	fi

	if [ $stderr_loglevel != debug ]; then
		push curl_additional_flags "-s"
	fi

	run_cmd "$curl" -R "${curl_additional_flags[@]}" -o "$new_sigfile_gz" \
		-f -v --referer ";auto" --location "$url"
	local exit_status=$?
	if [ $exit_status -eq 0 -o $exit_status -eq 22 ]; then
		# If we don't have the download or it's zero bytes
		# something went wrong and we did not get an update.
		if [ ! -s "$new_sigfile_gz" ]; then
			if [ -e "$new_sigfile_gz" ]; then
				rm -f "$new_sigfile_gz"
				log warning "'$new_sigfile_gz' was zero bytes and will not be used!"
			fi
			if [ $exit_status -eq 22 ]; then
				log warning "CURL returned an error code 22 which results from a HTTP error 4xx"
				log warning "This might be caused by the file not being updated (HTTP 412) but"
				log warning "it could be something else."
			fi
		fi
	else
		log err "CURL had a problem getting '$new_sigfile_gz' from '$url', exit status: $exit_status"
		rm -f "$new_sigfile_gz"
	fi

	if [ -s "$new_sigfile_gz" ]; then
		"$gunzip" -cdf "$new_sigfile_gz" > "$new_sigfile"
		exit_status=$?
		if [ $exit_status -eq 0 ]; then
			run_cmd mv -f "$new_sigfile_gz" "$sigfile_gz"
			exit_status=$?
			if [ $exit_status -eq 0 ]; then
				sigfile_gz_updated=1
			else
				log err "Cannot move '$new_sigfile_gz' to '$sigfile_gz', 'mv' exit status: $exit_status"
			fi
		else
			rm -f "$new_sigfile_gz"
			log err "Cannot uncompress '$new_sigfile_gz', 'gunzip' exit status: $exit_status"
		fi
	fi

	if [ $sigfile_gz_updated -ne 0 ]; then
		log info "'$sigfile_gz' was updated"
	else
		log info "'$sigfile_gz' was NOT updated"
	fi

	check_and_install_sigfile "$filename"
}

# Update/download the signature file using Rsync,
# check if ClamAV accepts it, and and installs it in
# the database directory.
# Exit status:
#	0   - sigfile was updated successfully
#	1   - sigfile was up-to-date or an error occurred
#
# Usage: update_sigfile_with_curl "$url" "$file_basename"
#
update_sigfile_with_rsync()
{
	local url="$1" filename="$2"

	if [ -z "$url" ]; then
		log info "Skipping '$filename' because no URL is configured for it"
		return 1
	fi

	local sigfile="$clam_db_dir/$filename"
	local new_sigfile="$tmp_dir/$filename"

	if [ -s "$sigfile" ]; then
		log debug "Checking for newer version of '$sigfile'"
	else
		log debug "'$sigfile' does not exist, so doing initial download"
	fi

	# Rsync will download the file only if it is different from the one in
	# $clam_db_dir. The downloaded file will be stored in $tmp_dir.
	run_cmd "$rsync" --stats -t --compare-dest="$clam_db_dir/" \
		"$url" "$new_sigfile"
	local exit_status=$?
	if [ $exit_status -ne 0 ]; then
		log err "Rsync had a problem getting '$new_sigfile' from '$url', exit status: $exit_status"
		rm -f "$new_sigfile"
	fi

	check_and_install_sigfile "$filename"
}

####################################################################
# Startup functions
#

# Check for the external programs/tools and
# set the corresponding variables to the found paths
#
# Usage: check_for_external_programs
#
check_for_external_programs()
{
	# Look for the paths to the programs we are going to need
	logger=`type -P logger`
	clamscan=`type -P clamscan`
	curl=`type -P curl`
	gunzip=`type -P gunzip`
	rsync=`type -P rsync`

	# Check if the 'logger' binary is missing
	if [ -z "$logger" -o ! -x "$logger" ]; then
		unset logger
		log err "Could not find the 'logger' program, no syslog will be attempted"
	fi

	# If we did not find any of our external programs
	# give an error message and exit
	local prg
	for prg in clamscan curl gunzip rsync; do
		if [ -z ${!prg} ]; then
			log err "Cannot find '$prg'"
			log err "Exiting."
			exit 1
		fi
	done
}

# Print usage message.
#
# Usage: print_usage
#
print_usage()
{
	echo -e "Downloads unofficial ClamAV signature files from sanesecurity.com and msrbl.com."
	echo -e "Usage: $0 [options]"
	echo -e "OPTIONS:"
	echo -e "\t--syslog-loglevel=level\t\tSets the log level for syslog to 'level'."
	echo -e "\t--stderr-loglevel=level\t\tSets the log level for stderr to 'level'."
	echo -e "\t--debug\t\t\t\tShorthand for --stderr-loglevel=debug."
	echo -e ""
	echo -e "Log level can be one of these: debug, info, notice, warning, err, crit, alert, emerg."
}

# Parse options/arguments
#
# Usage: parse_arguments
#
parse_arguments()
{
	local arg

	# Parse options/arguments
	while [ $# -ge 1 ]; do
		case "$1" in
			--debug|-d|debug|Debug|DEBUG)
				stderr_loglevel=debug
				log debug "Debug mode is ON"
				;;
			--syslog-loglevel)
				syslog_loglevel=$2
				shift
				;;
			--syslog-loglevel=*)
				syslog_loglevel=${1#--*=}
				;;
			--stderr-loglevel)
				stderr_loglevel=$2
				shift
				;;
			--stderr-loglevel=*)
				stderr_loglevel=${1#--*=}
				;;
			--unprivileged-child)
				unprivileged_child=1
				;;
			--help|-h|-\?)
				print_usage
				exit 0
				;;
			*)
				log err "Got command line argument of '$1' and I don't understand it!"
				log err "Exiting."
				exit 1
				;;
		esac
		shift
	done
}

# Create a temporary directory and arrange to remove it on exit,
# plus create an empty file to use for testing ClamScan
#
# Usage: create_temp_dir
#
create_temp_dir()
{
	tmp_dir=`mktemp -d -t ${program_invocation_short_name}.XXXXXXXX` || (
		log err "Cannot create temporary directory"
		log err "Exiting."
		exit 1
	)
	local exit_status=$?
	if [ $exit_status -ne 0 ]; then
		log err "Error running mktemp(1), exit status: $exit_status"
		log err "Exiting."
		exit 1
	fi
	log debug "Created temporary directory: '$tmp_dir'"
	if [ $keep_temp_dir -eq 0 ]; then
		trap 'rm -rf "$tmp_dir"' EXIT
	fi

	# We create a file for ClamScan to test in debug mode.
	test_file="$tmp_dir/test.file"
	touch "$test_file"
}

# Log a couple of debug messages with a summary on some parameters
#
# Usage: log_startup_summary
#
log_startup_summary()
{
	log debug "PHISH_SIGS    : $PHISH_SIGS_URL"
	log debug "SCAM_SIGS     : $SCAM_SIGS_URL"
	log debug "SPAM_SIGS     : $MSRBL_SPAM_SIGS_URL"
	log debug "IMAGE_SIGS    : $MSRBL_IMAGE_SIGS_URL"
	log debug "ClamScan      : $clamscan"
	log debug "CURL          : $curl"
	log debug "GunZip        : $gunzip"
	log debug "RSync         : $rsync"
	log debug "ClamAV db dir : $clam_db_dir"
	log debug "temp dir      : $tmp_dir"
}

# Sleep for a random time (determined by $min_sleep_time and $max_sleep_time global variables)
#
# Usage: random_sleep
#
random_sleep()
{
	if [ sleep_time == 0 ]; then
	   sleep_time=$(($RANDOM * $(($max_sleep_time-$min_sleep_time)) / 32767 + $min_sleep_time))
	fi
	log debug "Sleeping for $sleep_time seconds..."
	sleep $sleep_time
}

# Find the ClamAV db dir and set the $clam_db_dir global variable
#
# Usage: find_clam_db_dir
#
find_clam_db_dir()
{
	# Scan an empty test file with debug enabled to determine where ClamAV expects
	# to find it's signature database
	log debug "Checking for ClamAV database directory..."
	clam_db_dir=`"$clamscan" --debug "$test_file" 2>&1 | \
		sed -ne 's/\/$//; s/^.*loading databases from \(.*\)$/\1/ip' | head -1`
	log debug "Found ClamAV database directory: $clam_db_dir"

	# Check for either the daily.inc, the main.inc dirs or the main.cvd one of which
	# must exist for a functional clamav installation
	if [ ! -d "$clam_db_dir/daily.inc" -a ! -d "$clam_db_dir/main.inc" -a ! -f "$clam_db_dir/main.cvd" ]; then
		log err "None of '$clam_db_dir/daily.inc', '$clam_db_dir/main.inc',"
		log err "'$clam_db_dir/main.cvd' found in your database directory. Either '$clam_db_dir' is NOT"
		log err "the correct database path or there is something wrong with your"
		log err "ClamAV installation. This path came from your '$clamscan' so I would guess"
		log err "you need to check your clamd.conf file and/or '$clam_db_dir'"
		log err "Exiting."
		exit 1
	fi
}

#
# Change owner, group and security context of the signature files.
#
# Usage: chown_chcon sigfiles ...
#
chown_chcon()
{
	local -a sigfiles='("$@")'

	for i in "${sigfiles[@]}"; do
		[ -f "$i" ] || continue

		run_cmd chown $sigfile_owner_and_group "$i"
		exit_status=$?
		if [ $exit_status -ne 0 ]; then
			log err "chown had a problem changing ownership of signature file '$i', exit status: $exit_status"
			log err "Exiting."
			exit 1
		fi
	done

	# SELinux fix: change security context
	if [ -n "$(type -P sestatus 2>/dev/null)" ] && [ "$(sestatus | head -n 1 | awk '{ print $3 }')" == "enabled" ]; then
		for i in "${sigfiles[@]}"; do
			[ -f "$i" ] || continue

			run_cmd chcon user_u:object_r:var_t "$i"
			exit_status=$?
			if [ $exit_status -ne 0 ]; then
				log err "chcon had a problem changing security context of signature file '$i', exit status: $exit_status"
				log err "Exiting."
				exit 1
			fi
		done
	fi
}

# Reload the ClamAV daemon
#
# Usage: reload_clamav_daemon
#
reload_clamav_daemon()
{
	local -a clamd_reload_cmd
	if [ -n "`type -P service`" ]; then
		clamd_reload_cmd=(service clamd reload)
	else
		for init_script in /etc/{init,rc}.d/{clamd,clamav-daemon}; do
			if [ -x "$init_script" ]; then
				clamd_reload_cmd=("$init_script" reload-database)
				break
			fi
		done
	fi
	if [ -n "${clamd_reload_cmd[*]}" ]; then
		log info "Reloading ClamAV daemon"
		run_cmd "${clamd_reload_cmd[@]}"
	else
		log err "Cannot reload ClamAV daemon because no initscript found"
		return 1
	fi
}

####################################################################


declare logger clamscan curl gunzip rsync
declare tmp_dir test_file
declare clam_db_dir
declare unprivileged_child=0

# The short name of this script
readonly program_invocation_short_name=`basename "$0"`

# The absolute name of this script
readonly program_invocation_absolute_name=$(readlink -f "$0" || type -P "$0")

# Startup
parse_arguments "$@"
if [ "$unprivileged_child" -ne 1 ]; then
	log debug "Starting."
fi
check_for_external_programs
create_temp_dir
find_clam_db_dir
if [ "$unprivileged_child" -ne 1 ]; then
	log_startup_summary
	random_sleep
fi

# Change current directory to ClamAV database directory
# but just for the sake of safety we will use
# absolute paths for copy/move operations
cd "$clam_db_dir"

declare sigfile_updated=0
if [ "$unprivileged_child" -ne 0 -o $(id -u) -ne 0 ]; then
	# Update/download the signature files
	update_sigfile_with_curl "$SCAM_SIGS_URL" "$SCAM_SIGS" && sigfile_updated=1
	update_sigfile_with_curl "$PHISH_SIGS_URL" "$PHISH_SIGS" && sigfile_updated=1
	update_sigfile_with_rsync "$MSRBL_SPAM_SIGS_URL" "$MSRBL_SPAM_SIGS" && sigfile_updated=1
	update_sigfile_with_rsync "$MSRBL_IMAGE_SIGS_URL" "$MSRBL_IMAGE_SIGS" && sigfile_updated=1
else
	# Re-execute the script as the unprivileged user to do the download/check/install part.
	# (It exits with 0 exit status only if at least on the signature file were updated.)
	su -s $SHELL $unprivileged_user -c "'$program_invocation_absolute_name' --unprivileged-child --syslog-loglevel=$syslog_loglevel --stderr-loglevel=$stderr_loglevel" && sigfile_updated=1

	# Change owner, group and security context.
	chown_chcon "$SCAM_SIGS" "$PHISH_SIGS" "$MSRBL_SPAM_SIGS" "$MSRBL_IMAGE_SIGS"
fi

# Reload database
if [ $reload_clamd -ne 0 -a $sigfile_updated -ne 0 -a "$unprivileged_child" -eq 0 ]; then
	reload_clamav_daemon
fi

if [ "$unprivileged_child" -ne 1 ]; then
	log debug "Exiting."
fi
if [ $sigfile_updated -ne 0 ]; then
	final_exit_status=0
else
	final_exit_status=100
fi
exit $final_exit_status
