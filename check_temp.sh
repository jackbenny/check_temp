#!/bin/bash

################################################################################
#                                                                              #
#  Copyright (C) 2011 Jack-Benny Persson <jake@cyberinfo.se>                   #
#                                                                              #
#   This program is free software; you can redistribute it and/or modify       #
#   it under the terms of the GNU General Public License as published by       #
#   the Free Software Foundation; either version 2 of the License, or          #
#   (at your option) any later version.                                        #
#                                                                              #
#   This program is distributed in the hope that it will be useful,            #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of             #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              #
#   GNU General Public License for more details.                               #
#                                                                              #
#   You should have received a copy of the GNU General Public License          #
#   along with this program; if not, write to the Free Software                #
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA  #
#                                                                              #
################################################################################

###############################################################################
#                                                                             #	
# Nagios plugin to monitor CPU and M/B temperature with sensors.              #
# Written in Bash (and uses sed & awk).                                       #
# Latest version of check_temp can be found at the below URL:                 #
# https://github.com/jackbenny/check_temp                                     #
#                                                                             #
# If you are having problems getting it to work, check the instructions in    #
# the README first. It walks you though install lm-sensors and getting it to  #
# display sensor data.                                                        #
#                                                                             #
###############################################################################

VERSION="Version 1.0"
AUTHOR="(c) 2011 Jack-Benny Persson (jack-benny@cyberinfo.se)"

