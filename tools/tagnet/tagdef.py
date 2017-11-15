from construct import *

#from enum import Enum, unique
import enum

@enum.unique
class tlv_types(enum.Enum):
    NONE                   =  0
    STRING                 =  1
    INTEGER                =  2
    GPS                    =  3
    TIME                   =  4
    NODE_ID                =  5
    NODE_NAME              =  6
    OFFSET                 =  7
    SIZE                   =  8
    EOF                    =  9
    VERSION                = 10
    BLOCK                  = 11

TAGNET_VERSION = 1
DEFAULT_HOPCOUNT = 20
MAX_HOPCOUNT = 31

tagnet_message_header_s = Struct('tagnet_message_header_s',
                                 Byte('frame_length'),
                                 BitStruct('options',
                                           Flag('response'),
                                           BitField('version',3),
                                           Padding(3),
                                           Enum(BitField('tlv_payload',1),
                                                RAW               = 0,
                                                TLV_LIST          = 1,
                                                ),
                                           Enum(BitField('message_type',3),
                                                POLL              = 0,
                                                BEACON            = 1,
                                                HEAD              = 2,
                                                PUT               = 3,
                                                GET               = 4,
                                                DELETE            = 5,
                                                OPTION            = 6,
                                                ),
                                           Union('param',
                                                 BitField('hop_count',5),
                                                 Enum(BitField('error_code',5),
                                                      OK              = 0,
                                                      NO_ROUTE        = 1,
                                                      TOO_MANY_HOPS   = 2,
                                                      MTU_EXCEEDED    = 3,
                                                      UNSUPPORTED     = 4,
                                                      BAD_MESSAGE     = 5,
                                                      FAILED          = 6,
                                                      ),
                                                 ),
                                           ),
                                 Byte('name_length'),
                                 )


# gps format:  '32.30642N122.61458W'
# time format: '1470998711.36'
