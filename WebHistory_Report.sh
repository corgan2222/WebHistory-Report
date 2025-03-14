#!/bin/sh
VER="v1.11"
#======================================================================================= © 2016-2019 Martineau v1.11
#
# Scan Web History database
#
#    WebHistory_Report     [help | -h] ['ip='{[ip_address[,...] | hostname[...]]} ['flush']] ['url='{url_string[,...]}] ['nofilter'] ['email'] ['mode=or'] ['noscript']
#                          ['date='[yyyy/mm/dd[,...]]] ['time='[hh:mm:ss[,...]]] ['sqldb='{database}] ['backup'] ['purgeallreset'] ['count'] ['sortby='column]
#
#    WebHistory_Report
#                          Will list 'Todays' URL entries in the Web History database containing strings 'facebook' OR 'youtube'
#    WebHistory_Report     count
#                          Will count 'Todays' URL entries in the Web History database containing strings 'facebook' OR 'youtube'
#                          and will only display the result count. No records are displayed on screen.
#    WebHistory_Report     nofilter
#                          Will list ALL entries in the Web History database.
#    WebHistory_Report     nofilter sortby=url
#                          Will list ALL entries in the Web History database sorted by column URL
#    WebHistory_Report     nofilter email
#                          Will list ALL entries in the Web History database and will send an email with the results
#    WebHistory_Report     url=amazon,netflix
#                          Will list URL entries in the Web History database containing strings either 'amazon' OR 'netflix'
#    WebHistory_Report     ip=192.168.1.1 url=amazon,netflix time=18:,19: mode=or
#                          Will list URL entries in the Web History database for 192.168.1.1 or between 18:00-19:59 or URLs as above
#                          Without 'mode=or' then the databse records must match ALL three criteria
#    WebHistory_Report     date=2017/02/30
#                          Will list entries in the Web History database created on '30th Feb 2017'
#                          NOTE: The date specification can be an abbreviation e.g. '2017/02' for records created in 'Feb 2017'
#    WebHistory_Report     ip=10.88.8.123, 192.168.1.120-192.168.1.123, CAMERAS
#                          Will list database entries for five devices, plus all IPs for 'CAMERAS' entry in '/jffs/configs/IPGroups'
#                          NOTE: Only MAC addresses are stored in the database so if the devices are not 'reserved/static'
#                                then the report could be inaccurate.
#    WebHistory_Report     ip=10.88.8.123 flush url="www.veryexpensiveshoes.com"
#                          Will delete all URL 'www.veryexpensiveshoes.com' history for '10.88.8.123' Ha ha - wife mode eh? ;-)
#    WebHistory_Report     ip=10.88.8.123 flush
#                          Will delete all history for '10.88.8.123'
#    WebHistory_Report     time=09:
#                          Will list entries in the Web History database created between '09:00' to '09:59'
#                          NOTE: A full time specification can be used e.g. '12:05:30' but the report may never find a match!
#    WebHistory_Report     backup
#                          The current Web History database will be backed up to '/opt/var/WebHistory/'
#    WebHistory_Report     sqldb=/opt/var/WebHistory/WebHistory.db-Backup-20180401-060000
#                          The report/queries will be extracted from the archive/backup database '/opt/var/WebHistory/WebHistory.db-Backup-20180401-060000'
#    WebHistory_Report     purgeallreset
#                          The current Web History database is PURGED of ALL history!!!!! (NOTE: a backup is taken first ;-)

# To filter by additional criteria just use grep/awk etc. to apply additional filters
#
# e.g.  ONLY show the Echo devices 'youtube' activity where the rule contains 'cats' and 'adopt'
# [CODE]./WebHistory_Report.sh ip=10.88.8.18,10.88.8.17,10.88.8.16 | grep -F "youtube" | grep -E "cats" | grep "adopt"[CODE]

# [URL="https://www.snbforums.com/threads/web-history-reporting-and-management-traffic-analyzer-aiprotection-monitor.49888/"]Web History Reporting and Management (Traffic Analyzer/Aiprotection Monitor)[/URL]

