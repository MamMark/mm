# Copyright 2008, 2017 Eric B. Decker
# Mam-Mark Project
#
# mmdump: dump/process the data file from a mammark tag.
# can also handle a serial/network datastream.
#
# This makefile will build mmdump for the platform specified by
# MM_PLATFORM_DIR.  Shared platform files must be pointed to by
# MM_COMMON.
#

TARGET=mm4
MM_PLATFORM_DIR=$(MM_ROOT)/tos/platforms/$(TARGET)
MM_COMMON=$(MM_ROOT)/tos/platforms/mm
TYPED_DATA=$(MM_ROOT)/mm/include/typed_data.h
COMM=$(MM_ROOT)/tos/comm
SENSORS=$(MM_ROOT)/tos/chips/sensors

BUILD_NUM_FILE = $(MM_PLATFORM_DIR)/_Build
REF_BUILD_NUM := $(shell if [ -f $(BUILD_NUM_FILE) ]; then echo $$(($$(cat $(BUILD_NUM_FILE)))); else echo 0; fi)

STOW_DIR=/opt

PROGRAMS=mmdump

CC=gcc
CFLAGS += -g -O0 -Wall -I$(STOW_DIR)/include -I$(COMM) -I$(MM_PLATFORM_DIR) -DREF_BUILD=$(REF_BUILD_NUM)
LIBS += $(STOW_DIR)/lib/libmotenet.a

GEN = DtIgnoreMsg.h DtIgnoreMsg.c \
      DtConfigMsg.h DtConfigMsg.c \
      DtSyncMsg.h DtSyncMsg.c \
      DtRebootMsg.h DtRebootMsg.c \
      DtPanicMsg.h DtPanicMsg.c \
      DtGpsTimeMsg.h DtGpsTimeMsg.c \
      DtGpsPosMsg.h DtGpsPosMsg.c \
      DtSensorDataMsg.h DtSensorDataMsg.c \
      DtSensorSetMsg.h DtSensorSetMsg.c \
      DtTestMsg.h DtTestMsg.c \
      DtNoteMsg.h DtNoteMsg.c \
      DtVersionMsg.h DtVersionMsg.c \
      DtEventMsg.h DtEventMsg.c \
      DtGpsRawMsg.h DtGpsRawMsg.c \
      GpsNavDataMsg.h GpsNavDataMsg.c \
      GpsGeodeticDataMsg.h GpsGeodeticDataMsg.c \
      GpsNavLibDataMsg.h GpsNavLibDataMsg.c\
      GpsTrackerDataMsg.h GpsTrackerDataMsg.c \
      GpsSoftVersMsg.h GpsSoftVersMsg.c \
      GpsClockStatusMsg.h GpsClockStatusMsg.c \
      GpsErrorMsg.h GpsErrorMsg.c \
      GpsAlmanacStatusMsg.h GpsAlmanacStatusMsg.c\
      GpsPpsMsg.h GpsPpsMsg.c \
      GpsDevDataMsg.h GpsDevDataMsg.c \
      GpsUnkMsg.h GpsUnkMsg.c \
      gSensorIDs.h gDTConstants.h \
      serialpacket.c serialpacket.h serialprotocol.h

SERIAL_H = $(TOSDIR)/lib/serial/Serial.h

all: $(PROGRAMS)

#
# typed_data.h is run through mig to produce access routines
# for each of the network packets.  Mig generates a C file and
# associated header.  A pair is generated for each packet format
# because that is how mig does it.
#
# Convention: for the packet dt_ignore we generate the files
# DtIgnoreMsg.{c,h}
#

DtIgnoreMsg.c DtIgnoreMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_ignore -o DtIgnoreMsg.h

DtConfigMsg.c DtConfigMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_config -o DtConfigMsg.h

DtSyncMsg.c DtSyncMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_sync -o DtSyncMsg.h

DtRebootMsg.c DtRebootMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_reboot -o DtRebootMsg.h

DtPanicMsg.c DtPanicMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_panic -o DtPanicMsg.h

DtGpsTimeMsg.c DtGpsTimeMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_gps_time -o DtGpsTimeMsg.h

DtGpsPosMsg.c DtGpsPosMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_gps_pos -o DtGpsPosMsg.h

