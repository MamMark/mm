import os
import sys
import binascii
import struct


####
#
# This program reads an input source file and parses out the
# typed data records.
#
# Certain constraints on input are applied
# - input consists of a multiple of 514 bytes (the raw block size).
#   the last two bytes are stripped (used by SD for chksum).
# - each raw block is further defined to contain a logical blk
#   header of 8 bytes along with some record data.
#   The logical header bytes are stripped.
# - a record can be as large as 64k bytes (2**16)
#   each record has a standard header of length and d_type
#   followed by record-specific data
#

#RAW_BLK_SIZE        = 514
LOGICAL_BLK_SIZE    = 512
LOGICAL_BUFFER_SIZE = 508
LOGICAL_HEADER_SIZE = 4

dt_descriptor_array = [
    ("DT_TINTRYALF", 0,
     "HH", "length:{} type:{}"),
    ("DT_CONFIG", 1,
     "HH", "length:{} type:{}"),
    ("DT_SYNC", 2,
     "HHIII", "length:{} type:{}, timestamp:{3}, majik:{4}, cycle:{5}"),
    ("DT_REBOOT", 3,
     "HHIIIIIQIIIIH", "length:{} type:{}, timestamp:{}, majik:{}, cycle:{}, reset{}, reboot:{}, elapsed:{}, strange:{}, vector_chk:{}, image_chk:{}, reason:{}"),
    ("DT_PANIC", 4,
     "HHLIIIIBBB", "length:{} type:{}, timestamp:{3}, arg0:{}, arg1:{}, arg2:{}, arg3:{}, pcode:{}, where:{}, index:{}"),
    ("DT_VERSION", 5,
     "HHBBHBB", "length:{} type:{}, major:{}, minor{}, build{}, rev:{}, model:{}"),
    ("DT_EVENT", 6,
     "HHIIIIH", "length:{} type:{}, arg0:{}, arg1:{}, arg2:{}, arg3:{}, event:{}"),
    ("DT_DEBUG", 7,
     "HH", "length:{} type:{}"),
    ("DT_GPS_VERSION", 8,
     "HH", "length:{} type:{}"),
    ("DT_GPS_TIME", 9,
     "HH", "length:{} type:{}"),
    ("DT_GPS_GEO", 10,
     "HH", "length:{} type:{}"),
    ("DT_GPS_XYZ", 11,
     "HH", "length:{} type:{}"),
    ("DT_SENSOR_DATA", 12,
     "HHIIH", "length:{} type:{}, timestamp:{}, schedule:{}, sns_id:{}"),
    ("DT_SENSOR_SET", 13,
     "HHIIHH", "length:{} type:{}, timestamp:{}, schedule:{}, mask:{}, mask_id:{}"),
    ("DT_TEST", 14,
     "HH", "length:{} type:{}"),
    ("DT_NOTE", 15,
     "HHHHBBBBB", "length:{} type:{}, note_len:{}, {}.{}.{} {}:{}:{}"),
    ("DT_GPS_RAW_SIRFBIN", 16,
     "HHIIB", "length:{} type:{}, timestamp:{}, mark:{}, chip:{}"),
  ]


# generate data bytes from file (stripped of headers)
# uses generator.send() to pass number of bytes to be read
def gen_data_bytes(fd):
    offset = 0
    while (True):
        num = yield
        buf = bytearray()
        if (num):
            while (num > 0):
                if (offset == 0):
                    #                blk = raw_blks.next()
                    blk = fd.read(LOGICAL_BLK_SIZE)
                    if not blk:
                        break
                    offset += 4
                    # zzz need to check seq number
                limit = num if (num < (LOGICAL_BLK_SIZE - offset)) \
                            else LOGICAL_BLK_SIZE - offset
                buf.append(blk[offset:offset+limit])
                offset = offset + limit \
                            if ((offset + limit) < LOGICAL_BLK_SIZE) \
                            else 0
                num -= limit
        yield buf


# generate complete typed data records one at a time
def gen_records(fd):
    dt_hdr = struct.Struct("HH")
    data_bytes = gen_data_bytes(fd)
    data_bytes.send(None) # prime the generator
    while (True):
        # read size bytes
        hdr = data_bytes.send(dt_hdr.size)
        if not hdr:
            break
        rlen, rtyp = dt_hdr.unpack(hdr)
        if (rtyp > len(dt_descriptor_array)):
            break
        if (rtyp != dt_descriptor_array[rtyp][1]):
            break
        # return record header fields plus entire record
        yield rlen, rtyp, hdr + data_bytes.send(rlen)


# main processing loop
def main(source):
    with open(source, 'rb') as fd:
        for rlen, rtyp, rec in gen_records(fd):
            print(rtype, rlen, sizeof(rec), binascii.hexlify(rec))
            if (rlen < dt_rec.size):
                break
            dt_rec = struct.Struct(dt_descriptor_array[rtyp][2])
            dt_info = dt_rec.unpack(rec[:dt_rec.size])
            print(dtd[0])
            print(dtd[3].format(*dt_info))


if __name__ == "__main__":
    # filename = input('Please enter source file name: ')
    filename = 'data.log'
    main(filename)