Say(){
   echo -e $$ $@ | logger -st "($(basename $0))"
}
SayT(){
   echo -e $$ $@ | logger -t "($(basename $0))"
}
#
# Print between line beginning with'#==' to first blank line inclusive
ShowHelp() {
	/usr/bin/awk '/^#==/{f=1} f{print; if (!NF) exit}' $0
}
# shellcheck disable=SC2034
ANSIColours() {
	cRESET="\e[0m";cBLA="\e[30m";cRED="\e[31m";cGRE="\e[32m";cYEL="\e[33m";cBLU="\e[34m";cMAG="\e[35m";cCYA="\e[36m";cGRA="\e[37m";cFGRESET="\e[39m"
	cBGRA="\e[90m";cBRED="\e[91m";cBGRE="\e[92m";cBYEL="\e[93m";cBBLU="\e[94m";cBMAG="\e[95m";cBCYA="\e[96m";cBWHT="\e[97m"
	aBOLD="\e[1m";aDIM="\e[2m";aUNDER="\e[4m";aBLINK="\e[5m";aREVERSE="\e[7m"
	aBOLDr="\e[21m";aDIMr="\e[22m";aUNDERr="\e[24m";aBLINKr="\e[25m";aREVERSEr="\e[27m"
	cWRED="\e[41m";cWGRE="\e[42m";cWYEL="\e[43m";cWBLU="\e[44m";cWMAG="\e[45m";cWCYA="\e[46m";cWGRA="\e[47m"
	cYBLU="\e[93;48;5;21m"
	xHOME="\e[H";xERASE="\e[K";xCSRPOS="\e[s";xPOSCSR="\e[u"
}
StatusLine() {

	local ACTION=$1
	local FLASH="$aBLINK"

	if [ "${ACTION:0:7}" != "NoANSII" ];then

		[ "${ACTION:0:7}" == "NoFLASH" ] && local FLASH=

		local TEXT=$2

		echo -en $xCSRPOS								# Save current cursor position

		case $ACTION in
			*Clear*)	echo -en ${xHOME}${cRESET}$xERASE;;
			*)			echo -en ${xHOME}${aBOLD}${FLASH}${xERASE}$TEXT;;
		esac

		echo -en $xPOSCSR								# Restore previous cursor position
	fi

}
# Function Parse(String delimiter(s) variable_names)
Parse() {
	#
	# 	Parse		"Word1,Word2|Word3" ",|" VAR1 VAR2 REST
	#				(Effectivley executes VAR1="Word1";VAR2="Word2";REST="Word3")

	local string IFS

	TEXT="$1"
	IFS="$2"
	shift 2
	read -r -- "$@" <<EOF
$TEXT
EOF
}
Chk_Entware() {

    # ARGS [wait attempts] [specific_entware_utility]

    local READY=1                  # Assume Entware Utilities are NOT available
    local ENTWARE="opkg"
    ENTWARE_UTILITY=                # Specific Entware utility to search for (Tacky GLOBAL variable returned!)

    local MAX_TRIES=30
    if [ -n "$2" ] && [ -n "$(echo $2 | grep -E '^[0-9]+$')" ];then
        local MAX_TRIES=$2
    fi

    if [ -n "$1" ] && [ -z "$(echo $1 | grep -E '^[0-9]+$')" ];then
        ENTWARE_UTILITY=$1
    else
        if [ -z "$2" ] && [ -n "$(echo $1 | grep -E '^[0-9]+$')" ];then
            MAX_TRIES=$1
        fi
    fi

   # Wait up to (default) 30 seconds to see if Entware utilities available.....
   local TRIES=0
   while [ $TRIES -lt $MAX_TRIES ];do
      if [ -n "$(which $ENTWARE)" ] && [ "$($ENTWARE -v | grep -o "version")" == "version" ];then		# Check Entware exists and it executes OK
         if [ -n "$ENTWARE_UTILITY" ];then      								# Specific Entware utility installed?
            if [ -n "$($ENTWARE list-installed $ENTWARE_UTILITY)" ];then
                READY=0                                                         # Specific Entware utility found
            else
                # Not all Entware utilities exist as a stand-alone package e.g. 'find' is in package 'findutils'
				# 	opkg files findutils
				#
				# 	Package findutils (4.6.0-1) is installed on root and has the following files:
				# 	/opt/bin/xargs
				# 	/opt/bin/find
				# Add 'executable' as 'stubby' leaves behind two directories containing the string 'stubby'
				if [ "$(which find)" == "/opt/bin/find" ];then
					if [ -d /opt ] && [ -n "$(find /opt/ -type f -executable -name $ENTWARE_UTILITY)" ];then
						READY=0														# Specific Entware utility found
					fi
				else
					logger -st "($(basename $0))" $$ "Unable to verify existence of Entware" $ENTWARE_UTILITY". Please install Entware 'find'"
				fi
            fi
         else
            READY=0                                                             # Entware utilities ready
         fi
         break
      fi
      sleep 1
      logger -st "($(basename $0))" $$ "Entware" $ENTWARE_UTILITY "not available - wait time" $((MAX_TRIES - TRIES-1))" secs left"
      local TRIES=$((TRIES + 1))
   done

   return $READY
}
SendMail(){

#=================================> Insert favorite routine here
#=================================> Insert favorite routine here
#=================================> Insert favorite routine here

	#Say "You need to edit this script and add the Sendmail function first!"

	local SENDMAIL_VER="v3.2"
	local SENDMAIL_TITLE="Martineau Notification"

	# e.g. Send_email [file | "A_single_line_text_message_in_quotes_to_be_emailed" ] [email_method]

	#		Send_email	/tmp/mnt/sda1/mail.txt
	#					Send the preprepared email defined in file '/tmp/mnt/sda1/mail.txt' via Google SMTPS:// using the 'curl' utility
	#					(Default transmit method is to use SMTPS:// using curl.)
	#		Send_email	/tmp/mnt/sda1/mail.txt sendmail
	#					Send the preprepared email defined in file '/tmp/mnt/sda1/mail.txt' using the 'sendmail' utility
	#		Send_email	"This the body text of the email - e.g. disk is FULL"
	#					Send the single line of text via Google SMTPS:// using the 'curl' utility


	local FROM="EICornes@gmail.com"
	local TO="EICornes@gmail.com"
	local USERNAME="EICornes@gmail.com"
	#NOTE: ONLY use 'Google Application' passwords e.g. 'xxxx xxxx xxxx xxxx' ('Android App')
	#	   NEVER use your normal Gmail account password!!!
	#	   ===============================================
	local PASSWORD="gmeo tvid oooz ceyo"

	# If the first arg isn't a file, then assume it is the start of a single line text message! ;-)
	if [ ! -e "$1" ];then
		local BODY=$@					# Assume message is entirely in quotes!!!
	else
		local BODY="Body: SSL/TLS"
	fi

	local USE_CURL=1
	if [ "$(echo $@ | grep -owE "\-\-sendmail" | wc -w)" -eq 1 ]; then
		local USE_CURL=0				# Use 'sendmail' rather than 'curl smtps'
		BODY=$(echo "$BODY" | sed 's/\-\-sendmail//g')
	fi

	local MYROUTER=$(nvram get computer_name)
	[ -z "$(nvram get odmpid)" ] && HARDWARE_MODEL=$(nvram get productid) || HARDWARE_MODEL=$(nvram get odmpid)
	local BUILDNO=$(nvram get buildno)
	local EXTENDNO=$(nvram get extendno)

	local FROMNAME="Martineau "$MYROUTER

	# If no email file then create a basic test email..
	if [ ! -e "$1" ];then
		# If the USB is available then use it!
		if [ -d /tmp/mnt/$MYROUTER ]; then
			local TEMPFILE="/tmp/mnt/$MYROUTER/mail.txt"
		else
			local TEMPFILE="/tmp/mail.txt"
		fi

		echo "Subject: $SENDMAIL_TITLE $SENDMAIL_VER" >$TEMPFILE
		echo "From: \"$FROMNAME\"<$FROM>" >>$TEMPFILE
		echo "Date: `date -R`" >>$TEMPFILE
		echo "" >>$TEMPFILE
		echo $BODY >>$TEMPFILE
		echo "" >>$TEMPFILE
		echo "Uptime is: `uptime | sed -e 's/.*up\(.*\)load.*/\1/' | sed 's/.//;s/.$//' | sed 's/.$//' | sed 's/.$//'`" >>$TEMPFILE
		ROUTER_UPTIME=$(awk '{printf("%d days %02d hours %02d minutes %02d seconds\n",($1/60/60/24),($1/60/60%24),($1/60%60),($1%60))}' /proc/uptime)
		echo -e "/proc/uptime is:" $ROUTER_UPTIME >>$TEMPFILE
		echo "" >>$TEMPFILE
		echo "--- " >>$TEMPFILE
		echo "Your friendly" $HARDWARE_MODEL "router.  :-)" >>$TEMPFILE
		echo "Build v"$BUILDNO $EXTENDNO >>$TEMPFILE
		echo "" >>$TEMPFILE
		echo `date` >>$TEMPFILE

	else
		if [ -z "$(grep -E "^Subject" $1)" ];then				# Prepend the email headers
			local TEMPFILE="/tmp/Mail_$$.txt"
			echo -e "Subject: $SENDMAIL_TITLE $SENDMAIL_VER : $SQL_DB_DESC Report" > $TEMPFILE
			echo -e "From: \"$FROMNAME\"" >> $TEMPFILE
			echo -e "Date: `date -R`" >> $TEMPFILE
			cat $1 >> $TEMPFILE								# Body of e-mail
			echo "" >>$TEMPFILE
			echo "Uptime is: `uptime | sed -e 's/.*up\(.*\)load.*/\1/' | sed 's/.//;s/.$//' | sed 's/.$//' | sed 's/.$//'`" >>$TEMPFILE
			ROUTER_UPTIME=$(awk '{printf("%d days %02d hours %02d minutes %02d seconds\n",($1/60/60/24),($1/60/60%24),($1/60%60),($1%60))}' /proc/uptime)
			echo -e "/proc/uptime is:" $ROUTER_UPTIME >>$TEMPFILE
			echo "" >>$TEMPFILE
			echo "--- " >>$TEMPFILE
			echo "Your friendly" $HARDWARE_MODEL "router.  :-)" >>$TEMPFILE
			echo "Build v"$BUILDNO $EXTENDNO >>$TEMPFILE
			echo "" >>$TEMPFILE
			echo `date` >>$TEMPFILE
			#cat $TEMPFILE
		else
			local TEMPFILE=$1								# Use the pre-prepared email file as-is
		fi
	fi

	# Use 'smtps://' using curl as the preferred email method unless 'sendmail' explicity requested
	if [ $USE_CURL -eq 0 ]; then
		SMTP="smtp.gmail.com:587"
		cat $TEMPFILE | sendmail -v -H"exec openssl s_client -quiet \
		-connect $SMTP -tls1 -starttls smtp" \
		-f"$FROM" \
		-au"$USERNAME" -ap"$PASSWORD" $TO
		Say "e-mail sent using sendmail SSL/TLS (non-Certificate)" $SMTP
	else
		SMTP="smtp.gmail.com:465"
		curl -s --url smtps://$SMTP \
		--mail-from "$FROM" --mail-rcpt "$TO" \
		--upload-file $TEMPFILE \
		--ssl-reqd \
		--user "$USERNAME:$PASSWORD" --insecure
		Say "e-mail sent using curl smtps:// SSL/TLS (non-Certificate)" $SMTP
	fi


	rm "/tmp/Mail_$$.txt" 2>/dev/null					# Just in case we created a prepend file!

	return 0

}
ExpandIPRange() {

	# '192.168.1.30 192.168.1.50-192.168.1.54' -> '192.168.1.30 192.168.1.50 192.168.1.51 192.168.1.52 192.168.1.53 192.168.1.54'

	local HOST_NAME=0									# Hostname found/returned
	local IP_LIST=
	local START_RANGE=
	local END_RANGE=
	local NUM=
	local MAX=

	local LANIPADDR=`nvram get lan_ipaddr`
	local LAN_PREFIX=${LANIPADDR%.*}					# 1.2.3.99 -> 1.2.3

	for THIS in $@
		do

			if [ -n "$(echo "$THIS" | grep -E "^#")" ];then
				break				# Ignore comment
			fi

			# If any alphabetic characters then assume it is a name e.g. LIFX-Table_light
			if [ -z "$(echo $THIS | grep "[A-Za-z]")" ];then

				if [ -n "$(echo $THIS | grep "-")" ];then

					Parse $THIS "-" START_RANGE END_RANGE				# 1.2.3.90-1.2.3.99 -> 1.2.3.90 1.2.3.99
					local START_PREFIX=${START_RANGE%.*}				# 1.2.3.90 -> 1.2.3
					local END_PREFIX=${END_RANGE%.*}					# 1.2.3.99 -> 1.2.3

					if [ "$START_PREFIX" != "$END_PREFIX" ];then		# Restrict range of devices to 254
						Say "***ERROR*** invalid IP range" $THIS
						echo ""
						return 100
					fi

					NUM=${START_RANGE##*.}								# Extract 4th octet 1.2.3.90 -> 90
					MAX=${END_RANGE##*.}								# Extract 4th octet 1.2.3.99 -> 99
					while [ $NUM -le $MAX ]
						do
							IP_LIST=$IP_LIST" "$START_PREFIX"."$NUM
							NUM=$(($NUM+1))
						done
				else
					local THIS_PREFIX=${THIS%.*}
					if [ "$THIS_PREFIX" != "$LAN_PREFIX" ];then
						Say "***ERROR '"$THIS"' is not on this LAN '"$LAN_PREFIX".0/24'"
						echo ""
						return 200
					else
						IP_LIST=$IP_LIST" "$THIS						# Add to list
					fi
				fi
			else
				# Let the caller ultimately decide if non-IP is valid!!!
				#Say  "**Warning non-IP" $THIS
				IP_LIST=$IP_LIST" "$THIS								# Add to list
				HOST_NAME=1
			fi

			shift 1
		done

	echo $IP_LIST

	if [ $HOST_NAME -eq 1 ];then
		return 300
	else
	    return 0
	fi
}
Convert_TO_IP () {

	# Perform a lookup if a hostname (or I/P address) is supplied and is not known to PING
	# NOTE: etc/host.dnsmasq is in format
	#
	#       I/P address    hostname
	#

	local USEPATH="/jffs/configs"

	if [ -n "$1" ];then

		if [ -z $2 ];then									# Name to IP Address
		   local IP_NAME=$(echo $1 | tr '[a-z]' '[A-Z]')

		   local IP_RANGE=$(ping -c1 -t1 -w1 $IP_NAME 2>&1 | tr -d '():' | awk '/^PING/{print $3}')

		   # 127.0.53.53 for ANDROID? https://github.com/laravel/valet/issues/115
		   if [ -n "$(echo $IP_RANGE | grep -E "^127")" ];then
			  local IP_RANGE=
		   fi

		   if [ -z "$IP_RANGE" ];then		# Not PINGable so lookup static

			  IP_RANGE=$(grep -i "$IP_NAME" /etc/hosts.dnsmasq  | awk '{print $1}')
			  #logger -s -t "($(basename $0))" $$ "Lookup '$IP_NAME' in DNSMASQ returned:>$IP_RANGE<"

			  # If entry not matched in /etc /hosts.dnsmasq see if it exists in our IPGroups lookup file
			  #
			  #       KEY     I/P address[ {,|-} I/P address]
			  #
			  if [ -z "$IP_RANGE" ] && [ -f $USEPATH/IPGroups ];then
				 #IP_RANGE=$(grep -i "^$IP_NAME" $USEPATH/IPGroups | awk '{print $2}')
				 IP_RANGE=$(grep -i "^$IP_NAME" $USEPATH/IPGroups  | awk '{$1=""; print $0}')	# All columns except 1st to allow '#comments' and
	#																									#     spaces and ',' between IPs v1.07
				 #logger -s -t "($(basename $0))" $$ "Lookup '$IP_NAME' in '$USEPATH/IPGroups' returned:>$IP_RANGE<"
			  fi
		   fi
		else												# IP Address to name
			IP_RANGE=$(nslookup $1 | grep "Address" | grep -v localhost | cut -d" " -f4)
		fi
	else
	   local IP_RANGE=									# Return a default WiFi Client????
	   #logger -s -t "($(basename $0))" $$ "DEFAULT '$IP_NAME' lookup returned:>$IP_RANGE<"
	fi

	echo $IP_RANGE
}
Hostname_from_IP () {

	local HOSTNAMES=

	for IP in $@
		do
			local HOSTNAME=$(Convert_TO_IP "$IP" "Reverse")
			HOSTNAMES=$HOSTNAMES" "$HOSTNAME
		done
	echo $HOSTNAMES
}
Is_Private_IPv4 () {
	# 127.  0.0.0 – 127.255.255.255     127.0.0.0 /8
	# 10.   0.0.0 –  10.255.255.255      10.0.0.0 /8
	# 172. 16.0.0 – 172. 31.255.255    172.16.0.0 /12
	# 192.168.0.0 – 192.168.255.255   192.168.0.0 /16
	#grep -oE "(^192\.168\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])$)|(^172\.([1][6-9]|[2][0-9]|[3][0-1])\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])$)|(^10\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])\.([0-9]|[0-9][0-9]|[0-2][0-5][0-5])$)"
	grep -oE "(^127\.)|(^(0)?10\.)|(^172\.(0)?1[6-9]\.)|(^172\.(0)?2[0-9]\.)|(^172\.(0)?3[0-1]\.)|(^169\.254\.)|(^192\.168\.)"
}
Is_MAC_Address() {
	grep -oE "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}"
}
Filter_This(){
	grep -E "$1"
}
MAC_to_IP() {

		# Convert MAC into IP address
		local FN="/etc/ethers"

		local RESULT=

		if [ $FIRMWARE -gt 38201 ];then
			# etc/ethers no longer exists/used
			# Instead /etc/dnsmasq.conf contains
			#         dhcp-host=00:22:B0:B5:BB:1A,10.88.8.254
			FN="/etc/dnsmasq.conf"
			local ADDR_LIST=$(grep -i "$MAC" "$FN" | awk 'BEGIN {FS=","} {print $2}')
		else
			local ADDR_LIST=$(grep -i "$MAC" "$FN" | awk '{print $2}')
		fi

		if [ -n "$ADDR_LIST" ];then
			IP_RANGE=$ADDR_LIST
			IP_ADDR=`grep -i -w "$IP_RANGE" /etc/hosts.dnsmasq | awk '{print $1}'`
			HOST_NAME=`grep -i -w "$IP_RANGE" /etc/hosts.dnsmasq | awk '{print $2}'`
			RESULT=$HOST_NAME" "$IP_ADDR
		else
			RESULT="***ERROR MAC Address not on LAN ("$FN"): '"$2"'"
		fi

		echo "$RESULT"
}
Backup_DB() {

	local DB=$1

	local DBNAME=$(basename "$DB")

	local DB_DIR=${DBNAME%.*}

	local NOW=$(date +"%Y%m%d-%H%M%S")    # current date and time

	echo -en $cBRED >&2

	mkdir -p /opt/var/$DB_DIR
	cp -p $DB /opt/var/$DB_DIR/$DBNAME-Backup-$NOW
	RC=$?
	if [ $RC -eq 0 ];then
		echo -en $cBGRE >&2
		Say "'"$DB"' backup completed successfully"
	else
		echo -e "\a"
		Say "***ERROR '"$DB"' backup FAILED!"
	fi

	return $RC

	echo -en $cRESET >&2

}
#########################################################Main#############################################
Main() { true; }			# Syntax that is Atom Shellchecker compatible!

ANSIColours

MYROUTER=$(nvram get computer_name)

FIRMWARE=$(echo $(nvram get buildno) | awk 'BEGIN { FS = "." } {printf("%03d%02d",$1,$2)}')

# Need assistance ?
if [ "$1" == "-h" ] || [ "$1" == "help" ];then
	clear													# v1.08
	echo -e $cBWHT
	ShowHelp
	echo -e $cRESET
	exit 0
fi

# "dpi: TrendMicro function can't use under load-balance mode" 

# v384.11 now includes '/usr/sbin/sqlite3' 				# v1.11
if [ -z "$(which sqlite3)" ];then
	Chk_Entware                'sqlite3'  || { echo -e $cBRED"\a\n\t\t***ERROR*** Entware" $ENTWARE_UTILITY "not available\n"$cRESET;exit 99; }
fi

SQL_DB_DESC="Web History"
SQL_TABLE="history"
SQL_DATABASE=

TITLE=$SQL_DB_DESC" starting....."

FILTER_INUSE=

CMDNOFILTER=										# Use the default URL list
MODE="AND"											# v1.03 Default selection criteria 'AND' between filters
WHERE=												# v1.03 SQL WHERE clause
SEND_EMAIL=0										# Don't send report via email
CMDNOSCRIPT=										# v1.03 Execute this script after SQL SELECT
CMDIPFLUSH=											# v1.06 Purge all history for selected IPs
IP_CNT=0
SORTBY="time"										# Default sort column
SORTBY_DESC=										# Implied!
COLORTIME=$cBGRE									# Highlight Default sort column 'time'
COLORMAC="$cBCYA"
COLORIP="$cBCYA"
COLORURL="$cBCYA"

USE_TODAYS_DATE=1									# v1.08
USE_CURRENT_HOUR=1									# v1.08

# Check options
DUMMY="=================================================================== Options"
while [ $# -gt 0 ]; do    # Until you run out of parameters . . .		# v1.07
  case "$1" in
	mode=*)
			OPT=$(echo "$1" | sed -n "s/^.*mode=//p" | awk '{print $1}')
			case $OPT in
				"")			MODE=OR;;				# Override the default; 'mode=' is a shortcut!
				or|OR)		MODE=OR;;
				and|AND) 	MODE=AND;;
				*) 	echo -e $cBRED"\a\n\t\t***ERROR INVALID mode '$1'\n"$cRESET
					exit 99
					;;
			esac
			echo $WHERE
			[ -n "$FILTER_INUSE" ] && { echo -e $cBRED"\a\n\t\t***ERROR '$1' MUST precede filter specification '$FILTER_INUSE'\n"$cRESET; exit 99;}
			;;
	noscript)
			CMDNOSCRIPT="NoScript"
			;;
	count)
			CMDCOUNT="CountONLY"
			CMDCOUNT_DESC=$cBYEL"***Summary only;"$cRESET
			;;
	sqldb=*)									# Override default database
			SQL_DATABASE=$(echo "$1" | sed -n "s/^.*sqldb=//p" | awk '{print $1}')
			;;
	email)
			SEND_EMAIL=1
			MAILFILE="/tmp/WebHistory.txt"
			EMAILACTION=" > "$MAILFILE
			EMAIL_DESC="E-mailing results,"
			echo -e > $MAILFILE
			;;
	date=*)
			USE_TODAYS_DATE=0								# v1.08

			DATE_LIST="$(echo "$1" | sed -n "s/^.*date=//p" | awk '{print $1}' | tr ',' ' ')"

			if [ -n "$DATE_LIST" ];then					# v1.08
				DATE_FILTER=			# Used for Display info
				DATE_CNT=0
				[ -z "$FILTER_INUSE" ] && FILTER_DESC="by Date" || FILTER_DESC=$FILTER_DESC", "$MODE" by Date"

				DATE_SQL=				# v1.04 SQL statement for multiple 'DATE match'
				for DATE in $DATE_LIST
					do
						# SQL format is YYYY-MM-DD so change YYYY/MM/DD ->YYYY-MM-DD
						DATE=$(echo "$DATE" | tr '/' '-')
						[ $DATE_CNT -eq 0 ] && DATE_FILTER=$DATE_FILTER""$DATE || DATE_FILTER=$DATE_FILTER"|"$DATE
						DATE_CNT=$((DATE_CNT+1))
						[ -z "$DATE_SQL" ] && DATE_SQL=$DATE_SQL"(time LIKE '"$DATE"%'" || DATE_SQL=$DATE_SQL" OR time LIKE '"$DATE"%'"
					done
				[ -z "$FILTER_INUSE" ] && FILTER_INUSE=$DATE_FILTER || FILTER_INUSE=$FILTER_INUSE"|"$DATE_FILTER

				[ -z "$WHERE" ] && WHERE="WHERE ("$DATE_SQL")" || WHERE=$WHERE" "$MODE" "$DATE_SQL")"	# v1.04
			fi
			;;
	time=*)
			USE_CURRENT_HOUR=0								# v1.08

			TIME_LIST="$(echo "$1" | sed -n "s/^.*time=//p" | awk '{print $1}' | tr ',' ' ')"

			if [ -n "$TIME_LIST" ];then					# v1.08
				TIME_FILTER=			# Used for Display info
				TIME_CNT=0
				[ -z "$FILTER_INUSE" ] && FILTER_DESC="by Time" || FILTER_DESC=$FILTER_DESC", "$MODE" by Time"

				TIME_SQL=				# v1.04 SQL statement for multiple 'TIME match'
				for TIME in $TIME_LIST
					do
						# Minimum must be 'nn' or 'HH:' or 'HH:MM' format 					# v1.07
						# NOTE 'time=10' will match anywhere e.g. '10:01:02' (HH:) as expected but also '03:10:59' (MM:)
						case "${#TIME}" in
							2)	[ $(echo "$TIME" | grep -oE "^([0-1][0-9])|^(2[0-3])$") ]				|| { echo -e $cBRED"\a\n\t\t***ERROR time='$TIME' (HH format) invalid\n"$cRESET;   exit 55; } ;;
							3)	[ $(echo "$TIME" | grep -oE "^([0-1][0-9])|^(2[0-3])(:)?") ]			|| { echo -e $cBRED"\a\n\t\t***ERROR time='$TIME' (HH: format) invalid\n"$cRESET;  exit 66; } ;;
							5)	[ $(echo "$TIME" | grep -oE "^([0-1][0-9])|^(2[0-3]):[0-5][0-9]$") ]	|| { echo -e $cBRED"\a\n\t\t***ERROR time='$TIME' (HH:MM format) invalid\n"$cRESET;exit 77; } ;;
							*)	{ echo -e $cBRED"\a\n\t\tSQL time='$TIME' invalid format (HH:MM:SS is deemed illogical for SQL requests)\n"$cRESET;exit 99; };;
						esac

						[ $TIME_CNT -eq 0 ] && TIME_FILTER=$TIME_FILTER""$TIME || TIME_FILTER=$TIME_FILTER"|"$TIME
						TIME_CNT=$((TIME_CNT+1))
						[ -z "$TIME_SQL" ] && TIME_SQL=$TIME_SQL"(time LIKE '% "$TIME"%'" || TIME_SQL=$TIME_SQL" OR time LIKE '% "$TIME"%'" #v1.07 Fix
					done
				[ -z "$FILTER_INUSE" ] && FILTER_INUSE=$TIME_FILTER || FILTER_INUSE=$FILTER_INUSE"|"$TIME_FILTER

				if [ -z "$CMDNOSCRIPT" ] && [ $(echo $@ | grep -cw "noscript") -eq 0 ];then
					[ -z "$WHERE" ] && WHERE="WHERE ("$TIME_SQL")" || WHERE=$WHERE" "$MODE" "$TIME_SQL")"	# v1.04
				fi
			fi
			;;
	flush*)
			# *** Unique to IP processing***
			if [ $IP_CNT -eq 0 ];then
				echo -e $cBRED"\a\n\t\t***ERROR Missing 'ip=' arg as 'flush' is only valid in this context 'ip=    flush'\n"$cRESET
				exit 99
			fi
			CMDIPFLUSH="IPFlush"
			;;
	ip=*)
			# If Hostname/IP then filter on MAC address
			CMDIP=$(echo "$1" | sed -n "s/^.*ip=//p" | awk '{print $1}' | tr ',' ' ')

			GROUP_FOUND=0
			IP_GROUP_LIST=$CMDIP
			while true;do										# Iterate to expand any Groups within a Group
				for ITEM in $IP_GROUP_LIST
					do
						if [ -z "$(echo "$ITEM" | Is_Private_IPv4 )" ];then
							# Check for group names, and expand as necessary
							#	e.g. '192.168.1.30,192.168.1.50-192.168.1.54' -> '192.168.1.30 192.168.1.50 192.168.1.51 192.168.1.52 192.168.1.53 192.168.1.54'
							if [ -f "/jffs/configs/IPGroups" ];then		# '/jffs/configs/IPGroups' two columns
																		# ID xxx.xxx.xxx.xxx[[,xxx.xxx.xxx.xxx][-xxx.xxx.xxx.xxx]
								GROUP_IP=$(grep -iwE -m 1 "^$ITEM" /jffs/configs/IPGroups | awk '{$1=""; print $0}')
								if [ -n "$GROUP_IP" ];then
									GROUP_FOUND=1
									# Expand the list of IPs as necessary
									#	e.g. '192.168.1.30,192.168.1.50-192.168.1.54' -> '192.168.1.30 192.168.1.50 192.168.1.51 192.168.1.52 192.168.1.53 192.168.1.54'
									GROUP_IP=$(echo $GROUP_IP | tr ',' ' ')			# CSVs ?
									GROUP_IP=$(echo $GROUP_IP | tr ':' '-')			# Alternative range spec xxx.xxx.xxx.xxx:xxx.xxx.xxx.xxx
								else
									# Perform lookup
									GROUP_IP=$(nslookup "$ITEM" | grep -woE '([0-9]{1,3}\.){3}[0-9]{1,3}' | awk 'NR>2')
									if [ -z "$GROUP_IP" ];then
										echo -e $cBRED"\a\n\t\t***ERROR Hostname '$1' INVALID\n"$cRESET
										exit 99
									fi
								fi
							else
								GROUP_IP=$ITEM
							fi

							# Expand any ranges - allow Hostnames e.g. LIFX-Table_light to pass through
							if [ -n "$(echo "$GROUP_IP" | grep "-")" ];then		# xxx-yyy range ?
								GROUP_IP="$(ExpandIPRange "$GROUP_IP")"
								RC=$?													# Should really check
							fi
							[ -n "$GROUP_IP" ] && LAN_IPS=$LAN_IPS" "$GROUP_IP
						else
							LAN_IPS=$LAN_IPS" "$ITEM
						fi
					done

					if [ $GROUP_FOUND -eq 0 ];then
						break
					fi

					IP_GROUP_LIST=$LAN_IPS			# Keep expanding
					LAN_IPS=
					GROUP_FOUND=0
			done

			LAN_IPS=$(echo "$LAN_IPS" | sed 's/^ //p')
			LAN_IPS=$(echo "$LAN_IPS" | awk '{for (i=1;i<=NF;i++) if (!a[$i]++) printf("%s%s",$i,FS)}')	# Remove duplicates

			IP_FILTER=				# Used for Display info
			IP_CNT=0
			[ -z "$FILTER_INUSE" ] && FILTER_DESC="by IP" || FILTER_DESC=$FILTER_DESC", "$MODE" by IP"

			MAC_SQL=				# v1.04 SQL statement for multiple 'MAC match'
			for IP in $LAN_IPS
				do
					# Convert IP to MAC
					XIP=$(echo "$IP" | sed 's/\./\\\./g')
					MAC=$(grep -i "${XIP}$" /etc/dnsmasq.conf | awk 'BEGIN {FS=","} {print $1}' | sed -n "s/^dhcp-host=//p")
					[ $IP_CNT -eq 0 ] && IP_FILTER=$IP_FILTER""$IP || IP_FILTER=$IP_FILTER"|"$IP
					IP_CNT=$((IP_CNT+1))
					[ -z "$MAC_SQL" ] && MAC_SQL=$MAC_SQL"(mac LIKE '"$MAC"%'" || MAC_SQL=$MAC_SQL" OR mac LIKE '"$MAC"%'"
				done

			[ -z "$FILTER_INUSE" ] && FILTER_INUSE=$IP_FILTER || FILTER_INUSE=$FILTER_INUSE"|"$IP_FILTER

			[ -z "$WHERE" ] && WHERE="WHERE ("$MAC_SQL")" || WHERE=$WHERE" "$MODE" "$MAC_SQL")"	# v1.04

			# *** Unique to IP processing***
			if [ -n "$CMDIPFLUSH" ];then		# Should we 'flush' the history for these IPs ?
				FILTER_DESC=$FILTER_DESC", and they will have their history FLUSHED!"
			fi
			;;
	url=*)
			URL_LIST="$(echo "$1" | sed -n "s/^.*url=//p" | awk '{print $1}' | tr ',' ' ')"

			URL_FILTER=				# Used for Display info
			URL_CNT=0
			[ -z "$FILTER_INUSE" ] && FILTER_DESC="by URL" || FILTER_DESC=$FILTER_DESC", "$MODE" by URL"

			URL_SQL=				# v1.04 SQL statement for multiple 'URL match'
			for URL in $URL_LIST
				do
					[ $URL_CNT -eq 0 ] && URL_FILTER=$URL_FILTER""$URL || URL_FILTER=$URL_FILTER"|"$URL
					URL_CNT=$((URL_CNT+1))
					[ -z "$URL_SQL" ] && URL_SQL=$URL_SQL"(url LIKE '%"$URL"%'" || URL_SQL=$URL_SQL" OR url LIKE '%"$URL"%'"
				done
			[ -z "$FILTER_INUSE" ] && FILTER_INUSE=$URL_FILTER || FILTER_INUSE=$FILTER_INUSE"|"$URL_FILTER


			[ -z "$WHERE" ] && WHERE="WHERE ("$URL_SQL")" || WHERE=$WHERE" "$MODE" "$URL_SQL")"		# v1.04
			;;
	nofilter)
			CMDNOFILTER="NoFilter"
			;;
	backup)
			CMDBACKUP="Backup"
			;;
	purgeallreset)
			CMDPURGEALLRESET="PurgeAllReset"
			;;
	noansii)
			CMDNOANSII="NoANSII"
			;;
	sortby=*)
			CMDSORTBY="$(echo "$1" | sed -n "s/^.*sortby=//p" | awk '{print $1}' | tr ',' ' ')"
			case $CMDSORTBY in
				time)	SORTBY="time";;
				mac)	SORTBY="mac";SORTBY_DESC="${cBGRE}Sorted by 'mac';";COLORTIME=$cBCYA;COLORMAC=$cBGRE;;
				url)	SORTBY="url";SORTBY_DESC="${cBGRE}Sorted by 'url';";COLORTIME=$cBCYA;COLORURL=$cBGRE;;
				ip)		UNIXSORT="| sort -k 7";COLORTIME=$cBCYA;COLORIP=$cBGRE;;
				*)
						echo -e $cBRED"\a\n\t***ERROR Sort column '"$1" INVALID '(time, mac, url, ip)'\n"$cRESET
						exit 99
				;;
			esac
			;;
	*)
			echo -e $cBRED"\a\n\t***ERROR unrecognised directive '"$1"'\n"$cRESET
			exit 99
			;;
  esac
  shift       # Check next set of parameters.