DtSensorDataMsg.c DtSensorDataMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_sensor_data -o DtSensorDataMsg.h

DtSensorSetMsg.c DtSensorSetMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_sensor_set -o DtSensorSetMsg.h

DtTestMsg.c DtTestMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_test -o DtTestMsg.h

DtNoteMsg.c DtNoteMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_note -o DtNoteMsg.h

DtGpsRawMsg.c DtGpsRawMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_gps_raw -o DtGpsRawMsg.h

GpsNavDataMsg.c GpsNavDataMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) gps_nav_data -o GpsNavDataMsg.h

GpsTrackerDataMsg.c GpsTrackerDataMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) gps_tracker_data -o GpsTrackerDataMsg.h

GpsNavLibDataMsg.c GpsNavLibDataMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
        c $(TYPED_DATA) gps_nav_lib_data -o GpsNavLibDataMsg.h

GpsGeodeticDataMsg.c GpsGeodeticDataMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) gps_geodetic -o GpsGeodeticDataMsg.h

GpsDevDataMsg.c GpsDevDataMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) gps_dev_data -o GpsDevDataMsg.h

GpsSoftVersMsg.c GpsSoftVersMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) gps_soft_version_data -o GpsSoftVersMsg.h

GpsClockStatusMsg.c GpsClockStatusMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) gps_clock_status_data -o GpsClockStatusMsg.h

GpsErrorMsg.c GpsErrorMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) gps_error_data -o GpsErrorMsg.h

GpsAlmanacStatusMsg.c GpsAlmanacStatusMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) gps_almanac_status_data -o GpsAlmanacStatusMsg.h

GpsPpsMsg.c GpsPpsMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) gps_pps_data -o GpsPpsMsg.h

GpsUnkMsg.c GpsUnkMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) gps_unk -o GpsUnkMsg.h

DtVersionMsg.c DtVersionMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_version -o DtVersionMsg.h

DtEventMsg.c DtEventMsg.h: $(TYPED_DATA)
	mig -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) dt_event -o DtEventMsg.h

gSensorIDs.h: $(SENSORS)/sensors.h
	ncg -o $@ -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -I$(SENSORS) \
	-target=$(TARGET) c $(SENSORS)/sensors.h \
	SNS_ID_NONE               \
	SNS_ID_CRADLE             \
	SNS_ID_BATT               \
	SNS_ID_TEMP               \
	SNS_ID_SAL                \
	SNS_ID_ACCEL              \
	SNS_ID_PTEMP              \
	SNS_ID_PRESS              \
	SNS_ID_SPEED              \
	SNS_ID_MAG                \
	MM_NUM_SENSORS

