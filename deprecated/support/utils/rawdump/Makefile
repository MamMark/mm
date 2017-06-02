# Copyright 2008, 2010, Eric B. Decker
# Mam-Mark Project

STOW_DIR=/opt

PROGRAMS= rawdump

CC=gcc
CFLAGS += -g -O0 -Wall -I$(STOW_DIR)/include
LIBS += $(STOW_DIR)/lib/libmote.a

all: $(PROGRAMS)

.c.o:
	$(CC) -c $(CFLAGS) $<

rawdump: rawdump.o
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
