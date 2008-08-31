#
# USE_SPI_PACKET
# ENABLE_SPI1_DMA
# TEST_GPS
# TEST_NO_COMM
# ENABLE_ERASE: compile in erase code for the SD, controlled by var do_erase
# ALWAYS_ERASE: force do_erase to 1 forcing erasing every boot.
# FAKE_SURFACE: pretend to surface and submerge every minute.
#
COMPONENT=mm3AppC
#PFLAGS += -DUSE_SPI_PACKET -DENABLE_SPI1_DMA
#PFLAGS += -DTEST_GPS -DTEST_NO_COMM
#PFLAGS += -DTEST_GPS -DENABLE_ERASE -DALWAYS_ERASE
#PFLAGS += -DTEST_GPS -DENABLE_ERASE
PFLAGS += -DTEST_GPS -DENABLE_ERASE -DFAKE_SURFACE -DTRACE

include $(MAKERULES)