# Sensor program
SENSORPROG=$(whereis -b -B /{bin,sbin,usr} /{bin,sbin,usr}/* -f sensors | awk '{print $2}')

# Ryan's note: utils.sh is installed with nagios-plugins in with the plugins
# Check if utils.sh exists. This lets you use check_domain in a testing environment
# or outside of Nagios.
if [ -e "$PROGPATH/utils.sh" ]; then
	. "$PROGPATH/utils.sh"
else
	STATE_OK=0
	STATE_WARNING=1
	STATE_CRITICAL=2
	STATE_UNKNOWN=3
#	STATE_DEPENDENT=4    (Commented because it's unused.)
fi

shopt -s extglob

#### Functions ####

# Print version information
print_version()
{
	echo "$0 - $VERSION"
}

#Print help information
print_help()
{
	print_version
	echo "$AUTHOR"
	echo "Monitor temperature with the use of sensors"
/bin/cat <<EOT

Options:
-h, --help
   Print detailed help screen
-V, --version
   Print version information
-v, --verbose
   Verbose output

-s, --sensor <WORD[,DISPLAY_NAME]>
   Set what to monitor, for example CPU or MB (or M/B). Check sensors for the
   correct word. Default is CPU. A different display name can be used in output,
   by adding it next to sensor with a comma.
   It can be used more than once, with different warning/critical thresholds optionally.
-w, --warning <INTEGER>
   Exit with WARNING status if above INTEGER degrees
-c, --critical <INTEGER>
   Exit with CRITICAL status if above INTEGER degrees
   Warning and critical thresholds must be provided before the corresponding --sensor option.

Examples:
./check_temp.sh -w 65 -c 75 --sensor CPU
./check_temp.sh -w 65 -c 75 --sensor CPU --sensor temp1
./check_temp.sh -w 65 -c 75 --sensor CPU -w 75 -c 85 --sensor temp1,GPU
EOT
}


###### MAIN ########

# Warning threshold
thresh_warn=
# Critical threshold
thresh_crit=
# Hardware to monitor
default_sensor="CPU"
sensor_declared=false

STATE=$STATE_OK

# See if we have sensors program installed and can execute it
if [[ ! -x "$SENSORPROG" ]]; then
	echo "It appears you don't have lm-sensors installed. You may find help in the readme for this script."
	exit $STATE_UNKNOWN
fi

function set_state {
	[[ "$STATE" -lt "$1" ]] && STATE=$1 
}

function process_sensor {
	sensor=$(echo $1 | cut -d, -f1)
	sensor_display=$(echo $1 | cut -d, -f2)
	# Check if a sensor were specified
	if [[ -z "$sensor" ]]; then
		# No sensor to monitor were specified
		echo "No sensor specified"
		print_help
		exit $STATE_UNKNOWN
	fi

	# Check if the thresholds have been set correctly
	if [[ -z "$thresh_warn" || -z "$thresh_crit" ]]; then
		# One or both thresholds were not specified
		echo "Threshold not set"
		print_help
		exit $STATE_UNKNOWN
	  elif [[ "$thresh_crit" -lt "$thresh_warn" ]]; then
		# The warning threshold must be lower than the critical threshold
		echo "Warning temperature should be lower than critical"
		print_help
		exit $STATE_UNKNOWN
	fi
	# Get the temperature
	# Grep the first float with a plus sign and keep only the integer
	WHOLE_TEMP=$(${SENSORPROG} | grep "$sensor" | head -n1 | grep -o "+[0-9]\+\(\.[0-9]\+\)\?[^ \t,()]*" | head -n1)
	TEMPF=$(echo "$WHOLE_TEMP" | grep -o "[0-9]\+\(\.[0-9]\+\)\?")
	TEMP=$(echo "$TEMPF" | cut -d. -f1)

	# Verbose output
	if [[ "$verbosity" -ge 1 ]]; then
	   /bin/cat <<__EOT
	Debugging information:
	  Warning threshold: $thresh_warn 
	  Critical threshold: $thresh_crit
	  Verbosity level: $verbosity
	  Current $sensor temperature: $TEMP
__EOT
	echo "Temperature lines directly from sensors:"
	${SENSORPROG}
	fi
	
	# Get performance data for Nagios "Performance Data" field
	PERFDATA="$PERFDATA $sensor_display=$TEMP;$thresh_warn;$thresh_crit"

	# And finally check the temperature against our thresholds
	if [[ "$TEMP" != +([0-9]) ]]; then
		# Temperature not found for that sensor
		OUTPUT_TEXT="$OUTPUT_TEXT, No data found for sensor ($sensor)"
		set_state $STATE_UNKNOWN
	elif [[ "$TEMP" -gt "$thresh_crit" ]]; then
		# Temperature is above critical threshold
		OUTPUT_TEXT="$OUTPUT_TEXT, $sensor_display has temperature: $WHOLE_TEMP"
		set_state $STATE_CRITICAL
	elif [[ "$TEMP" -gt "$thresh_warn" ]]; then
		# Temperature is above warning threshold
		OUTPUT_TEXT="$OUTPUT_TEXT, $sensor_display has temperature: $WHOLE_TEMP"
		set_state $STATE_WARNING
	else
		# Temperature is ok
		OUTPUT_TEXT="$OUTPUT_TEXT, $sensor_display has temperature: $WHOLE_TEMP"
		set_state $STATE_OK
	fi
}

# Parse command line options
while [[ -n "$1" ]]; do 
   case "$1" in

       -h | --help)
           print_help
           exit $STATE_OK
           ;;

       -V | --version)
           print_version
           exit $STATE_OK
           ;;

       -v | --verbose)
           : $(( verbosity++ ))
           shift
           ;;

       -w | --warning)
           if [[ -z "$2" ]]; then
               # Threshold not provided
               echo "Option $1 requires an argument"
               print_help
               exit $STATE_UNKNOWN
            elif [[ "$2" = +([0-9]) ]]; then
               # Threshold is an integer 
               thresh=$2
            else
               # Threshold is not an integer
               echo "Threshold must be an integer"
               print_help
               exit $STATE_UNKNOWN
           fi
           thresh_warn=$thresh
	   shift 2
           ;;

       -c | --critical)
           if [[ -z "$2" ]]; then
               # Threshold not provided
               echo "Option '$1' requires an argument"
               print_help
               exit $STATE_UNKNOWN
            elif [[ "$2" = +([0-9]) ]]; then
               # Threshold is an integer 
               thresh=$2
            else
               # Threshold is not an integer
               echo "Threshold must be an integer"
               print_help
               exit $STATE_UNKNOWN
           fi
           thresh_crit=$thresh
	   shift 2
           ;;

       -s | --sensor)
	   if [[ -z "$2" ]]; then
		echo "Option $1 requires an argument"
		print_help
		exit $STATE_UNKNOWN
	   fi
	   sensor_declared=true
	   process_sensor "$2"
           shift 2
           ;;

       *)
           echo "Invalid option '$1'"
           print_help
           exit $STATE_UNKNOWN
           ;;
   esac
done

if [ "$sensor_declared" = false ]; then
	process_sensor "$default_sensor"
fi

case "$STATE" in
	"$STATE_OK") STATE_TEXT="OK" ;;
	"$STATE_WARNING") STATE_TEXT="WARNING" ;;
	"$STATE_CRITICAL") STATE_TEXT="CRITICAL" ;;
	"$STATE_UNKNOWN") STATE_TEXT="UNKNOWN" ;;
esac

OUTPUT_TEXT=$(echo $OUTPUT_TEXT | sed -e 's/, //')
echo "TEMPERATURE $STATE_TEXT - $OUTPUT_TEXT |$PERFDATA"
exit $STATE
