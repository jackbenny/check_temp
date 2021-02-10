#!/bin/bash
. common.inc

export TESTDATA=$(sample_from_scriptname $0)

result=$(../check_temp.sh -w 65 -c 75)

matcher1=$(has_temperature "$result" '+44.1°C')
matcher2=$(has_stats "$result" 'CPU=44;65;75')

exit $(( matcher1 + matcher2 ))

