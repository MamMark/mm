
source ../../.gdb_x2
source ../../.gdb_mm

set remoteaddresssize 0d64
set remotetimeout 0d999999
target remote localhost:2000

disp/i $pc
x/i $pc
set pri ele 0

define inst
p/d SDspP__last_reset_time_us
p/d SDspP__last_reset_time_ms
p/d SDspP__last_read_time_us
p/d SDspP__last_read_time_ms
p/d SDspP__last_write_time_us
p/d SDspP__last_write_time_ms
end

# b RealMainP.nc:85   (PlatformInit)
# b RealMainP.nc:93   (SoftwareInit)
# b RealMainP.nc:100   (booted)
#b RealMainP.nc:85
#b RealMainP.nc:93
#b RealMainP.nc:100

#b SchedulerBasicP.nc:159
b SchedulerBasicP.nc:162
#b VirtualizeTimerC.nc:92
dis


# 6 panic   debug_break
b PanicP.nc:85
comm
printf "pcode: 0d%d (0x%0x)  where: 0d%d  0x%04x 0x%04x 0x%04x 0x%04x\n",_p,_p, _w, _a0, _a1, _a2, _a3
end

# 7
b FileSystemP.nc:276
comm
p FileSystemP__fsc
end

b mmSyncP.nc:99

define nx
fini
ni 3
si 2
end

define noint
printf "cur sr: %02x\n", $r2
set $r2=0
end

define npc
x/16i $pc
end
document npc
display next (16) instructions from $pc
end

define gg
set wait=0
c
end
document gg
go, set wait to 0 and continue
end
