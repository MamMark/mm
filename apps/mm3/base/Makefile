# Copyright 2008, Eric B. Decker
# Mam-Mark Project

PROGRAMS=seriallisten sflisten

CFLAGS += -g -O0 -Wall -I/usr/local/include
LIBS += -lmote

all: $(PROGRAMS)

seriallisten: seriallisten.o
	$(CC) -o $@ $(LDFLAGS) $^ $(LIBS)

sflisten: sflisten.o
	$(CC) -o $@ $(LDFLAGS) $^ $(LIBS)

.c.o:
	$(CC) -c $(CFLAGS) $<

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
