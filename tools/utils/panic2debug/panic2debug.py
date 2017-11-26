import os
import codecs
import sys
import binascii

PanicFile = "PANIC001"
DebugFileBase = ""
DebugFile = DebugFileBase + 'Panic_Block_0.dbg'
dirPart_start = 0
dirPart_end = 511
regPart_start = 804
ramPart_start = 1024
regPart_end = ramPart_start - regPart_start
ramPart_end = ramPart_start + (64 * 1024)
IoPart_start = 66560
IoPart_end = IoPart_start + 1024
dump_end = 67200

if not os.path.exists(PanicFile):
    print("Panic File Does Not Exist")
    sys.exit(0)

# if not os.path.exists(DebugFileBase):
#     os.makedirs(DebugFileBase)
#
#     if not os.path.exists(DebugFileBase):
#         print("Cannot Create Debug File Base Directory")
#         sys.exit(0)

with open(PanicFile,'rb') as PanicFile:
    raw = PanicFile.read()

cc_sigPart = raw[:804]
dir_sigPart = raw[:4]
cc_sigPartHex = binascii.hexlify(cc_sigPart)
dir_sigPartHex = binascii.hexlify(dir_sigPart)
ramStartHex = binascii.hexlify(raw[ramPart_start:ramPart_start + 8])
ramEndHex = binascii.hexlify
#print(dir_sigPartHex)
#print(cc_sigPartHex)
#print(ramStartHex)

regPart = raw[regPart_start:dump_end]
ramPart = raw[ramPart_start:ramPart_end]
IoPart = raw[IoPart_start:IoPart_end]
outFile = open(DebugFile,'wb')
regPartHex = binascii.hexlify(regPart)
IoPartHex = binascii.hexlify(IoPart)
#print(regPartHex)
outFile.write(regPart)
outFile.close
print("Success")
