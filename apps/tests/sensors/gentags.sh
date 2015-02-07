#!/bin/bash
#
# http://www.gnu.org/software/libtool/manual/emacs/Tags.html
#
# MSP430_TOOLCHAIN: where does the toolchain live.
# TOSROOT: top dir of the tinyos tree being used.
#

TC=${MSP430_TOOLCHAIN:-/opt/msp430-20110716}
TR=${TOSROOT:-$HOME/w/t2_cur/tinyos-2.x}

etags    ${TC}/msp430/include/msp430f5438.h 
etags -a ${TR}/tos/chips/msp430/pins/*.nc
etags -a ${TR}/tos/system/*.nc
etags -a ${TR}/tos/interfaces/*.nc
