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
from   collections import OrderedDict
from   misc_utils  import dump_buf

__version__ = '0.4.5rc0'

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

        if callable(self.f_str):
            return self.p_str.format(self.f_str(self.val))
        return self.p_str.format(self.val)

    def set(self, buf):
        '''
        set the atom.val to the unpack from the format string.

        return the number of bytes (size) consumed
        '''
        self.val = self.s_rec.unpack(buf[:self.s_rec.size])[0]
        return self.s_rec.size


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


class tlv_aggie(aggie):
    '''
    tlv_aggie: aggregation node for a tlv
    takes one parameter an ordered dictionary defining what the
    tlv header looks like (key -> {atom | aggie})

    tlv_aggie will first create just the header, then using header
    via set will populate the data key.
    '''
    def __init__(self, a_dict):
        super(aggie, self).__init__(a_dict)

    def set(self, buf):
        '''
        This needs to be fleshed out.  Current this does the same
        thing as aggie.
        '''
        consumed = super(aggie, self).set(buf)
        return consumed


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
    def __init__(self, obj_tlv_func, a_dict):
        super(tlv_block_aggie, self).__init__(a_dict)
        self.tlv_func = obj_tlv_func

    def set(self, buf):
        '''
        This needs to be fleshed out.  Current this does the same
        thing as aggie.
        '''
        consumed = super(tlv_block_aggie, self).set(buf)
        block_len = self['tlv_block_len'].val
        consumed += block_len
        return consumed
