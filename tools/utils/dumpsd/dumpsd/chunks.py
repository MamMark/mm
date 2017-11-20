import os
import contextlib
from binascii import hexlify
from struct import Struct

# This is a list of all 4b chunks read from the input file
# These are typically record short headers or tintryalfs
#
chunk4b_offsets = []

sync_sig    = int('\xde\xdf\x00\xef'.encode('hex'), 16)

SECTSIZE = 512
BLKSIZE  = 508
BS       = BLKSIZE
SS       = SECTSIZE
DT_SYNC  = 3

chunk4b_offsets = []

last_seq_no = 0
s_tail = Struct('HH')
sync_struct = Struct('HHIII')
#sync_struct = Struct('HHQI')
i_struct = Struct('I')

def next_sector_pos(fd, inc=1):
    """
    position at beginning of sector

    'inc' determines how many sectors to advance
    """
    fd.seek(((fd.tell()/SS)+inc)*SS)
    return fd.tell()

def next_word_pos(fd, inc=1):
    """
    position at beginning of word (4 bytes)

    'inc' determines how many words to advance
    """
    fd.seek(((fd.tell()/4)+inc)*4)
    return fd.tell()

def get_sector_info(fd):
    """
    unpack info stored at tail of the sector
    """
    oldpos = fd.tell()
    fd.seek(((oldpos/SS)*SS)+BS)
    seq, chk = s_tail.unpack(fd.read(s_tail.size))
    fd.seek(oldpos)
    return seq, chk

def good_chksum(fd, chk):
    """
    verify checksum of byte buffer against chk value
    """
    oldpos = fd.tell()
    fd.seek((oldpos/SS)*SS)
    acc = sum(bytearray(fd.read(BS+2)))
    if acc != chk:
        print('bad chksum@({:6x}), expect: 0x{:x}, got: 0x{:x}'.format(
            fd.tell(), chk, acc))
    fd.seek(oldpos)
    return chk == acc

def valid_sequence(fd, seq):
    """
    verify next sequence matches expected, ignore zero
    """
    global last_seq_no
    old = last_seq_no
    last_seq_no = seq
    if (old == 0):
        return True
    if (seq) and (seq == (old + 1)):
        return True
    print('bad seq@({:6x}), expect:{}, got:{}'.format(fd.tell(),
                                                      old, seq))
    return False

def resync(fd):
    while (True):
        next_word_pos(fd, inc=0)  # force word boundary
        while (True):
            try:
                if (fd.tell()) == int('\xc2\xb8'.encode('hex'), 16):
                    pass
                sig = i_struct.unpack(fd.read(i_struct.size))[0]
                if sig == sync_sig:
                    break
            except:
                return -1
        seq, chk = get_sector_info(fd)
        if not good_chksum(fd, chk) or not valid_sequence(fd, seq):
            continue
        fd.seek(-sync_struct.size,1)
        buf = bytearray(fd.read(sync_struct.size))
        if (len(buf) == sync_struct.size):
#            rlen, rtype, timestamp, sig = sync_struct.unpack(buf)
            rlen, rtype, ts1, ts2, sig = sync_struct.unpack(buf)
            if (rlen == sync_struct.size) and (rtype == DT_SYNC):
#               (rtype == dt_index("SYNC")):
                fd.seek(-sync_struct.size,1)
                break                # found sync record
        else:
            return -1                # indicate end of file
    return fd.tell()

def get_chunk(fd, num):
    """
    return a chunk of bytes from the input file

    input:  'num'  number of bytes to read
    output: 'off'  offset where this chunk starts,
                   zero indicates bad read - try again
            'buf'  bytearray buffer containing chunk

    A chunk is a portion of the current logical sector that
    satisfies the 'num' bytes requested or a maximum of the
    bytes remaining in the logical sector from the current
    offset if num is larger than bytes remaining in sector.

    Records are assembled from one or more chunks.

    The input data file consists of 512 byte logical sectors,
    each ending in a halfword sequence number and a halfword
    checksum.

    Because the sequence number or checksum can fail, this
    routine handles finding the next usable sector while
    reporting the failure in return code. The caller is
    expected to reset its search for the start of a new record.

    The file position is used to control where to get the
    next chunk as well as detect and correct for logical
    sector errors (checksum or sequence number).
    """
    global last_seq_no
    if num == 0:
        return 0, ''

    first = True
    off = fd.tell()
    fd.seek(0,2)
    if (off >= fd.tell()):
        return -1, ''
    fd.seek(off)

    if (off % SS >= BS):             # ? all sector data consumed
        off = next_sector_pos(fd)
    if (off % SS == 0):              # ? beginning of new sector
                                     # verify checksum and sequence
        seq_no, chksum = get_sector_info(fd)
        if (good_chksum(fd, chksum)):
            if (first):              # ignore first sequence number
                first = False
                last_seq_no = seq_no
            elif not valid_sequence(seq_no):
                first = True
                last_seq_no = seq_no
                return 0, ''         # bad sequence, try again
        else:
            next_sector_pos(fd)
            return 0, ''             # bad checksum, try next sector
    # return chunk and position of its first byte
    csz = num if (num < (BS - (off % SS))) else (BS - (off % SS))
    buf = bytearray(fd.read(csz))
    if (len(buf) < csz):
        return -1, ''
    if (len(buf) == 4):
        chunk4b_offsets.append((off, buf))