gDTConstants.h: $(TYPED_DATA) Makefile
	ncg -o $@ -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c $(TYPED_DATA) \
	DT_IGNORE                 \
	DT_CONFIG		  \
	DT_SYNC			  \
	DT_REBOOT		  \
	DT_PANIC		  \
	DT_GPS_TIME		  \
	DT_GPS_POS		  \
	DT_SENSOR_DATA		  \
	DT_SENSOR_SET		  \
	DT_TEST			  \
	DT_NOTE			  \
	DT_GPS_RAW		  \
	DT_VERSION		  \
	DT_EVENT		  \
	DT_DEBUG		  \
	DT_MAX			  \
				  \
	DT_EVENT_SURFACED	  \
	DT_EVENT_SUBMERGED	  \
	DT_EVENT_DOCKED		  \
	DT_EVENT_UNDOCKED	  \
	DT_EVENT_GPS_BOOT	  \
	DT_EVENT_GPS_RECONFIG	  \
	DT_EVENT_GPS_START	  \
	DT_EVENT_GPS_GRANT	  \
	DT_EVENT_GPS_RELEASE	  \
	DT_EVENT_GPS_OFF	  \
	DT_EVENT_GPS_FAST	  \
	DT_EVENT_GPS_FIRST	  \
	DT_EVENT_GPS_SATS_2	  \
	DT_EVENT_GPS_SATS_7	  \
	DT_EVENT_GPS_SATS_29	  \
	DT_EVENT_GPSCM_STATE	  \
				  \
	DT_HDR_SIZE_IGNORE        \
	DT_HDR_SIZE_CONFIG        \
	DT_HDR_SIZE_SYNC          \
	DT_HDR_SIZE_REBOOT        \
	DT_HDR_SIZE_PANIC         \
	DT_HDR_SIZE_GPS_TIME      \
	DT_HDR_SIZE_GPS_POS       \
	DT_HDR_SIZE_SENSOR_DATA   \
	DT_HDR_SIZE_SENSOR_SET    \
	DT_HDR_SIZE_TEST          \
	DT_HDR_SIZE_NOTE	  \
	DT_HDR_SIZE_GPS_RAW       \
	DT_HDR_SIZE_VERSION       \
	DT_HDR_SIZE_EVENT	  \
	DT_HDR_SIZE_DEBUG         \
	                          \
	CHIP_GPS_SIRF3            \
	CHIP_GPS_ORG4472          \
	CHIP_GPS_GSD4E            \
	                          \
	BATT_PAYLOAD_SIZE         \
	BATT_BLOCK_SIZE           \
	TEMP_PAYLOAD_SIZE         \
	TEMP_BLOCK_SIZE           \
	SAL_PAYLOAD_SIZE          \
	SAL_BLOCK_SIZE            \
	ACCEL_PAYLOAD_SIZE        \
	ACCEL_BLOCK_SIZE          \
	PTEMP_PAYLOAD_SIZE        \
	PTEMP_BLOCK_SIZE          \
	PRESS_PAYLOAD_SIZE        \
	PRESS_BLOCK_SIZE          \
	SPEED_PAYLOAD_SIZE        \
	SPEED_BLOCK_SIZE          \
	MAG_PAYLOAD_SIZE          \
	MAG_BLOCK_SIZE            \
	GPS_TIME_BLOCK_SIZE	  \
	GPS_POS_BLOCK_SIZE

serialpacket.c serialpacket.h: $(SERIAL_H)
	mig -o serialpacket.h -c-prefix=spacket c $(SERIAL_H) serial_packet

serialprotocol.h: $(SERIAL_H)
	ncg -o $@ -c-prefix=SERIAL c $(SERIAL_H) Serial.h

mmdump.o: mmdump.c $(BUILD_NUM_FILE)
	$(CC) -c $(CFLAGS) $<

.c.o:
	$(CC) -c $(CFLAGS) $<

mmdump: mmdump.o filesource.o ParseSirf.o serialpacket.o                       \
	    DtIgnoreMsg.o DtConfigMsg.o DtSyncMsg.o DtRebootMsg.o DtPanicMsg.o \
	    DtGpsTimeMsg.o DtGpsPosMsg.o DtSensorDataMsg.o                     \
	    DtSensorSetMsg.o DtTestMsg.o DtNoteMsg.o DtVersionMsg.o            \
	    DtEventMsg.o DtGpsRawMsg.o GpsNavDataMsg.o GpsGeodeticDataMsg.o    \
	    GpsNavLibDataMsg.o GpsTrackerDataMsg.o GpsSoftVersMsg.o            \
	    GpsClockStatusMsg.o GpsErrorMsg.o GpsAlmanacStatusMsg.o            \
	    GpsPpsMsg.o GpsDevDataMsg.o GpsUnkMsg.o
	$(CC) -o $@ $(LDFLAGS) $^ $(LIBS)

TAGS:
	rm -f TAGS
	etags *.c *.h

clean:
	rm -f *.o *~ \#*# tmp_make .#*

veryclean: clean
	rm -f TAGS $(PROGRAMS) $(GEN)

dep:
	sed '/\#\#\# Dependencies/q' <Makefile >tmp_make
	$(CPP) $(CFLAGS) -MM *.c >>tmp_make
	mv tmp_make Makefile

