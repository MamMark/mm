
disp/i $pc
x/i $pc

b TinyOSMainP.nc:83
b TinyOSMainP.nc:90
b SchedulerBasicP.nc:134
b SchedulerBasicP.nc:137
b TinyThreadSchedulerP.nc:78
b TinyThreadSchedulerP.nc:115
b VirtualizeTimerC.nc:81
#dis

#b PanicP.nc:42
#comm
#printf "pcode: %d  where: %d  %04x %04x %04x %04x\n",_p, _w, _a0, _a1, _a2, _a3
#end

#b SerialCollectP.nc:60
#b CollectP.nc:45
#comm
#printf "collect: len: %d (0x%02x), type: %d  id: %d\n",dlen,dlen,data[2],data[3]
#end

# b sig_TIMERA0_VECTOR
# b sig_TIMERA1_VECTOR
# b sig_TIMERB0_VECTOR
# b sig_TIMERB1_VECTOR

# b AdcP.nc:219
# comm
# printf "PUD: owner: %d  req: %d  adc_state: %02x\n", AdcP$adc_owner, AdcP$req_client, AdcP$adc_state
# end
# b AdcP.nc:372
# comm
# printf "PowerAlarm: owner: %d\n", AdcP$adc_owner
# end
# b AdcP.nc:412
# comm
# printf "reqConf: id: %d\n",client_id
# end
# b AdcP.nc:453
# comm
# printf "reconfig: %d\n",AdcP$adc_owner
# end
# b AdcP.nc:492
# comm
# printf "release: %d %d\n",AdcP$adc_owner,client_id
# end
