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


import os
import types

class TagFile(object):
    def __init__(self, input, direct=False):
        super( TagFile, self ).__init__()

        if not isinstance(input, types.FileType):
            raise IOError('not expected file type {}'.format(input))

        self.direct = direct
        self.fd     = input

        if (self.direct):
            self.name = input.name
            self.fd.close()
            self.fileno = os.open(self.name, os.O_DIRECT | os.O_RDONLY)

    def read(self, cnt):
        if (self.direct):
            return os.read(self.fileno, cnt)
        else:
            return self.fd.read(cnt)

    def tell(self):
        if (self.direct):
            return os.lseek(self.fileno, 0, 1)
        else:
            return self.fd.tell()

    def seek(self, pos, where=0):
        if (self.direct):
            return os.lseek(self.fileno, pos, where)
        else:
            return self.fd.seek(pos, where)
