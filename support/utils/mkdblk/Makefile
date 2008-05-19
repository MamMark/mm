# $Id: Makefile,v 1.3 2006/07/08 07:54:11 cire Exp $
# Copyright 2006, Eric B. Decker
# Mam-Mark Project

F_DIR   = ../fat

SOURCE  = mkdblk.c ms_unix.c ms_util.c util.c $(F_DIR)/fatxfc.c
OBJECTS = mkdblk.o fatxfc.o ms_unix.o ms_util.o util.o

CFLAGS += -g -Wall -O0 -I../include -I../fat -I.
VPATH = $(F_DIR)

all: mkdblk

mkdblk: $(OBJECTS)
	$(CC) -o $@ $(LDFLAGS) $^

.c.o:
	$(CC) -c $(CFLAGS) $<

clean:
	rm -f *.o *.s *.i *~ \#*# tmp_make .#* .new*

distclean: clean
	rm -f *.a scanfat

tags:	$(SOURCE) $(F_DIR)/*.h *.h
	etags $(SOURCE) $(F_DIR)/*.h *.h

dep:
	sed '/\#\#\# Dependencies/q' <Makefile >tmp_make
	$(CPP) $(CFLAGS) -MM $(SOURCE) $(S_FAT) >>tmp_make
	mv tmp_make Makefile

### Dependencies
