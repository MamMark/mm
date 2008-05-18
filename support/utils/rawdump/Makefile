# Copyright 2008, Eric B. Decker
# Mam-Mark Project

PROGRAMS= rawdump

CC=gcc
CFLAGS += -g -O0 -Wall

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