### Dependencies
DtConfigMsg.o: DtConfigMsg.c /opt/include/message.h DtConfigMsg.h
DtEventMsg.o: DtEventMsg.c /opt/include/message.h DtEventMsg.h
DtGpsPosMsg.o: DtGpsPosMsg.c /opt/include/message.h DtGpsPosMsg.h
DtGpsRawMsg.o: DtGpsRawMsg.c /opt/include/message.h DtGpsRawMsg.h
DtGpsTimeMsg.o: DtGpsTimeMsg.c /opt/include/message.h DtGpsTimeMsg.h
DtIgnoreMsg.o: DtIgnoreMsg.c /opt/include/message.h DtIgnoreMsg.h
DtNoteMsg.o: DtNoteMsg.c /opt/include/message.h DtNoteMsg.h
DtPanicMsg.o: DtPanicMsg.c /opt/include/message.h DtPanicMsg.h
DtRebootMsg.o: DtRebootMsg.c /opt/include/message.h DtRebootMsg.h
DtSensorDataMsg.o: DtSensorDataMsg.c /opt/include/message.h \
 DtSensorDataMsg.h
DtSensorSetMsg.o: DtSensorSetMsg.c /opt/include/message.h \
 DtSensorSetMsg.h
DtSyncMsg.o: DtSyncMsg.c /opt/include/message.h DtSyncMsg.h
DtTestMsg.o: DtTestMsg.c /opt/include/message.h DtTestMsg.h
DtVersionMsg.o: DtVersionMsg.c /opt/include/message.h DtVersionMsg.h
filesource.o: filesource.c /opt/include/message.h \
 ../../../tos/comm/am_types.h filesource.h serialprotocol.h \
 serialpacket.h DtSensorDataMsg.h DtSyncMsg.h gDTConstants.h gSensorIDs.h \
 sync.h
GpsAlmanacStatusMsg.o: GpsAlmanacStatusMsg.c /opt/include/message.h \
 GpsAlmanacStatusMsg.h
GpsClockStatusMsg.o: GpsClockStatusMsg.c /opt/include/message.h \
 GpsClockStatusMsg.h
GpsDevDataMsg.o: GpsDevDataMsg.c /opt/include/message.h GpsDevDataMsg.h
GpsErrorMsg.o: GpsErrorMsg.c /opt/include/message.h GpsErrorMsg.h
GpsGeodeticDataMsg.o: GpsGeodeticDataMsg.c /opt/include/message.h \
 GpsGeodeticDataMsg.h
GpsNavDataMsg.o: GpsNavDataMsg.c /opt/include/message.h GpsNavDataMsg.h
GpsNavLibDataMsg.o: GpsNavLibDataMsg.c /opt/include/message.h \
 GpsNavLibDataMsg.h
GpsPpsMsg.o: GpsPpsMsg.c /opt/include/message.h GpsPpsMsg.h
GpsSoftVersMsg.o: GpsSoftVersMsg.c /opt/include/message.h \
 GpsSoftVersMsg.h
GpsTrackerDataMsg.o: GpsTrackerDataMsg.c /opt/include/message.h \
 GpsTrackerDataMsg.h
GpsUnkMsg.o: GpsUnkMsg.c /opt/include/message.h GpsUnkMsg.h
mmdump.o: mmdump.c /opt/include/serialsource.h /opt/include/sfsource.h \
 /opt/include/message.h ../../../tos/comm/am_types.h sync.h \
 filesource.h serialpacket.h serialprotocol.h \
 ../../../tos/platforms/mm4/platform_version.h gSensorIDs.h \
 gDTConstants.h DtIgnoreMsg.h DtSyncMsg.h DtRebootMsg.h DtPanicMsg.h \
 DtSensorDataMsg.h DtVersionMsg.h DtEventMsg.h DtGpsTimeMsg.h \
 DtGpsPosMsg.h DtGpsRawMsg.h ParseSirf.h
ParseSirf.o: ParseSirf.c /opt/include/serialsource.h \
 /opt/include/sfsource.h /opt/include/message.h filesource.h \
 serialpacket.h serialprotocol.h gDTConstants.h ParseSirf.h \
 GpsNavDataMsg.h GpsTrackerDataMsg.h GpsGeodeticDataMsg.h GpsDevDataMsg.h \
 GpsSoftVersMsg.h GpsClockStatusMsg.h GpsPpsMsg.h GpsAlmanacStatusMsg.h \
 DtGpsRawMsg.h GpsErrorMsg.h GpsUnkMsg.h GpsNavLibDataMsg.h
serialpacket.o: serialpacket.c /opt/include/message.h serialpacket.h
