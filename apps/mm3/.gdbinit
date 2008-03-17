
disp/i $pc
x/i $pc

b RealMainP.nc:75
b RealMainP.nc:82
b SchedulerBasicP.nc:151
b SchedulerBasicP.nc:148
b VirtualizeTimerC.nc:81
dis

b AdcP.nc:107
comm
printf "pcode: %d  where: %d  %04x %04x %04x %04x\n",\
    pcode, where, arg0, arg1, arg2, arg3
end

# b sig_TIMERA0_VECTOR
# b sig_TIMERA1_VECTOR
# b sig_TIMERB0_VECTOR
# b sig_TIMERB1_VECTOR

#set remoteaddresssize 0d64
#set remotetimeout 0d999999
#target remote localhost:2000