done

# Use Today's date and current hour?
if [ $USE_TODAYS_DATE  -eq 1 ];then									# v1.08 Default is Todays's date
	DATE_FILTER=$(date "+%F")
	DATE_SQL="(time LIKE '"$DATE_FILTER"%'"
	[ -z "$FILTER_INUSE" ] && FILTER_DESC="by Today" || FILTER_DESC=$FILTER_DESC", "$MODE" by Today"
	[ -z "$WHERE" ] && WHERE="WHERE ("$DATE_SQL")" || WHERE=$WHERE" "$MODE" "$DATE_SQL")"
	[ -z "$FILTER_INUSE" ] && FILTER_INUSE=$DATE_FILTER || FILTER_INUSE=$FILTER_INUSE"|"$DATE_FILTER
fi
if [ $USE_CURRENT_HOUR -eq 1 ];then									# v1.08 Default is current hour
	TIME_FILTER=$(date "+%H")":"
	TIME_SQL="(time LIKE '% "$TIME_FILTER"%'"

	[ -z "$FILTER_INUSE" ] && FILTER_DESC="by current hour" || FILTER_DESC=$FILTER_DESC", "$MODE" by current hour"
	[ -z "$WHERE" ] && WHERE="WHERE ("$TIME_SQL")" || WHERE=$WHERE" "$MODE" "$TIME_SQL")"
	[ -z "$FILTER_INUSE" ] && FILTER_INUSE=$TIME_FILTER|| FILTER_INUSE=$FILTER_INUSE"|"$TIME_FILTER