#        print('chunk@0x{:x}: len({}): {}'.format(off, len(buf), hexlify(buf)))
    return off, buf

def unit_test(fd):
    global last_seq_no
    last_seq_no = 0
    fd.seek(0,2)
    fsize = fd.tell()
    fd.seek(0)
    for i in range(fsize/512):
        seq_no, chk = get_sector_info(fd)
        if (not good_chksum(fd, chk) or not valid_sequence(fd, seq_no)):
            print(seq_no, chk)
        next_sector_pos(fd)

    fd.seek(0)
    next_sector_pos(fd, inc=4)
    while (True):
        if (resync(fd) == -1):
            break
        print('resync@({:6x})'.format(fd.tell()))

if __name__ == '__main__':
    which_file = '../data.log'
    fd = open(which_file,'rb')
    unit_test(fd)

#filesize: 0x155cc0, sectors: 0xaad
#bafabafa  sect/index is 0x214       :0x1         :0x14
#bafabafa  sect/index is 0x238       :0x1         :0x38
#bafabafa  sect/index is 0x254       :0x1         :0x54
#ef00dfde  sect/index is 0xc2bc      :0x61        :0xbc
#ef00dfde  sect/index is 0x183e8     :0xc1        :0x1e8
#ef00dfde  sect/index is 0x245e8     :0x122       :0x1e8
#ef00dfde  sect/index is 0x306f4     :0x183       :0xf4
#ef00dfde  sect/index is 0x3c7d4     :0x1e3       :0x1d4
#ef00dfde  sect/index is 0x488cc     :0x244       :0xcc
#ef00dfde  sect/index is 0x54954     :0x2a4       :0x154
#ef00dfde  sect/index is 0x60acc     :0x305       :0xcc
#ef00dfde  sect/index is 0x6cc38     :0x366       :0x38
#ef00dfde  sect/index is 0x78d78     :0x3c6       :0x178
#ef00dfde  sect/index is 0x84ef4     :0x427       :0xf4
#ef00dfde  sect/index is 0x90fbc     :0x487       :0x1bc
#ef00dfde  sect/index is 0x9d0ac     :0x4e8       :0xac
#ef00dfde  sect/index is 0xa9768     :0x54b       :0x168
#ef00dfde  sect/index is 0xb6738     :0x5b3       :0x138
#ef00dfde  sect/index is 0xc36ec     :0x61b       :0xec
#ef00dfde  sect/index is 0xd0684     :0x683       :0x84
#ef00dfde  sect/index is 0xdd630     :0x6eb       :0x30
#ef00dfde  sect/index is 0xea5d8     :0x752       :0x1d8
#ef00dfde  sect/index is 0xf7538     :0x7ba       :0x138
#ef00dfde  sect/index is 0x10458c    :0x822       :0x18c
#ef00dfde  sect/index is 0x1115a8    :0x88a       :0x1a8
#ef00dfde  sect/index is 0x11e5a8    :0x8f2       :0x1a8
#ef00dfde  sect/index is 0x12b538    :0x95a       :0x138
#ef00dfde  sect/index is 0x1384cc    :0x9c2       :0xcc
#ef00dfde  sect/index is 0x1453f8    :0xa29       :0x1f8

#Neptune (18): hexdump -n 512 -s 0xc200 ../data.log
#000c200 13 08 01 2f 00 0b 20 00 4a 00 0a 1b 00 e8 00 09
#000c210 0e 00 63 00 06 09 00 da 00 05 18 01 24 00 4a 0c
#000c220 01 43 00 03 0f 00 3c 00 00 0b 58 b0 b3 00 00 00
#000c230 7d 00 20 00 19 f3 00 00 b8 ff 00 20 00 00 00 00
#000c240 01 00 00 00 a0 a2 00 61 0d 13 03 01 3e 00 3b 1f
#000c250 00 32 00 31 01 00 e3 00 2a 17 01 19 00 22 1d 00
#000c260 26 00 45 10 00 b7 00 3c 15 00 f2 00 24 1e 00 a6
#000c270 00 23 11 01 30 00 1e 13 01 29 00 14 06 01 29 00
#000c280 13 08 01 2f 00 0b 20 00 4a 00 0a 1b 00 e8 00 09
#000c290 0e 00 63 00 06 09 00 da 00 05 18 01 24 00 4a 0c
#000c2a0 01 43 00 03 0f 00 3c 00 00 0b 58 b0 b3 00 00 00

#000c2b0 10 00 03 00 01 f6 00 00 00 00 00 00 ef 00 df de

#000c2c0 4e 00 20 00 47 f6 00 00 b8 ff 00 20 00 00 00 00
#000c2d0 01 00 00 00 a0 a2 00 32 5c 01 00 00 00 00 00 00
#000c2e0 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
