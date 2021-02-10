#!/bin/bash
. common.inc

export TESTDATA_PREFIX=$(sample_from_scriptname $0)

echo $TESTDATA

# -n enables filtering by device through sensors command
#
result=$(../check_temp.sh -n -w 65 -c 75 --sensor k10temp-pci-00c3,CPU -w 60 -c 80 --sensor radeon-pci-0008,GPU)

matcher1=$(has_temperature "$result" '+45.2°C,' '+40.7°C')
matcher2=$(has_stats "$result" 'CPU=45;65;75 GPU=40;60;80')

exit $(( matcher1 + matcher2 ))

