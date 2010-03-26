#
# USE_SPI_PACKET
# ENABLE_SPI0_DMA
# GPS_TEST
#   GPS_LEAVE_UP	don't turn power off to GPS
#   GPS_NO_SHORT	don't do quick fix (always stay up for long window)
#   GPS_SHORT_COUNT	if don't short how many over-determined fixes to see before saying got short
#   GPS_STAY_UP		don't turn gps off after good fix
#   GPS_FAST_POLL	enable fast poll (which sends data to the gps to elicit a 29 geodetic packet)
#   GPS_COMM_EMIT_2	generate gps_sat(2) (nav data) event message via comm link.
#   GPS_COMM_EMIT_7	generate gps_sat(7) (clock) event message via comm link.
#   GPS_COMM_EMIT_29	generate gps_sat(29) event message via comm link.
#
# GPS_LOG_EVENTS
#
# TEST_NO_COMM
# ENABLE_ERASE: compile in erase code for the SD, controlled by var do_erase
# ALWAYS_ERASE: force do_erase to 1 forcing erasing every boot.
# FAKE_SURFACE: pretend to surface and submerge every minute.
# CC2420_STACK: use actual CC2420 stack for radio (otherwise null stack)
# LOW_POWER_LISTENING
# ACK_LOW_POWER_LISTENING
# TOSTHREADS_TIMER_OPTIMIZATION makes normal thread and suspend longer (check out why).
#
# SERIAL_DEFAULT_OWNER: test code for trying out Serial owning the comm.
#

COMPONENT=mmAppC
PFLAGS += -DENABLE_ERASE -DFAKE_SURFACE 

PFLAGS += -DDEFAULT_EAVES=TRUE
#PFLAGS += -DTRACE_RESOURCE
#PFLAGS += -DTRACE_THREAD
#PFLAGS += -DSERIAL_DEFAULT_OWNER
#PFLAGS += -DCC2420_STACK
#PFLAGS += -DLOW_POWER_LISTENING -DACK_LOW_POWER_LISTENING

#PFLAGS += -DTEST_READER

PFLAGS += -DGPS_TEST
#PFLAGS += -DGPS_LEAVE_UP
#PFLAGS += -DGPS_STAY_UP 
#PFLAGS += -DGPS_NO_SHORT
#PFLAGS += -DGPS_COMM_EMIT_2 -DGPS_COMM_EMIT_7
PFLAGS += -DGPS_COMM_EMIT_29

#PFLAGS += -DTOSTHREADS_TIMER_OPTIMIZATION

#PFLAGS += -DTEST_NO_COMM

#PFLAGS += -DTOSH_DATA_LENGTH=512
#PFLAGS += -DALWAYS_ERASE
#PFLAGS += -DUSE_SPI_PACKET -DENABLE_SPI0_DMA

include $(MAKERULES)
