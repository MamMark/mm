
GEN=CollectMsg.java DtIgnoreMsg.java DtSensorDataMsg.java SensorConstants.java \
    SDConstants.java

MAMMARK_PLATFORM_DIR=$(MAMMARK_DIR)/tos/platforms/mm3

all: Mm3SerialCollectApp.jar

Mm3SerialCollectApp.jar: Mm3SerialCollectApp.class
	jar cf $@ *.class

CollectMsg.java: $(MAMMARK_PLATFORM_DIR)/collect_msg.h
	mig -I$(MAMMARK_PLATFORM_DIR) -target=mm3 \
	-java-classname=CollectMsg java $(MAMMARK_PLATFORM_DIR)/collect_msg.h collect_msg -o $@

DtIgnoreMsg.java: $(MAMMARK_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MAMMARK_PLATFORM_DIR) -target=mm3 \
	-java-classname=DtIgnoreMsg java $(MAMMARK_PLATFORM_DIR)/sd_blocks.h dt_ignore -o $@

DtSensorDataMsg.java: $(MAMMARK_PLATFORM_DIR)/sd_blocks.h
	mig -I$(MAMMARK_PLATFORM_DIR) -target=mm3 \
	-java-classname=DtSensorDataMsg java $(MAMMARK_PLATFORM_DIR)/sd_blocks.h dt_sensor_data -o $@

SensorConstants.java: $(MAMMARK_PLATFORM_DIR)/sensors/sensors.h
	ncg -I$(MAMMARK_PLATFORM_DIR) -I$(MAMMARK_PLATFORM_DIR)/sensors/ -target=mm3 \
	-java-classname=SensorConstants java $(MAMMARK_PLATFORM_DIR)/sensors/sensors.h \
	SNS_ID_NONE               \
	SNS_ID_BATT               \
	SNS_ID_TEMP               \
	SNS_ID_SAL                \
	SNS_ID_ACCEL              \
	SNS_ID_PTEMP              \
	SNS_ID_PRESS              \
	SNS_ID_SPEED              \
	SNS_ID_MAG                \
	-o $@

SDConstants.java: $(MAMMARK_PLATFORM_DIR)/sd_blocks.h
	ncg -I$(MAMMARK_PLATFORM_DIR) -target=mm3 \
	-java-classname=SDConstants java $(MAMMARK_PLATFORM_DIR)/sd_blocks.h \
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

Mm3SerialCollectApp.class: $(wildcard *.java) $(GEN)
	javac *.java

clean:
	rm -f *.class $(GEN)

veryclean: clean
	rm Mm3SerialCollectApp.jar
