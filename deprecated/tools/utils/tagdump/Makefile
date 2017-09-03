# Copyright 2008, 2017 Eric B. Decker
# Mam-Mark Project
#
# tagdump: dump/process the data file from a mammark tag.
#
# This makefile will build tagdump for the platform specified by
# MM_PLATFORM_DIR.
#

ROOT_DIR = $(MM_ROOT)
INSTALL_DIR = /usr/local/bin
TRD = $(TINYOS_ROOT_DIR)

TARGET=dev6a
TYPED_DATA=$(ROOT_DIR)/mm/include/typed_data.h

# MM_PLATFORM_DIR=$(MM_ROOT)/tos/platforms/$(TARGET)
# COMM=$(MM_ROOT)/tos/comm
# SENSORS=$(MM_ROOT)/tos/chips/sensors

# STOW_DIR=/opt

PROGRAMS=tagdump

CC=gcc
INCS    = -I$(ROOT_DIR)/include -I$(ROOT_DIR)/mm/include -I$(TRD)/tos/system
CFLAGS += -g -O0 -Wall -DREF_BUILD=$(REF_BUILD_NUM) $(INCS)
# LIBS +=

all: $(PROGRAMS)

tagdump.o: tagdump.c $(BUILD_NUM_FILE)
	$(CC) -c $(CFLAGS) $<

.c.o:
	$(CC) -c $(CFLAGS) $<

tagdump: tagdump.o filesource.o ParseSirf.o
	$(CC) -o $@ $(LDFLAGS) $^ $(LIBS)

TAGS:
	rm -f TAGS
	etags *.c *.h

clean:
	rm -f *.o *~ \#*# tmp_make .#*

veryclean: clean
	rm -f TAGS $(PROGRAMS)

dep:
	sed '/\#\#\# Dependencies/q' <Makefile >tmp_make
	$(CPP) $(CFLAGS) -MM *.c >>tmp_make
	mv tmp_make Makefile

### Dependencies
ParseSirf.o: ParseSirf.c filesource.h ParseSirf.h
filesource.o: filesource.c filesource.h
tagdump.o: tagdump.c filesource.h ParseSirf.h
