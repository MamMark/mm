#!/usr/bin/env bash

if [[ ! -v MM_ROOT ]]; then
    echo need MM_ROOT defined
    exit 1
fi
cp ${MM_ROOT}/tos/mm/gdbinit                    .gdbinit
cp ${MM_ROOT}/tos/mm/gdb_msp432                 .gdb_msp432
cp ${MM_ROOT}/tos/mm/gdb_mm                     .gdb_mm
cp ${MM_ROOT}/tos/platforms/mm6a/gdb_mm6a       .gdb_mm6a
cp ${MM_ROOT}/tos/platforms/dev6a/gdb_dev6a     .gdb_dev6a
cp ${MM_ROOT}/tos/chips/gsd4e_v4/gdb_gps        .gdb_gps
#cp ${MM_ROOT}/tos/chips/si446x/gdb_radio       .gdb_radio
