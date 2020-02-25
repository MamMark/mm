# Copyright (c) 2020 Eric B. Decker
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# See COPYING in the top level directory of this source tree.

__all__ = [
    'IMAGE_INFO_SIG',
    'IMAGE_META_OFFSET',

    'IMAGE_INFO_BASIC_SIZE',
    'IMAGE_INFO_PLUS_SIZE',
    'IMAGE_INFO_SIZE',

    'IMAGE_MIN_SIZE',

    'IIP_TLV_END',
    'IIP_TLV_DESC',
    'IIP_TLV_REPO0',
    'IIP_TLV_REPO0URL',
    'IIP_TLV_REPO1',
    'IIP_TLV_REPO1URL',
    'IIP_TLV_STAMP',
]


IMAGE_INFO_SIG        = 0x33275401
IMAGE_META_OFFSET     = 0x140
IMAGE_INFO_BASIC_SIZE = 32
IMAGE_INFO_PLUS_SIZE  = 300
IMAGE_INFO_SIZE       = IMAGE_INFO_BASIC_SIZE + IMAGE_INFO_PLUS_SIZE
IMAGE_MIN_SIZE        = 1024

# do not recycle or reorder number.  Feel free to add.
# one byte, max value 255, 0 says done.

IIP_TLV_END           = 0
IIP_TLV_DESC          = 1
IIP_TLV_REPO0         = 2
IIP_TLV_REPO0URL      = 3
IIP_TLV_REPO1         = 4
IIP_TLV_REPO1URL      = 5
IIP_TLV_STAMP         = 6

iip_tlv = {
    'end'       : 0,
    'desc'      : 1,
    'repo0'     : 2,
    'repo0Url'  : 3,
    'repo1'     : 4,
    'repo1Url'  : 5,
    'stamp'     : 6,

    0           : 'end',
    1           : 'desc',
    2           : 'repo0',
    3           : 'repo0Url',
    4           : 'repo1',
    5           : 'repo1Url',
    6           : 'stamp',
}


def iip_tlv_name(tlv_type):
    unk_name = 'tlv/' + str(tlv_type)
    name = iip_tlv.get(tlv_type, unk_name) if isinstance(tlv_type, int) else \
               tlv_type
    return name
