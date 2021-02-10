whereis() {
	echo lala sensors
}

export -f whereis

sensors() {
	if [ $# -eq 2 ]; then
		switch=$1
		sensor=$2
		if [ ! -z "$TESTDATA" ]; then
			>&2 echo WARNING: TESTDATA is set while check_temp uses -n
			>&2 echo WARNING: Therefore ./data/sample_$sensor is loaded instead
			>&2 echo WARNING: of $TESTDATA
		fi
		cat ${TESTDATA_PREFIX}-$sensor | grep -v -e '^#'
	else
		cat $TESTDATA | grep -v -e '^#'
	fi
}

export -f sensors

sample_from_scriptname() {
	scriptName=$(basename $1)
	stage1=${scriptName%.sh}
	echo ./data/${stage1/test/sample}
}

# Matches one or more temperatures, only the last is without
# a comma. All others must have a comma at their end
#
has_temperature() {
	output="$1"

	expectedTemp="$2"

	tempFound=0
	for token in $output; do
		if [ "$token" = 'temperature:' ]; then
			tempFound=1
		elif [ $tempFound -eq 1 ]; then
			if [ "$token" = "$expectedTemp" ]; then
				if [ $# -eq 2 ]; then
					echo 0
					return
				else
					shift
					expectedTemp="$2"
				fi
			else
				>&2 echo -e "Expected temperature $expectedTemp not in output:\n$output"
				echo 1
				return
			fi
			tempFound=0

		fi
	done

	echo 1
}

# matches the stats as a block, thus order is implicit
#
has_stats() {
	output="$1"
	expectedStats="$2"

	stats=${output#*| }

	if [ "$stats" = "$expectedStats" ]; then
		echo 0
	else
		>&2 echo -e "Expected statistcs $expectedStats not in output:\n$output"
		echo 1
	fi
}