fi

# Remember to terminate the SQL 'WHERE' clause!
[ -n "$WHERE" ] && WHERE=$WHERE")"

if [ -z "$CMDNOFILTER" ];then
	# Default filter
	if [ -z "$FILTER_INUSE" ];then
		DATE_FILTER=$(date "+%F")										# v1.05
		URL_FILTER="facebook|youtube"
		FILTER_INUSE=$DATE_FILTER"|"$URL_FILTER
		IP_FILTER="¬";TIME_FILTER="¬"									# v1.07 unused filters cannot be NULL
		if [ "$MODE" == "AND" ];then									# v1.07
			FILTER_DESC="by today's Facebook OR Youtube URL activity"
			WHERE="WHERE ((time LIKE '"$(date "+%F")"%' AND url LIKE '%youtube%') OR (time LIKE '"$(date "+%F")"%' AND url LIKE '%facebook%'))"
		else
			FILTER_DESC="by today's activity AND any previous Facebook OR Youtube URL activity"
			WHERE="WHERE (time LIKE '"$(date "+%F")"%' OR url LIKE '%youtube%' OR url LIKE '%facebook%')"
		fi
	fi
else
	FILTER_DESC="ALL i.e. no filter"
	WHERE=
fi

# Find appropriate database '/jffs/.sys/WebHistory/WebHistory.db'
if [ -z $SQL_DATABASE ];then
	SQL_DATABASE="$(find /jffs/.sys/ -name WebHistory.db)"
	if [ $(find /jffs/.sys -name WebHistory.db | wc -l) -ne 1 ];then
		if [ $(find /jffs/.sys -name WebHistory.db | wc -l) -gt 1 ];then
			echo -e $cBRED"\a\n\t\t***ERROR Multiple $SQL_DB_DESC databases '"$SQL_DATABASE"'found??!!\n"$cRESET
			exit 99
		fi
	fi
