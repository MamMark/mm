# Copyright 2008, Eric B. Decker
# Mam-Mark Project

PROGRAMS= mm3dump

CC=gcc
CFLAGS += -g -O0 -Wall -I/usr/local/include
LIBS += -lmote

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
    DtCalStringMsg.h DtCalStringMsg.c \
    DtGpsRawMsg.h DtGpsRawMsg.c \
    DtVersionMsg.h DtVersionMsg.c \
    SDConstants.h SensorConstants.h \
    serialpacket.c serialpacket.h serialprotocol.h

SERIAL_H = $(TOSDIR)/lib/serial/Serial.h
MM3_PLATFORM_DIR=../../../tos/platforms/mm3

all: $(PROGRAMS)

mm3DataMsg.h: $(MM3_PLATFORM_DIR)/mm3_data_msg.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/mm3_data_msg.h mm3_data_msg -o mm3DataMsg.h

DtIgnoreMsg.c DtIgnoreMsg.h: $(MM3_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sd_blocks.h dt_ignore -o DtIgnoreMsg.h

DtConfigMsg.c DtConfigMsg.h: $(MM3_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sd_blocks.h dt_config -o DtConfigMsg.h

DtSyncMsg.c DtSyncMsg.h: $(MM3_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sd_blocks.h dt_sync -o DtSyncMsg.h

DtPanicMsg.c DtPanicMsg.h: $(MM3_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sd_blocks.h dt_panic -o DtPanicMsg.h

DtGpsTimeMsg.c DtGpsTimeMsg.h: $(MM3_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sd_blocks.h dt_gps_time -o DtGpsTimeMsg.h

DtGpsPosMsg.c DtGpsPosMsg.h: $(MM3_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sd_blocks.h dt_gps_pos -o DtGpsPosMsg.h

DtSensorDataMsg.c DtSensorDataMsg.h: $(MM3_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sd_blocks.h dt_sensor_data -o DtSensorDataMsg.h

DtSensorSetMsg.c DtSensorSetMsg.h: $(MM3_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sd_blocks.h dt_sensor_set -o DtSensorSetMsg.h

DtTestMsg.c DtTestMsg.h: $(MM3_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sd_blocks.h dt_test -o DtTestMsg.h

DtCalStringMsg.c DtCalStringMsg.h: $(MM3_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sd_blocks.h dt_cal_string -o DtCalStringMsg.h

DtGpsRawMsg.c DtGpsRawMsg.h: $(MM3_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sd_blocks.h dt_gps_raw -o DtGpsRawMsg.h

DtVersionMsg.c DtVersionMsg.h: $(MM3_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sd_blocks.h dt_version -o DtVersionMsg.h

SensorConstants.h: $(MM3_PLATFORM_DIR)/sensors/sensors.h
	ncg -I$(MM3_PLATFORM_DIR) -I$(MM3_PLATFORM_DIR)/sensors/ -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sensors/sensors.h \
	SNS_ID_NONE               \
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

SDConstants.h: $(MM3_PLATFORM_DIR)/sd_blocks.h
	ncg -I$(MM3_PLATFORM_DIR) -target=mm3 \
	c $(MM3_PLATFORM_DIR)/sd_blocks.h \
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
	DT_CAL_STRING		  \
	DT_GPS_RAW		  \
	DT_VERSION		  \
				  \
	DT_HDR_SIZE_IGNORE        \
	DT_HDR_SIZE_CONFIG        \
	DT_HDR_SIZE_SYNC          \
	DT_HDR_SIZE_GPS_TIME      \
	DT_HDR_SIZE_GPS_POS       \
	DT_HDR_SIZE_SENSOR_DATA   \
	DT_HDR_SIZE_SENSOR_SET    \
	DT_HDR_SIZE_CAL_STRING    \
	DT_HDR_SIZE_GPS_RAW       \
	DT_HDR_SIZE_VERSION       \
	DT_HDR_SIZE_TEST          \
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
	-o $@

serialpacket.c serialpacket.h: $(SERIAL_H)
	mig -o serialpacket.h -c-prefix=spacket c $(SERIAL_H) serial_packet

serialprotocol.h: $(SERIAL_H)
	ncg -o $@ -c-prefix=SERIAL c $(SERIAL_H) Serial.h

.c.o:
	$(CC) -c $(CFLAGS) $<

mm3dump.o: mm3dump.c mm3DataMsg.h DtIgnoreMsg.h DtConfigMsg.h DtSyncMsg.h DtPanicMsg.h DtGpsTimeMsg.h \
	DtGpsPosMsg.h DtSensorDataMsg.h DtSensorSetMsg.h DtTestMsg.h DtCalStringMsg.h DtGpsRawMsg.h DtVersionMsg.h \
	SensorConstants.h SDConstants.h serialpacket.h serialprotocol.h

mm3dump: mm3dump.o mm3DataMsg.o DtIgnoreMsg.o DtConfigMsg.o DtSyncMsg.o DtPanicMsg.o DtGpsTimeMsg.o \
	DtGpsPosMsg.o DtSensorDataMsg.o DtSensorDataMsg.o DtSensorSetMsg.o DtTestMsg.o DtCalStringMsg.o \
	DtGpsRawMsg.o DtVersionMsg.o serialpacket.o
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
