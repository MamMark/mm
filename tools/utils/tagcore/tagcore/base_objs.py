# Copyright (c) 2020      Eric B. Decker
# Copyright (c) 2017-2018 Daniel J. Maltbie, Eric B. Decker
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
#
# Contact: Daniel J. Maltbie <dmaltbie@daloma.org>
#          Eric B. Decker <cire831@gmail.com>

'''base classes for defining record objects'''

import struct
import copy
from   collections import OrderedDict
from   misc_utils  import dump_buf

import tagcore.globals        as     g
from   misc_utils             import dump_buf
from   misc_utils             import eprint
from   tagcore.imageinfo_defs import iip_tlv_name
from   tagcore.imageinfo_defs import IMAGE_INFO_PLUS_SIZE
from   tagcore.imageinfo_defs import IIP_TLV_END

__version__ = '0.4.8.dev1'

class atom(object):
    '''
    takes 2-tuple: ('struct_string', 'default_print_format')
    optional 3-tuple: (..., ..., formating_function)

    set will set the instance.attribute "val" to the value
    of the atom's decode of the buffer.
    '''
    def __init__(self, a_tuple):
        self.s_str = a_tuple[0]
        self.s_rec = struct.Struct(self.s_str)
        self.p_str = a_tuple[1]
        if (len(a_tuple) > 2):
            self.f_str = a_tuple[2]
        else:
            self.f_str = None
        self.val = None

    def __len__(self):
        return self.s_rec.size

    def __repr__(self):
        if self.val == None:
            return 'notset'

        try:
            if callable(self.f_str):
                return self.p_str.format(self.f_str(self.val))
            return self.p_str.format(self.val)
        except ValueError:
            raise ValueError('p_str: <{}>'.format(self.p_str))

    def set(self, buf):
        '''
        set the atom.val to the unpack from the format string.

        return the number of bytes (size) consumed
        '''
        self.val = self.s_rec.unpack(buf[:self.s_rec.size])[0]
        return self.s_rec.size

    def build(self):
        return self.s_rec.pack(self.val)


class aggie(OrderedDict):
    '''
    aggie: aggregation node.
    takes one parameter a dictionary of key -> {atom | aggie}
    '''
    def __init__(self, a_dict):
        super(aggie, self).__init__(a_dict)

    def __len__(self):
        l = 0
        for key, v_obj in self.iteritems():
            if isinstance(v_obj, atom) or isinstance(v_obj, aggie):
                l += v_obj.__len__()
        return l

    def __repr__(self):
        s = ''
        for key, v_obj in self.iteritems():
            if len(s) != 0:
                s += '  '
            if isinstance(v_obj, atom):
                s += key + ': ' + v_obj.__repr__()
            elif isinstance(v_obj, aggie):
                s += '[' + key + ': ' + v_obj.__repr__() + ']\n'
            elif isinstance(v_obj, tlv_block_aggie):
                s += '[' + key + ': ' + v_obj.__repr__() + ']\n'
            else:
                s += '({},{})'.format(key, v_obj)
        return s

    def set(self, buf):
        consumed = 0
        for key, v_obj in self.iteritems():
            consumed += v_obj.set(buf[consumed:])
        return consumed

    def build(self):
        out = ''
        for key, v_obj in self.iteritems():
            out += v_obj.build()
        return out


class tlv_aggie(aggie):
    '''
    tlv_aggie: aggregation node for a tlv, (tlv_type, tlv_len, tlv_value)
        takes one parameter an ordered dictionary defining what the
        tlv header looks like (key -> {atom | aggie})

    tlv_aggie will first create a header with the tlv_type and tlv_len.
    Calling .set() or .tlv_force() will populate the 3rd field, tlv_value.

    tlv_type,  the type of this tlv.
    tlv_len,   length of the entire tlv block.
    tlv_value, string value of the tlv.
    '''

    def __init__(self, a_dict):
        super(tlv_aggie, self).__init__(a_dict)

    def set(self, buf):
        #
        # a tlv_aggie object, when created, has definitions for the
        # tlv_type and tlv_len.  Using tlv_len, we can suck the appropriate
        # number of bytes as tlv_value.
        #
        tlv_type  = buf[0]
        tlv_len   = buf[1]
        tlv_value = buf[2: tlv_len]
        self['tlv_type'].val  = tlv_type
        self['tlv_len'].val   = tlv_len
        self['tlv_value'].val = tlv_value
        consumed = tlv_len
        return consumed

    def __repr__(self):
        out = super(tlv_aggie, self).__repr__()
        if g.debug:
            tlv_type  = self['tlv_type'].val
            tlv_len   = self['tlv_len'].val
            tlv_value = self.get('tlv_value', None)
            out += '\n** [tlv: <{}, {}>, <{}>, <{}>] **'.format(
                        tlv_type, iip_tlv_name(tlv_type),
                        tlv_len, tlv_value)
        return out

    def tlv_force(self, tlv_type, tlv_len, tlv_value):
        '''
        force a tlv entry to a particular tlv_value.
        if tlv_type already exists we replace its previous value.
        '''
        self['tlv_type'].val  = tlv_type
        self['tlv_len'].val   = tlv_len
        self['tlv_value'].val = tlv_value
        return tlv_len

    def build(self):
        out = ''
        for key, v_obj in self.iteritems():
            out += v_obj.build()
        return out


