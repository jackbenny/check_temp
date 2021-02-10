#!/bin/bash
. common.inc

export TESTDATA=$(sample_from_scriptname $0)

result=$(../check_temp.sh -w 65 -c 75 --sensor CPU,Emily)

matcher2=$(has_stats "$result" 'Emily=44;65;75')

exit $(( matcher1 + matcher2 ))

