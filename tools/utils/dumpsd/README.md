DUMPSD
======

Dan Maltbie <dmaltbie@daloma.org>
copyright @ 2017 Dan Maltbie

*License*: [MIT](http://www.opensource.org/licenses/mit-license.php)

This program is able to decode the record contents from a Tag
data log file. This is a binary file with a basic structure of

- Sector = 512 bytes
         = Block(508) + Sequence(2) + Checksum(2)
- Record = 4 to 65000 bytes
         = Len(2) + Rtype(2) + Body(n)
- Len    = length of record
- Rtype  = type of record (see dt_records dict)
- Body   = depends on rtype (with a type specific Header)

The Sector is the unit of bytes used by the block storage device.

The Sector checksum must first be validated before using bytes
from its Block. If the checksum fails, a search for the sync record
will be started at the next sector with a valid checksum (may
skip more than one until a good sector is found).

A Record is stored in the Block of a Sector. More than one Record
can be store in a given Block. A Record can also span Blocks. All
Records start on a word (4 byte) boundary and are padded up to a
word as well.

A bad Rtype will cause a search for the sync record from the file
position just after the previously Record (before the bad record).

Since a record can span more than one Sector, it is necessary to
detect Sequence errors. When an error is detected, a search for
sync is started from the current location.

Both the Checksum error and the Sequence error will cause a bad
Record error. The next record following an error is the sync
record found in the search. Otherwise end-of-file.

A special Record (TINTRYALF) may be the last record in a Block,
depending on whether the Header of next Record to be written to
the log can completely fit in the block. If it fits, then the
Block is completely filled. If it won't fit, a TINTRYALF (this
is not the record you are looking for) is written to fill the
remaining space. TINTRYALF is only one word so is assured to
fit into the last free word of the sector.