class tlv_block_aggie(aggie):
    '''
    tlv_block_aggie: aggregation node for multiple tlvs coming
    from one block of memory.
    '''

    def __init__(self, a_dict):
        self.tlv_blocks    = OrderedDict()
        self.max_block_len = IMAGE_INFO_PLUS_SIZE       # assumption, should be good
        self.cur_block_len = 0
        super(tlv_block_aggie, self).__init__(a_dict)

    def set(self, buf):
        consumed = super(tlv_block_aggie, self).set(buf)
        tlv_consumed = 0
        while True:
            if consumed >= len(buf) or buf[consumed] == '\0':
                break;
            # first, peek, 1st byte tlv_type, 2nd tlv_len
            # we need tlv_len to properly build the tlv_aggie.
            tlv_type = buf[consumed]
            tlv_len  = buf[consumed + 1]
            tlv = tlv_aggie(aggie(OrderedDict([
                ('tlv_type',  atom(('<B', '{}'))),
                ('tlv_len',   atom(('<B', '{}'))),
                ('tlv_value', atom(('{}s'.format(tlv_len - 2), '{}'))),
            ])))
            consumed += tlv.set(buf[consumed:])
            tlv_type  = tlv['tlv_type'].val
            self.tlv_blocks[tlv_type] = tlv

        self.cur_block_len += consumed
        return consumed

    def set_max(self, max_len):
        self.max_block_len = max_len

    def getPlusSize(self):
        return self.cur_block_len, self.max_block_len

    def add_tlv(self, tlv_type, tlv_value):
        tlv_len = len(tlv_value)
        if tlv_len == 0:
            return 0

        tlv = tlv_aggie(aggie(OrderedDict([
            ('tlv_type',  atom(('<B', '{}'))),
            ('tlv_len',   atom(('<B', '{}'))),
            ('tlv_value', atom(('{}s'.format(len(tlv_value)),  '{}'))),
        ])))
        tlv_len = len(tlv)              # should now be correct

        # If we can't add this TLV without going over max_block_len. we fail
        if self.cur_block_len + tlv_len > self.max_block_len:
            return 0

        consumed = tlv.tlv_force(tlv_type, tlv_len, tlv_value)
        if tlv_type in self.tlv_blocks:
            # subtract off previous length
            old_tlv = self.tlv_blocks[tlv_type]
            self.cur_block_len -= old_tlv['tlv_len'].val
            del self.tlv_blocks[tlv_type]
        self.cur_block_len += consumed
        self.tlv_blocks[tlv_type] = tlv
        return consumed

    def get_tlv(self, tlv_type):
        tlv = self.tlv_blocks[tlv_type]
        return tlv.value

    def get_tlv_rows(self):
        return self.tlv_blocks.items()

    def build_tlv(self):
        out = ''
        for ttype, v_obj in self.tlv_blocks.items():
            if g.debug:
                eprint('** build_tlv: {} {} {}'.format(ttype, v_obj, type(v_obj)))
            if isinstance(v_obj, aggie) or isinstance(v_obj, atom):
                out += v_obj.build()
            else:
                raise RuntimeError('build_tlv: wrong object type, {}'.format(type(v_obj)))
        return out

    def __repr__(self):
        out = super(tlv_block_aggie, self).__repr__()
        for key, v_obj in self.tlv_blocks.items():
            out += v_obj.__repr__()
        return out

    def build(self):
        out = super(tlv_block_aggie, self).build()
        return out
