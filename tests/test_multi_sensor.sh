#!/bin/bash
. common.inc

export TESTDATA=$(sample_from_scriptname $0)

result=$(../check_temp.sh -w 65 -c 75 --sensor first -w 60 -c 70 --sensor second)

matcher1=$(has_temperature "$result" '+34.1°C,' '+45.1°C')
matcher2=$(has_stats "$result" 'first=34;65;75 second=45;60;70')

exit $(( matcher1 + matcher2 ))

