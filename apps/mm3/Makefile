#
# USE_SPI_PACKET
# ENABLE_SPI1_DMA
# TEST_GPS
# TEST_NO_COMM
# ENABLE_ERASE: compile in erase code for the SD, controlled by var do_erase
# ALWAYS_ERASE: force do_erase to 1 forcing erasing every boot.
# FAKE_SURFACE: pretend to surface and submerge every minute.
# CC2420_STACK: use actual CC2420 stack for radio (otherwise null stack)
#

COMPONENT=mm3AppC
PFLAGS += -DENABLE_ERASE -DFAKE_SURFACE -DTRACE
PFLAGS += -DTEST_READER
#PFLAGS += -DTEST_GPS

#PFLAGS += -DTEST_NO_COMM

#PFLAGS += -DTOSH_DATA_LENGTH=512
#PFLAGS += -DCC2420_STACK
#PFLAGS += -DALWAYS_ERASE
#PFLAGS += -DUSE_SPI_PACKET -DENABLE_SPI1_DMA

include $(MAKERULES)
