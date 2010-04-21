# Copyright 2010, Eric B. Decker
# Mam-Mark Project
#
# Unix side commands for communicating with a tag.
#
# mmping: ping a node.
# mmnote: send a time stamped note to the tag to be written into the SD
#
# This makefile will build tools for communicating with the platform
# specified by MM_PLATFORM_DIR.  Shared platform files must be pointed
# to by MM_COMMON.
#

TARGET=mm4
MM_PLATFORM_DIR=$(MM_ROOT)/tos/platforms/$(TARGET)
MM_COMMON=$(MM_ROOT)/tos/platforms/mm
COMM=$(MM_ROOT)/tos/comm

STOW_DIR = /opt

PROGRAMS = mmping mmnote

CC=gcc
CFLAGS += -g -O0 -Wall -I$(STOW_DIR)/include -I$(COMM)
LIBS += $(STOW_DIR)/lib/libmote.a

GEN = gCmdIDs.h mmCmd.h mmCmd.c mmCmdNote.h mmCmdNote.c \
      serialpacket.c serialpacket.h serialprotocol.h

SERIAL_H = $(TOSDIR)/lib/serial/Serial.h

all: $(PROGRAMS)

#
# ../mm_control.h contains definitions for any commands and responses
# sent between the base station and the tag.
#
# mm_control.h is run through mig to produce access routines
# for each control packet.  Mig generates a C file and associated
# header.  A seperate C,h pair is generated for each network control
# packet.  Ncg is used to extract any enums needed.
#
# Convention: basic command header, mm_cmd, produces mmCmd.{c,h}.  And
# structure mm_cmd_note, produces mmCmdNote.{c,h}.
#

mmCmd.c mmCmd.h:  ../mm_control.h
	mig -o mmCmd.h -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c ../mm_control.h mm_cmd

mmCmdNote.c mmCmdNote.h:  ../mm_control.h
	mig -o mmCmdNote.h -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) -target=$(TARGET) \
	c ../mm_control.h mm_cmd_note

gCmdIDs.h: ../mm_control.h
	ncg -o $@ -I$(MM_COMMON) -I$(MM_PLATFORM_DIR) \
	-target=$(TARGET) c $<  \
	CMD_PING		\
	CMD_WR_NOTE		\
	CMD_RESPONSE

serialpacket.c serialpacket.h: $(SERIAL_H)
	mig -o serialpacket.h -c-prefix=spacket c $(SERIAL_H) serial_packet

serialprotocol.h: $(SERIAL_H)
	ncg -o $@ -c-prefix=SERIAL c $(SERIAL_H) Serial.h

.c.o:
	$(CC) -c $(CFLAGS) $<

mmping: ping.o mmCmd.o
	$(CC) -o $@ $(LDFLAGS) $^ $(LIBS)

mmnote: note.o mmCmd.o mmCmdNote.o
	$(CC) -o $@ $(LDFLAGS) $^ $(LIBS)

TAGS:
	rm -f TAGS
	etags *.c *.h

clean:
	rm -f *.o *~ \#*# tmp_make .#*

veryclean: clean
	rm -f TAGS $(PROGRAMS) $(GEN)

dep: $(GEN)
	sed '/\#\#\# Dependencies/q' <Makefile >tmp_make
	$(CPP) $(CFLAGS) -MM *.c >>tmp_make
	mv tmp_make Makefile

### Dependencies
mmCmd.o: mmCmd.c /opt/include/message.h mmCmd.h
mmCmdNote.o: mmCmdNote.c /opt/include/message.h mmCmdNote.h
note.o: note.c /opt/include/serialsource.h /opt/include/sfsource.h \
 /opt/include/message.h serialpacket.h serialprotocol.h \
 /home/cire/mm/t2_mm/tos/comm/am_types.h gCmdIDs.h mmCmd.h mmCmdNote.h
ping.o: ping.c /opt/include/serialsource.h /opt/include/sfsource.h \
 /opt/include/message.h serialpacket.h serialprotocol.h \
 /home/cire/mm/t2_mm/tos/comm/am_types.h gCmdIDs.h mmCmd.h
serialpacket.o: serialpacket.c /opt/include/message.h serialpacket.h
