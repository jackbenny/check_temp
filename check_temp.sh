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

VERSION="Version 0.8"
AUTHOR="(c) 2011 Jack-Benny Persson (jack-benny@cyberinfo.se)"

# Sensor program
SENSORPROG=/usr/bin/sensors

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

shopt -s extglob

#### Functions ####

# Print version information
print_version()
{
	printf "\n\n$0 - $VERSION\n"
}

#Print help information
print_help()
{
	print_version
	printf "$AUTHOR\n"
	printf "Monitor temperature with the use of sensors\n"
/bin/cat <<EOT

Options:
-h
   Print detailed help screen
-V
   Print version information
-v
   Verbose output

--sensor WORD
   Set what to monitor, for example CPU or MB (or M/B). Check sensors for the
   correct word. Default is CPU.
-w INTEGER
   Exit with WARNING status if above INTEGER degres
-c INTEGER
   Exit with CRITICAL status if above INTEGER degres
EOT
}


###### MAIN ########

# Warning threshold
thresh_warn=
# Critical threshold
thresh_crit=
# Hardware to monitor
sensor=CPU

# See if we have sensors program installed and can execute it
if [[ ! -x "$SENSORPROG" ]]; then
	printf "\nIt appears you don't have sensors installed in $SENSORPROG\n"
	exit $STATE_UNKOWN
fi

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
               printf "\nOption $1 requires an argument"
               print_help
               exit $STATE_UNKNOWN
            elif [[ "$2" = +([0-9]) ]]; then
               # Threshold is an integer 
               thresh=$2
            else
               # Threshold is not an integer
               printf "\nThreshold must be an integer"
               print_help
               exit $STATE_UNKNOWN
           fi
           thresh_warn=$thresh
	   shift 2
           ;;

       -c | --critical)
           if [[ -z "$2" ]]; then
               # Threshold not provided
               printf "\nOption '$1' requires an argument"
               print_help
               exit $STATE_UNKNOWN
            elif [[ "$2" = +([0-9]) ]]; then
               # Threshold is an integer 
               thresh=$2
            else
               # Threshold is not an integer
               printf "\nThreshold must be an integer"
               print_help
               exit $STATE_UNKNOWN
           fi
           thresh_crit=$thresh
	   shift 2
           ;;

       -\?)
           print_help
           exit $STATE_OK
           ;;

       --sensor)
	   if [[ -z "$2" ]]; then
		printf "\nOption $1 requires an argument"
		print_help
		exit $STATE_UNKNOWN
	   fi
		sensor=$2
           shift 2
           ;;

       *)
           printf "\nInvalid option '$1'"
           print_help
           exit $STATE_UNKNOWN
           ;;
   esac
done


# Check if a sensor were specified
if [[ -z "$sensor" ]]; then
	# No sensor to monitor were specified
	printf "\nNo sensor specified"
	print_help
	exit $STATE_UNKNOWN
fi


#Get the temperature
TEMP=`${SENSORPROG} | grep "$sensor" | cut -d+ -f2 | cut -c1-2 | head -n1`
#Old way - Get the temperature
#TEMP=`${SENSORPROG} | grep "$sensor" | awk '{print $3}' | cut -c2-3 | head -n1`


# Check if the thresholds have been set correctly
if [[ -z "$thresh_warn" || -z "$thresh_crit" ]]; then
	# One or both thresholds were not specified
	printf "\nThreshold not set"
	print_help
	exit $STATE_UNKNOWN
  elif [[ "$thresh_crit" -lt "$thresh_warn" ]]; then
	# The warning threshold must be lower than the critical threshold
	printf "\nWarning temperature should be lower than critical"
	print_help
	exit $STATE_UNKNOWN
fi


# Verbose output
if [[ "$verbosity" -ge 1 ]]; then
   /bin/cat <<__EOT
Debugging information:
  Warning threshold: $thresh_warn 
  Critical threshold: $thresh_crit
  Verbosity level: $verbosity
  Current $sensor temperature: $TEMP
__EOT
printf "\n  Temperature lines directly from sensors:\n"
${SENSORPROG}
printf "\n\n"
fi

# Get performance data for Nagios "Performance Data" field
PERFDATA=`${SENSORPROG} | grep "$sensor" | head -n1`


# And finally check the temperature against our thresholds
if [[ "$TEMP" != +([0-9]) ]]; then
	# Temperature not found for that sensor
	printf "No data found for that sensor ($sensor)\n"
	exit $STATE_UNKNOWN
	
  elif [[ "$TEMP" -gt "$thresh_crit" ]]; then
	# Temperature is above critical threshold
	echo "$sensor CRITICAL - Temperature is $TEMP | $PERFDATA"
	exit $STATE_CRITICAL

  elif [[ "$TEMP" -gt "$thresh_warn" ]]; then
	# Temperature is above warning threshold
	echo "$sensor WARNING - Temperature is $TEMP | $PERFDATA"
	exit $STATE_WARNING

  else
	# Temperature is ok
	echo "$sensor OK - Temperature is $TEMP | $PERFDATA"
	exit $STATE_OK
fi
exit 3
