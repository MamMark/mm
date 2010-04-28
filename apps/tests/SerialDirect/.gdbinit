
#no threads.

source ../../.gdb2618

set remoteaddresssize 0d64
set remotetimeout 0d999999
target remote localhost:2000

disp/i $pc
x/i $pc
set pri ele 0

# 1
b RealMainP.nc:82

# 2
b RealMainP.nc:85

# 3 task scheduler
b SchedulerBasicP.nc:151

# 4 thread dispatch
#b TinyThreadSchedulerP.nc:89

#dis


define tq
printf "taskq: head: %d  tail %d\n", (uint8_t) SchedulerBasicP__m_head, (uint8_t) SchedulerBasicP__m_tail
x/25bu SchedulerBasicP__m_next
end
document tq
display task queue
end


define nx
fini
ni 3
si 2
end


define noint
printf "cur sr: %02x\n", $r2
set $r2=0
end
