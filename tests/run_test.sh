#!/bin/bash
export esc="\e"
export COLOR_RST="$esc[0m"
export COLOR_RED="$esc[31m"
export COLOR_GRN="$esc[32m"
export COLOR_YLW="$esc[33m"
export COLOR_LGREEN="$esc[1;32m" 

PATTERN='%-25s %-45s %s'
totalTests=0
testsFailed=0
testsSucceeded=0

for testCase in $(ls ./test_*.sh); do
	(( totalTests++ ))
	echo "*** Start testcase $testCase"
	$testCase
	errCode=$?
	
	if [ $errCode -ne 0 ]; then
		(( testsFailed++ ))
		status="${COLOR_RED}failed${COLOR_RST}"
	else
		(( testsSucceeded++ ))
		status="${COLOR_LGREEN}success${COLOR_RST}"
	fi

	printf -v msg "$PATTERN" $testCase "->" $status

	echo -e "$msg"
	echo -e "----------------------------------------\n"
done

echo Of $totalTests tests $testsFailed failed and $testsSucceeded succeeded
