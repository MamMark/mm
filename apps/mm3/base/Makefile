# Copyright 2008, Eric B. Decker
# Mam-Mark Project

STOW_DIR=/opt

PROGRAMS= mm3dump

CC=gcc
CFLAGS += -g -O0 -Wall -I$(STOW_DIR)/include -I../../../support/utils/include
LIBS += $(STOW_DIR)/lib/libmote.a

GEN=mm3DataMsg.h mm3DataMsg.c \
    DtIgnoreMsg.h DtIgnoreMsg.c \
    DtConfigMsg.h DtConfigMsg.c \
    DtSyncMsg.h DtSyncMsg.c \
    DtPanicMsg.h DtPanicMsg.c \
    DtGpsTimeMsg.h DtGpsTimeMsg.c \
    DtGpsPosMsg.h DtGpsPosMsg.c \
    DtSensorDataMsg.h DtSensorDataMsg.c \
    DtSensorSetMsg.h DtSensorSetMsg.c \
    DtTestMsg.h DtTestMsg.c \
    DtNoteMsg.h DtNoteMsg.c \
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
    DtVersionMsg.h DtVersionMsg.c \
    DtEventMsg.h DtEventMsg.c \
    SDConstants.h SensorConstants.h \
    serialpacket.c serialpacket.h serialprotocol.h

SERIAL_H = $(TOSDIR)/lib/serial/Serial.h
MM3_PLATFORM_DIR=$(MAMMARK_DIR)/tos/platforms/mm3

all: $(PROGRAMS)

mm3DataMsg.h: $(MM3_PLATFORM_DIR)/misc/mm3_data_msg.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/mm3_data_msg.h mm3_data_msg -o mm3DataMsg.h

DtIgnoreMsg.c DtIgnoreMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h dt_ignore -o DtIgnoreMsg.h

DtConfigMsg.c DtConfigMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h dt_config -o DtConfigMsg.h

DtSyncMsg.c DtSyncMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h dt_sync -o DtSyncMsg.h

DtPanicMsg.c DtPanicMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h dt_panic -o DtPanicMsg.h

DtGpsTimeMsg.c DtGpsTimeMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h dt_gps_time -o DtGpsTimeMsg.h

DtGpsPosMsg.c DtGpsPosMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h dt_gps_pos -o DtGpsPosMsg.h

DtSensorDataMsg.c DtSensorDataMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h dt_sensor_data -o DtSensorDataMsg.h

DtSensorSetMsg.c DtSensorSetMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h dt_sensor_set -o DtSensorSetMsg.h

DtTestMsg.c DtTestMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h dt_test -o DtTestMsg.h

DtNoteMsg.c DtNoteMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h dt_note -o DtNoteMsg.h

DtGpsRawMsg.c DtGpsRawMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h dt_gps_raw -o DtGpsRawMsg.h

GpsNavDataMsg.c GpsNavDataMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h gps_nav_data -o GpsNavDataMsg.h

GpsTrackerDataMsg.c GpsTrackerDataMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h gps_tracker_data -o GpsTrackerDataMsg.h

GpsNavLibDataMsg.c GpsNavLibDataMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
        c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h gps_nav_lib_data -o GpsNavLibDataMsg.h

GpsGeodeticDataMsg.c GpsGeodeticDataMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h gps_geodetic -o GpsGeodeticDataMsg.h

GpsDevDataMsg.c GpsDevDataMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h gps_dev_data -o GpsDevDataMsg.h

GpsSoftVersMsg.c GpsSoftVersMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h gps_soft_version_data -o GpsSoftVersMsg.h

GpsClockStatusMsg.c GpsClockStatusMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h gps_clock_status_data -o GpsClockStatusMsg.h

GpsErrorMsg.c GpsErrorMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h gps_error_data -o GpsErrorMsg.h

GpsAlmanacStatusMsg.c GpsAlmanacStatusMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h gps_almanac_status_data -o GpsAlmanacStatusMsg.h

GpsPpsMsg.c GpsPpsMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h gps_pps_data -o GpsPpsMsg.h

GpsUnkMsg.c GpsUnkMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h gps_unk -o GpsUnkMsg.h

DtVersionMsg.c DtVersionMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h dt_version -o DtVersionMsg.h

DtEventMsg.c DtEventMsg.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h dt_event -o DtEventMsg.h

SensorConstants.h: $(MM3_PLATFORM_DIR)/sensors/sensors.h
	ncg -I$(MM3_PLATFORM_DIR) -I$(MM3_PLATFORM_DIR)/sensors/ -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sensors/sensors.h \
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
	MM3_NUM_SENSORS		  \
	-o $@

SDConstants.h: $(MM3_PLATFORM_DIR)/misc/sd_blocks.h
	ncg -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/misc/sd_blocks.h \
	DT_IGNORE                 \
	DT_CONFIG		  \
	DT_SYNC			  \
	DT_SYNC_RESTART		  \
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
	DT_EVENT_GPS_CONFIG	  \
	DT_EVENT_GPS_START	  \
	DT_EVENT_GPS_GRANT	  \
	DT_EVENT_GPS_RELEASE	  \
	DT_EVENT_GPS_OFF	  \
	DT_EVENT_GPS_FAST	  \
	DT_EVENT_GPS_FIRST	  \
				  \
	DT_HDR_SIZE_IGNORE        \
	DT_HDR_SIZE_CONFIG        \
	DT_HDR_SIZE_SYNC          \
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
	GPS_POS_BLOCK_SIZE	  \
	-o $@

