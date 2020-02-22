# Copyright (c) 2019 Eric B. Decker
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
# Contact: Eric B. Decker <cire831@gmail.com>

'''
Misc. Simple Sensor emitters.
'''

from   __future__   import print_function
from   collections  import OrderedDict

from   dt_defs      import DT_SNS_TMP_PX
from   sensor_defs  import *
import sensor_defs  as     sensor
from   mr_emitters  import mr_display

__version__ = '0.4.6'

def emit_default(level, offset, buf, obj):
    print()
    if (level >= 1):
        print('    {}'.format(obj))

##
# Tmp102 emitters
#
# Tmp_PX, platform and External combination sensor.
# We use the 12 bit format.  The low 4 bits are insignificant, and
# get shifted out by the /16.
#
def sns_str_tmp_px(obj, level = 0):
    s = ''
    sep = ''
    tmp_p = obj['tmp_p'].val
    tmp_x = obj['tmp_x'].val
    c_p = float(tmp_p)/16*0.0625
    c_x = float(tmp_x)/16*0.0625
    if level == 0:
        return '{:6.1f}C {:6.1f}C'.format(c_p, c_x)

    if level >= 2:
        s = '({:04x}) ({:04x})'.format(tmp_p, tmp_x)
        sep = ' '
    if level >= 1:
        f_p = c_p * 9/5 + 32
        f_x = c_x * 9/5 + 32
        s = s + sep + '{:6.1f}F {:6.1f}F'.format(f_p, f_x)
    return s


##
# mr_display dict for the tmp_px sensor.
# The keys denote column titles for the values stored on the keys.
#
def sns_dict_tmp_px(obj, level = 0):
    dt_sns_id = DT_SNS_TMP_PX
    r = OrderedDict()
    tmp_p = obj['tmp_p'].val
    tmp_x = obj['tmp_x'].val
    c_p = float(tmp_p)/16*0.0625
    c_x = float(tmp_x)/16*0.0625
    r['C_tmp_p'] = c_p
    r['C_tmp_x'] = c_x
    return r


def sns_str_acceln(obj, level = 0):
    s = ''
    sep = ''
    nsamples = obj['nsamples'].val
    datarate = obj['datarate'].val

    if level == 0:
        s = '  {:d} samples, {:d} Hz'.format(nsamples, datarate)
    return s


def print_sample(fmt, c, obj):
    print(fmt.format(c, obj[c]['x'], obj[c]['y'], obj[c]['z']),  end = '')


def emit_sample(fmt, obj):
    nsamples = obj['nsamples'].val
    datarate = obj['datarate'].val
    for n in range(0, nsamples, 3):
        c = n
        if c < nsamples:
            print_sample(fmt, c, obj)
        c += 1
        if c < nsamples:
            print_sample(fmt, c, obj)
        c += 1
        if c < nsamples:
            print_sample(fmt, c, obj)
        print('')


def emit_acceln(level, offset, buf, obj):
    fmt = '    {:>2d}: ({:04x}, {:04x}, {:04x})'
    emit_sample(fmt, obj)

def emit_acceln8(level, offset, buf, obj):
    fmt = '    {:>2d}: ({:2d}, {:2d}, {:2d})'
    emit_sample(fmt, obj)

def emit_acceln8x(level, offset, buf, obj):
    fmt = '    {:>2d}: ({:02x}, {:02x}, {:02x})'
    emit_sample(fmt, obj)


# machine readable sensor emitter
#
# sns_hdr is hdr/sns_hdr
# nsample_obj is nsample_hdr and samples
#
# Hang this function on the SNS_MR_EMITTER for the ACCELn sensor and
# set the DICT setting to None.

def emit_acceln_mr(offset, sns_hdr, nsample_obj):
    nsamples = nsample_obj['nsamples'].val
    datarate = nsample_obj['datarate'].val
    for n in range(nsamples):
        r = OrderedDict()
        dt_sns_id     = sns_hdr['hdr']['type'].val
        r['nsamples'] = nsamples
        r['datarate'] = datarate
        r['sample']  = n
        samples = nsample_obj[n]
        for k in samples.iterkeys():
            r[k] = samples[k]
            if n >= nsamples:
                break;
        mr_display(offset, sns_hdr, r);
