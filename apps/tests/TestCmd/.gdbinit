
source ../../.gdb2618
# source ../../.gdb_mm

set remoteaddresssize 0d64
set remotetimeout 0d999999
target remote localhost:2000

disp/i $pc
x/i $pc
set pri ele 0

#b RealMainP.nc:86
#b RealMainP.nc:91
b SchedulerBasicP.nc:159
b SchedulerBasicP.nc:162
dis

#b SerialP.nc:443
#comm
#p SerialP__rxState
#p data
#end

#b SerialP.nc:483
#b SerialDispatcherP.nc:258
#dis 5-6

#b CmdHandlerP.nc:99
#b CmdHandlerP.nc:112
#b CmdHandlerP.nc:122

#b SerialP.nc:460
#b SerialP.nc:489
#b SerialP.nc:515

define nx
fini
ni 3
si 2
end

define noint
printf "cur sr: %02x\n", $r2
set $r2=0
end


define sdp
printf "SDP rx_state: "
print SerialDispatcherP__0__rx_state
printf "SDP rx_index: %d,  rx_buffer: %04x\n", SerialDispatcherP__0__rx_index, SerialDispatcherP__0__rx_buffer
printf "P_rx_slot: %d,  C_rx_slot: %d\n", SerialDispatcherP__0__P_rx_slot, SerialDispatcherP__0__C_rx_slot
print SerialDispatcherP__0__rx_slots[0]
print SerialDispatcherP__0__rx_slots[1]
end
document sdp
display SerialDispatcherP state informtion
end
