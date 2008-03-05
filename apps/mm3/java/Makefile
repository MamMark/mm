GEN=CollectMsg.java DtIgnoreMsg.java DtSensorDataMsg.java

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

Mm3SerialCollectApp.class: $(wildcard *.java) $(GEN)
	javac *.java

clean:
	rm -f *.class $(GEN)

veryclean: clean
	rm Mm3SerialCollectApp.jar
