#!/usr/bin/env python2
#
# Copyright (c) 2017 Daniel J. Maltbie, Eric B. Decker
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the
#   distribution.
#
# - Neither the name of the copyright holders nor the names of
#   its contributors may be used to endorse or promote products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
#

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
