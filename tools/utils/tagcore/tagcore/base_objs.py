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

__version__ = '0.4.6'

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
                raise RuntimeError('object not aggie/atom: [{}], '
                                   'oops!'.format(v_obj))
        return s

    def set(self, buf):
        '''
        '''
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
    tlv_aggie: aggregation node for a tlv
    takes one parameter an ordered dictionary defining what the
    tlv header looks like (key -> {atom | aggie})

    tlv_aggie will first create just the header, then using header
    via set will populate the data key.
    '''

    tlv_hdr_len = 2	#default to the 'T/L' bytes
    tlv_value = None

    def __init__(self, a_dict):
        self.tlv_value = ''
        super(tlv_aggie, self).__init__(a_dict)

    def set(self, buf):
        #
        # First collect T & L... V is done manually
        #
        self.tlv_hdr_len = super(tlv_aggie, self).set(buf)
        tlv_type = self['tlv_type'].val
        tlv_len = self['tlv_len'].val
        self.tlv_value = buf[self.tlv_hdr_len:self.tlv_hdr_len+tlv_len]
        consumed = self.tlv_hdr_len + tlv_len
        return consumed

    def __repr__(self):
        out = super(tlv_aggie, self).__repr__()
#        out += "\nType %d = Value: %s" % (self['tlv_type'].val, self.tlv_value)
        return out

    '''
    update() - Add/Update an entry to the TLV blocks
       if tlv_type already exists we need to update if not, add it.
    '''
    def update(self, tlv_type, tlv_value):
        self['tlv_type'].val = tlv_type
        self['tlv_len'].val = len(tlv_value)
        self.tlv_value = tlv_value
        return self['tlv_len'].val + self.tlv_hdr_len # Add header T/L back in

    def build(self):
        out = ''
        for key, v_obj in self.iteritems():
            out += v_obj.build()
        out += "%s" % self.tlv_value
        return out


class tlv_block_aggie(aggie):
    '''
    tlv_block_aggie: aggregation node for multiple tlvs coming
    from one block of memory.

    takes two parameters:

        tlv_func:    function that generates a tlv object
        OrderedDict: the foundation on which to hang the tlvs.

    A tlv_block starts with are required object 'tlv_block_len'
    that defines a length parameter that is the size of the tlv
    block.  Any passed in buffer must be at least this size.

    The tlv_block_len object consumed in addition to the tlv_block
    itself.
    '''

    def __init__(self, a_dict):
        self.tlv_blocks = dict()
        self.max_block_len = 0
        self.cur_block_len = 0
        super(tlv_block_aggie, self).__init__(a_dict)


    def set(self, buf):
        consumed = super(tlv_block_aggie, self).set(buf)
        tlv_consumed = 0
        while True:
            tlv = tlv_aggie(aggie(OrderedDict([
                ('tlv_type', atom(('<B', '{}'))),
                ('tlv_len',  atom(('<B', '{}'))),
            ])))
            tlv_consumed += tlv.set(buf[consumed+tlv_consumed:])
            tlv_type = tlv['tlv_type'].val
            if tlv_type == 0:
               break;
            self.tlv_blocks[tlv_type] = tlv

        self.cur_block_len = tlv_consumed

        '''
        We at len-2 because we must keep that last 2 bytes as 0,0 to
        Terminate the list
        '''
        self.max_block_len = self['tlv_block_len'].val - 2
        consumed += self['tlv_block_len'].val
        return consumed

    def add_tlv(self, tlv_type, tlv_value):
        tlv_len = len(tlv_value)
        '''
        If we can't add this TLV without going over tlv_block_len. we fail
        '''
        if self.cur_block_len + tlv_len > self.max_block_len:
            return 0

        tlv = tlv_aggie(aggie(OrderedDict([
            ('tlv_type', atom(('<B', '{}'))),
            ('tlv_len',  atom(('<B', '{}'))),
        ])))
        consumed = tlv.update(tlv_type, tlv_value)
        if tlv_type in self.tlv_blocks:
            self.cur_block_len += (consumed - self.tlv_blocks[tlv_type]['tlv_len'].val)
            self.tlv_blocks[tlv_type] = tlv
        else:
            self.cur_block_len += consumed
            self.tlv_blocks.__setitem__(tlv_type, tlv)
        return consumed

    def get_tlv(self, tlv_type):
        tlv = self.tlv_blocks[tlv_type]
        return tlv.value

    def get_tlv_rows(self):
        return self.tlv_blocks.items()

    def build_tlv(self):
        out = ''
        for type, v_obj in self.tlv_blocks.items():
            out += v_obj.build()
        return out

    def __repr__(self):
        out = super(tlv_block_aggie, self).__repr__()
        for key, v_obj in self.tlv_blocks.items():
            out += v_obj.__repr__()
        return out

    def build(self):
        out = super(tlv_block_aggie, self).build()
        return out