fi

# Validate Web History database
if [ ! -f $SQL_DATABASE ];then
	echo -e $cBRED"\a\n\t\t***ERROR $SQL_DB_DESC database '"$SQL_DATABASE"' NOT found!\n"$cRESET
	exit 98
fi

[ -n "$CMDNOANSII" ] && SQLDB_TITLE="'"$SQL_DATABASE"'"

# Should the backup be performed?
if [ -n "$CMDBACKUP" ];then		# v1.06
	echo -e
	Backup_DB "$SQL_DATABASE"
	echo -e $cRESET
	exit 0
fi

if [ -n "$CMDPURGEALLRESET" ];then
	echo -e

	echo -en ${cBRED}$aBLINK"\a\n\t\t\t****** WARNING are you sure? ******\n\n\t\t\t"${cRESET}$cBYEL"Enter "$cBWHT"ContinueOK!"$cBYEL" or press "$cBWHT"ENTER"$CBYEL" key to"$cBYEL" ABORT\n\t\t\t    >>"$cRESET
	read OPT
	if [ -n "$(echo "$OPT" | grep -oF "ContinueOK!")" ];then
		echo -e
		Backup_DB "$SQL_DATABASE"

		/usr/sbin/WebHistory -z
		/usr/sbin/WebHistory -e
		Say $VER "'"$SQL_DATABASE"' PURGED and RESET."
	else
		echo -e $cBWHT"\n\t\t\tRequest cancelled!"
	fi
	echo -e $cRESET
	exit 0
