PIX
===

Eric B. Decker <cire831@gmail.com>
copyright (c) 2018 Eric B. Decker

*License*: [GPL3](https://opensource.org/licenses/GPL-3.0)

This program is used to examine and extract panics.

The PANIC file from a tag can contain one or more panic dumps from
a running tag.

PIX first will display what panics are in the file.  One can also
extract a specific panic.  This extraction will be in CrashDump format
and then can be used to examine the crash using gdb.

Requires tagcore.

INSTALL:
========

> sudo python setup.py install

will install as /usr/local/bin/pix
