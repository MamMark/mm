TAGDUMP
=======

Dan Maltbie <dmaltbie@daloma.org>
copyright @ 2017 Dan Maltbie

*License*: [MIT](http://www.opensource.org/licenses/mit-license.php)

This program is able to decode the record contents from a Tag data log
file. This is a binary file with a basic structure of

- Sector = 512 bytes
- Record = 4 to 65535 bytes
         = Len(2) + Rtype(2) + Body(n-4)
- len    = length of record
- rtype  = type of record (see dt_records dict)
- recnum = record number
- systime= ms time of record (since last reboot)
- recsum = record checksum over both header and data fields
- body   = depends on rtype (with a type specific Header)

Records are defined in include/typed_data.h.

All records start with quad alignment.  Headers start on quad alignment.
The body/data area also starts on quad alignment.  This is to make sure
that any data structures that layed on to the data area conform to
reasonable alignment restrictions for modern 32 bit architectures (ARM,
Intel x86, etc.).  Little Endian only.

The Sector is the unit of bytes used by the block storage device.  It is
512 bytes.

If a record fails sanity checks (bad rtype, incorrect length, bad record
sum) a resync will be performed.  This involves locating the next sync or
reboot record (looking for SYNc_MAJIK).  And then we will back up to the
start of the record.

INSTALL:
========

> python setup.py build
> sudo python setup.py install

will install as /usr/local/bin/tagdump
