#no threads

source ../../.gdb2618
source ../../.gdb_mm

set remoteaddresssize 0d64
set remotetimeout 0d999999
target remote localhost:2000

disp/i $pc
x/i $pc

b RealMainP.nc:75
b RealMainP.nc:82
b SchedulerBasicP.nc:151
b SchedulerBasicP.nc:148

#b VirtualizeTimerC.nc:81
dis

# 5 debug_break  (optimized out)
# b PanicP.nc:62

# 5 panic
b PanicP.nc:78
comm
printf "pcode: 0d%d (0x%0x)  where: 0d%d  0x%04x 0x%04x 0x%04x 0x%04x\n",_p,_p, _w, _a0, _a1, _a2, _a3
end

dis
ena 5

b SDspP.nc:632
comm
p/d SDspP__last_pwr_on_first_cmd_uis
p/d SDspP__last_full_reset_time_uis
p/d SDspP__last_reset_time_uis
p/d SDspP__last_reset_time_mis
end

b sdP.nc:246

b SDspP.nc:1184
comm
p/d SDspP__last_pwr_on_first_cmd_uis
p/d sa_t3
p/d w_diff
p/d SDspP__sd_go_op_count
end
