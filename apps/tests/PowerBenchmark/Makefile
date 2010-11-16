COMPONENT=PowerBenchmarkC
BUILD_EXTRA_DEPS += McuPowerStats.class
CLEAN_EXTRA = *.class McuPowerStatsMsg.java

CFLAGS += -I$(TOSDIR)/lib/T2Hack

McuPowerStats.class: $(wildcard *.java) McuPowerStatsMsg.java
	javac -target 1.4 -source 1.4 *.java

McuPowerStatsMsg.java:
	mig java -target=null $(CFLAGS) -java-classname=McuPowerStatsMsg McuPowerStats.h mcustat -o $@

include $(MAKERULES)
