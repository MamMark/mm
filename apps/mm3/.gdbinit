set remoteaddresssize 0d64
set remotetimeout 0d999999
target remote localhost:2000

define dt
printf "TA:\n"
x/16hx 0x160
printf "\nTB:\n"
x/16hx 0x180
end

define dc
printf "dcoctl:  %02x\n",(*(uint8_t *)0x56)
printf "bcsctl1: %02x\n",(*(uint8_t *)0x57)
printf "bcsctl2: %02x\n",(*(uint8_t *)0x58)
end

define sa
printf "resQ:  %02x%02x\n", RoundRobinResourceQueueC$0$resQ[1], RoundRobinResourceQueueC$0$resQ[0]
printf "adc: state: %02x, req: %02x, owner: %02x\n", AdcP$adc_state, AdcP$req_client, AdcP$adc_owner
end

disp/i $pc
x/i $pc

b RealMainP.nc:75
b RealMainP.nc:82
b SchedulerBasicP.nc:151
b SchedulerBasicP.nc:148
b VirtualizeTimerC.nc:81

# b sig_TIMERA0_VECTOR
# b sig_TIMERA1_VECTOR
# b sig_TIMERB0_VECTOR
# b sig_TIMERB1_VECTOR