fi

##################################################################Display#####################################################
clear

echo -e $cBWHT
Say $VER "$TITLE"$SQLDB_TITLE

# Hyperlink support is native under Xshell5/MobaXterm. (Xshell5 visually shows which text is URL clickable ;-)
# MobaXterm: CTRL+Click the URL (must be prefixed with 'http')
# PuTTY: https://www.chiark.greenend.org.uk/~sgtatham/putty/wishlist/url-launching.html
#
# Prevent double spacing between report lines by changing font size
# MobaXTerm: CTRL+MouseScrollWheel
# PuTTY:     ClearType Andale Mono 9pt
#
echo -e $cBYEL"\tNOTE: Columns in "$cBWHT"white"${cRESET}$cBYEL" are eligible for filters; "$cBRED"red text"${cRESET}$cBYEL" indicates a match on the filters requested; (URLs are Xshell5/MobaXterm hyperlinks)"
echo -e "\n\t"${CMDCOUNT_DESC}${SORTBY_DESC}${EMAIL_DESC}$cBMAG"Filter" $FILTER_DESC "==> '"$FILTER_INUSE"'"



# Execute this script i.e. create report/email ?
if [ -z "$CMDNOSCRIPT" ];then

	printf '\n\t\t%b%b %-12s %-10s %b%-20s %-18s %-16s %b%-44s\n\n' "$cBCYA" "$COLORTIME" "YYYY/MM/DD" " HH:MM:SS"  "$cBCYA" "  MAC address" "  Host Name" "   IP address" "$COLORURL" "    URL"
	echo -en $cRESET

	# v1.07 unused filters cannot be NULL
	[ -z "$DATE_FILTER" ] && DATE_FILTER="¬"
	[ -z "$TIME_FILTER" ] && TIME_FILTER="¬"
	[ -z "$IP_FILTER"   ] && IP_FILTER="¬"
	[ -z "$URL_FILTER"  ] && URL_FILTER="¬"

	StatusLine $CMDNOANSII"Update" ${cYBLU}$aBOLD"Processing '$SQL_DATABASE' database....please wait!"

	RESULT_PAGECNT=0											# v1.08 No. records shown on screen
	RESULT_CNT=0												# v1.08 Total number of matching records

	echo -en $cBRED											# Just in case SQL error e.g. 'Error: database is locked'

	# Display Summary cont of matches  ONLY?
	if [ -n "$CMDCOUNT" ];then
		RESULT_CNT=$(sqlite3 $SQL_DATABASE "SELECT datetime(timestamp, 'unixepoch', 'localtime') AS time,  count(*) FROM $SQL_TABLE $WHERE ORDER BY $SORTBY;"  | cut -d'|' -f2)
		#echo -e $CMDCOUNT_DESC
	else
		sqlite3 $SQL_DATABASE "SELECT datetime(timestamp, 'unixepoch', 'localtime') AS time, mac, url FROM $SQL_TABLE $WHERE ORDER BY $SORTBY;" | while IFS= read -r LINE

			do

				if [ -n "$(echo $LINE | grep -F "SQLite        version")" ];then		# Webhistory -z ???????
					break
				fi

				if [ -n "$(echo $LINE | grep -F "Error: database is locked")" ];then
					break
				fi

				[ -z "$RECORD_CNT" ] && RECORD_CNT=0

				DATE=${LINE:0:10}

				TIME=${LINE:11:8}

				MAC=${LINE:20:17}

				DESC=$(MAC_to_IP "$MAC")
				HOSTNAME=${DESC% *}									# First word (' ' delimiter)
				IP=${DESC##* }										# Last word  (' ' delimiter)
				if [ "${HOSTNAME:0:3}" == "***" ];then
					HOSTNAME="n/a"
					IP="n/a"
				fi

				URL=${LINE##*|}										# Last word ('|' delimiter)


				# DEBUG_LINE=">"$LINE"<"
				# DEBUG_FILTER_INUSE=">"$FILTER_INUSE"<"
				# DEBUG_DATE=">"$DATE"<"
				# DEBUG_FILTER_DATE=">"$DATE_FILTER"<"
				# DEBUG_TIME=$TIME
				# DEBUG_FILTER_TIME=">"$TIME_FILTER"<"
				# DEBUG_MAC=$MAC
				# DEBUG_FILTER_MAC=">"$MAC_FILTER"<"
				# DEBUG_DESC=$DESC
				# DEBUG_HOSTNAME=$HOSTNAME
				# DEBUG_IP=$IP
				# DEBUG_FILTER_IP=">"$IP_FILTER"<"
				# DEBUG_CAT=$CAT
				# DEBUG_FILTER_CAT=">"$CAT_FILTER"<"
				# DEBUG_APP=$APP
				# DEBUG_FILTER_APP=">"$APP_FILTER"<"

				# Cosmetic highlighting! ;-)
				if echo "$DATE" | grep -qE "$DATE_FILTER" ;then	# Date filter match? # YYYY-MM-DD
					COLOUR_DATE=$cBRED
				else
					COLOUR_DATE=$cRESET
				fi

				if echo "$TIME" | grep -qE "$TIME_FILTER" ;then				# Time filter match? # HH:MM:SS
					COLOUR_TIME=$cBRED
				else
					COLOUR_TIME=$cRESET
				fi

				if echo "$MAC" | grep -qE "$IP_FILTER" ;then			# v1.06 fix MAC filter match?
					COLOUR_IP=$cBRED
				else
					COLOUR_IP=$cRESET
				fi

				if [ -n "$CMDIPFLUSH" ];then
					COLOUR_URL=$cBRED
					URL=$URL"**FLUSHED"
				else
					if echo "$URL" | grep -qE "$URL_FILTER" ;then			# URL filter match?
						COLOUR_URL=$cBRED
					else
						COLOUR_URL=$cRESET
					fi
				fi

				#
				# SQL format is YYYY-MM-DD so convert to EU ->YYYY/MM/DD
				DATE=$(echo "$DATE" | tr '-' '/')

				printf '\t\t%b %-12s %b %-10s %b %-20s %-18s %b %-16s %b http://%s\n' "$COLOUR_DATE" "$DATE"  "$COLOUR_TIME" "$TIME" "$cBBLU" "$MAC" "$HOSTNAME" "$COLOUR_IP" "$IP" "$COLOUR_URL" "$URL"
				if [ $SEND_EMAIL -eq 1 ];then
					printf '%-12s %-10s %-20s %-18s %-16s http://%s\n' "$(echo $LINE | awk '{print $1" "$2}')" "$MAC" ""$(echo $DESC | awk '{print $1}')"" ""$(echo $DESC | awk '{print $NF}')"" ""$(echo $LINE | awk '{print $NF}')"" >>$MAILFILE # v1.08
				fi
				echo -en $cRESET

				RECORD_CNT=$((RECORD_CNT+1))
				nvram set tmp_WH_TOTAL=$RECORD_CNT										# Damn subshells VERY UGLY HACK :-(


			done


		# Delete specified URL history for device if 'url=' specified otherwise
		# if 'ip=10.88.8.1 flush' then mass delete ALL history for the IP (aka MAC address)
		if [ "$CMDIPFLUSH" == "IPFlush" ];then
			sqlite3 $SQL_DATABASE "DELETE from $SQL_TABLE WHERE $MAC_SQL) AND $URL_SQL)"
			RC=$?
		fi

		if [ $SEND_EMAIL -eq 1 ];then
			echo -e $cBYEL
			StatusLine $CMDNOANSII"Update" ${cYBLU}$aBOLD"Preparing e-mail....please wait!"
			sleep 1
			SendMail $MAILFILE
			StatusLine $CMDNOANSII"Clear"
			#echo -e $cBGRE"\n\tEmail sent..."$MAILFILE
		fi


		RESULT_CNT=$(nvram get tmp_WH_TOTAL);nvram unset tmp_WH_TOTAL	# Damn subshells VERY UGLY HACK :-(
		[ -z "$RESULT_CNT" ] && RESULT_CNT=0

	fi

	# Summarise
	[ $RESULT_CNT -eq 0 ] && IND=$cBRED || IND=$cBGRE

	if [ -z "$CMDNOANSII" ];then
		if [ -n "$CMDCOUNT" ] || [ $RESULT_CNT -le 20 ];then					# v1.09
			StatusLine $CMDNOANSII"NoFLASH" ${IND}$aREVERSE"Summary: Result count = "$RESULT_CNT" "
		else
			echo -e "\n"${cRESET}${cIND}$aREVERSE"Summary: Result count = "${RESULT_CNT}" "$aREVERSEr
		fi
	else
		echo -e "\n"${cRESET}${cIND}$aREVERSE"Summary: Result count = "${RESULT_CNT}" "$aREVERSEr
	fi

else
	echo -e $cBYEL
	if [ -z "$CMDCOUNT" ];then													# v1.10
		sqlite3 $SQL_DATABASE "SELECT datetime(timestamp, 'unixepoch', 'localtime') AS time, timestamp, mac, url FROM $SQL_TABLE $WHERE;"
	fi
	SQL_TOTAL=$(sqlite3 $SQL_DATABASE "SELECT datetime(timestamp, 'unixepoch', 'localtime') AS time, count(*) FROM $SQL_TABLE $WHERE;" | cut -d'|' -f2)
	echo -e $cBGRE"\nTotal Records = "$SQL_TOTAL
fi

# "dpi: TrendMicro function can't use under load-balance mode" 
# v1.10 Moved to after summary report
if [ $(nvram get bwdpi_wh_enable) -eq 0 ];then
	echo -e $cBRED"\a\n**Warning $SQL_DB_DESC logging NOT currently enabled"$cRESET
	#exit 97
fi

echo -e $cRESET

exit 0