serialpacket.c serialpacket.h: $(SERIAL_H)
	mig -o serialpacket.h -c-prefix=spacket c $(SERIAL_H) serial_packet

serialprotocol.h: $(SERIAL_H)
	ncg -o $@ -c-prefix=SERIAL c $(SERIAL_H) Serial.h

.c.o:
	$(CC) -c $(CFLAGS) $<

mm3dump.o: mm3dump.c mm3DataMsg.h DtIgnoreMsg.h DtConfigMsg.h DtSyncMsg.h DtPanicMsg.h DtGpsTimeMsg.h \
	DtGpsPosMsg.h DtSensorDataMsg.h DtSensorSetMsg.h DtTestMsg.h DtNoteMsg.h DtGpsRawMsg.h DtVersionMsg.h \
	DtEventMsg.h \
	GpsNavDataMsg.h GpsTrackerDataMsg.h GpsSoftVersMsg.h GpsErrorMsg.h GpsGeodeticDataMsg.h GpsPpsMsg.h \
	GpsClockStatusMsg.h GpsNavLibDataMsg.h GpsAlmanacStatusMsg.h GpsDevDataMsg.h GpsUnkMsg.h \
	ParseSirf.h \
	SensorConstants.h SDConstants.h serialpacket.h serialprotocol.h

mm3dump: mm3dump.o filesource.o mm3DataMsg.o DtIgnoreMsg.o DtConfigMsg.o DtSyncMsg.o DtPanicMsg.o DtGpsTimeMsg.o \
	DtGpsPosMsg.o DtSensorDataMsg.o DtSensorDataMsg.o DtSensorSetMsg.o DtTestMsg.o DtNoteMsg.o \
	DtGpsRawMsg.o DtVersionMsg.o GpsNavLibDataMsg.o DtEventMsg.o serialpacket.o \
	ParseSirf.o GpsNavDataMsg.o GpsTrackerDataMsg.o GpsSoftVersMsg.o GpsErrorMsg.o GpsGeodeticDataMsg.o \
	GpsClockStatusMsg.o GpsAlmanacStatusMsg.o GpsPpsMsg.o GpsDevDataMsg.o GpsUnkMsg.o \

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
DtCalStringMsg.o: DtCalStringMsg.c /opt/include/message.h \
  DtCalStringMsg.h
DtConfigMsg.o: DtConfigMsg.c /opt/include/message.h DtConfigMsg.h
DtEventMsg.o: DtEventMsg.c /opt/include/message.h DtEventMsg.h
DtGpsPosMsg.o: DtGpsPosMsg.c /opt/include/message.h DtGpsPosMsg.h
DtGpsRawMsg.o: DtGpsRawMsg.c /opt/include/message.h DtGpsRawMsg.h
DtGpsTimeMsg.o: DtGpsTimeMsg.c /opt/include/message.h DtGpsTimeMsg.h
DtIgnoreMsg.o: DtIgnoreMsg.c /opt/include/message.h DtIgnoreMsg.h
DtNoteMsg.o: DtNoteMsg.c /opt/include/message.h DtNoteMsg.h
DtPanicMsg.o: DtPanicMsg.c /opt/include/message.h DtPanicMsg.h
DtSensorDataMsg.o: DtSensorDataMsg.c /opt/include/message.h \
  DtSensorDataMsg.h
DtSensorSetMsg.o: DtSensorSetMsg.c /opt/include/message.h \
  DtSensorSetMsg.h
DtSyncMsg.o: DtSyncMsg.c /opt/include/message.h DtSyncMsg.h
DtTestMsg.o: DtTestMsg.c /opt/include/message.h DtTestMsg.h
DtVersionMsg.o: DtVersionMsg.c /opt/include/message.h DtVersionMsg.h
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
ParseSirf.o: ParseSirf.c /opt/include/serialsource.h \
  /opt/include/sfsource.h /opt/include/message.h filesource.h \
  serialpacket.h serialprotocol.h SDConstants.h DtGpsRawMsg.h ParseSirf.h \
  GpsNavDataMsg.h GpsTrackerDataMsg.h GpsGeodeticDataMsg.h \
  GpsDevDataMsg.h GpsSoftVersMsg.h GpsClockStatusMsg.h GpsPpsMsg.h \
  GpsAlmanacStatusMsg.h GpsErrorMsg.h GpsUnkMsg.h GpsNavLibDataMsg.h
filesource.o: filesource.c /opt/include/message.h filesource.h \
  serialprotocol.h serialpacket.h DtSensorDataMsg.h DtSyncMsg.h \
  mm3DataMsg.h SDConstants.h SensorConstants.h mm3dump.h
mm3DataMsg.o: mm3DataMsg.c /opt/include/message.h mm3DataMsg.h
mm3dump.o: mm3dump.c /opt/include/serialsource.h /opt/include/sfsource.h \
  /opt/include/message.h filesource.h serialpacket.h serialprotocol.h \
  mm3DataMsg.h SensorConstants.h SDConstants.h DtIgnoreMsg.h DtSyncMsg.h \
  DtPanicMsg.h DtSensorDataMsg.h DtVersionMsg.h DtEventMsg.h \
  DtGpsTimeMsg.h DtGpsPosMsg.h DtGpsRawMsg.h ParseSirf.h
serialpacket.o: serialpacket.c /opt/include/message.h serialpacket.h
