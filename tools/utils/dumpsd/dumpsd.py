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
# - input consists of a multiple of 512 bytes (the sector size).
# - each sector is further defined to contain a logical blk
#   trailer of 4 bytes along with up to 508 bytes of record data.
#   (uint16_t sequence_no, uint16_t checksum)
#   The logical trailer bytes are stripped.
# - a record can be as large as 64k bytes (2**16)
#   each record has a standard header of length and d_type (4 bytes)
#   followed by record-specific data
# - records
#

LOGICAL_SECTOR_SIZE = 512
LOGICAL_BLOCK_SIZE  = 508  # excludes trailer
LOGICAL_HEADER_SIZE = 4

# the dt_descriptor_array contains contains details about each record type,
# including: name of record, id of record, struct format for unpacking,
# and format string for printing
#
dt_descriptor_array = [
    ("DT_TINTRYALF", 0,
     "HH", "length:{} type:{}"),
    ("DT_CONFIG", 1,
     "HH", "length:{} type:{}"),
    ("DT_SYNC", 2,
     "HHIII", "length:{} type:{}, timestamp:{}, majik:{}, cycle:{}"),
    ("DT_REBOOT", 3,
     "HHIIIIIQIIIIH", "length:{} type:{}, timestamp:{}, majik:{}, cycle:{}, reset{}, reboot:{}, elapsed:{}, strange:{}, vector_chk:{}, image_chk:{}, reason:{}"),
    ("DT_PANIC", 4,
     "HHLIIIIBBB", "length:{} type:{}, timestamp:{3}, arg0:{}, arg1:{}, arg2:{}, arg3:{}, pcode:{}, where:{}, index:{}"),
    ("DT_VERSION", 5,
     "HHBBHBB", "length:{} type:{}, major:{}, minor:{}, build:{}, rev:{}, model:{}"),
    ("DT_EVENT", 6,
     "HHIIIIH", "length:{} type:{}, arg0:0x{:02x}, arg1:0x{:02x}, arg2:0x{:02x}, arg3:0x{:02x}, event:{}"),
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


# gen_data_bytes generates data bytes from file (stripped of non-data bytes).
#
# Uses generator.send() to pass number of bytes to be read
# the number of bytes to read is returned by the yield, while
# the buffer read is returned by the yield
#
# The buffer will be as large as requested, which may require additional
# sectors to be read. Any remaining data in the sector will be used
# in the next yield request.
#
def gen_data_bytes(fd):
    # skip first block
    blk = fd.read(LOGICAL_SECTOR_SIZE)
    if not blk:
        return
    blk_struct = struct.Struct("508sHH")
    offset = 0
    old_seq_no = 0
    buf = bytearray()
    while (True):
        num = yield offset, buf
        buf = bytearray() # clear the return buffer each time
        if (num < 0):
            offset = 0  # force a skip to next sector
        else:
            while (num > 0):
                if (offset == 0):
                    sect = fd.read(LOGICAL_SECTOR_SIZE)
                    if not sect:
                        break
                    blk, seq_no, chk_sum = blk_struct.unpack(sect)
                    # check sequence number for discontinuity
                    if (seq_no) and (seq_no != (old_seq_no + 1)):
                        print(old_seq_no, seq_no)
                        break
                    old_seq_no = seq_no
                limit = num if (num < (LOGICAL_BLOCK_SIZE - offset)) \
                            else LOGICAL_BLOCK_SIZE - offset
                buf.extend(blk[offset:offset+limit])
                offset = offset + limit \
                         if ((offset + limit) < LOGICAL_BLOCK_SIZE) \
                            else 0
                num -= limit


# generate complete typed data records one at a time
#
# yields one record each time (len, type, data)
#
def gen_records(fd):
    dt_hdr = struct.Struct("HH")
    data_bytes = gen_data_bytes(fd)
    data_bytes.send(None) # prime the generator
    while (True):
        # read size bytes
        offset, hdr = data_bytes.send(dt_hdr.size)
        if (not hdr) or (len(hdr) < LOGICAL_HEADER_SIZE):
            break
        rlen, rtyp = dt_hdr.unpack(hdr)
        if (rtyp > len(dt_descriptor_array)):
            break
        if (rtyp != dt_descriptor_array[rtyp][1]):
            break
        if (rtyp == dt_descriptor_array[0][1]): # tinytryalf
            data_bytes.send(-1)   # skip to next sector
            continue
        # return record header fields plus record contents
        offset, pl = data_bytes.send(rlen - LOGICAL_HEADER_SIZE)
        pl = hdr + pl
        yield rlen, rtyp, offset, pl
        if (rlen % 4):
            data_bytes.send(4 - (rlen % 4))  # skip to next word boundary

def insert_space(st):
    """
    Convert byte array into string and insert space periodically to
    break up long string
    """
    p_ds = ''
    ix = 4
    i = 0
    p_s = binascii.hexlify(st)
    while (i < (len(st) * 2)):
        p_ds += p_s[i:i+ix] + ' '
        i += ix
    return p_ds

# main processing loop
#
# look for records and print out details for each one found
#
def main(source):
    total = 0
    with open(source, 'rb') as fd:
        for rlen, rtyp, offset, buf in gen_records(fd):
            print(rtyp, rlen, len(buf), (fd.tell()-512)+offset, hex((fd.tell()-512)+offset), insert_space(buf))
            if (rlen < len(buf)) or (rtyp >= len(dt_descriptor_array)):
                break
            dtd = dt_descriptor_array[rtyp]
            dt_rec = struct.Struct(dtd[2])
            dt_info = dt_rec.unpack(buf[:dt_rec.size])
            print(dtd[0])
            print(dtd[3].format(*dt_info))
            total += rlen
            print('----')
        print(fd.tell(),  total)


if __name__ == "__main__":
    # filename = input('Please enter source file name: ')
    filename = 'data.log'
    main(filename)
