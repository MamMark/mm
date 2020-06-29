'''configuration for tagdump'''

from   __future__         import print_function

import sys
import importlib
import tagcore.globals as g

pop = 'core_populate' if g.gps_level   is None else 'core_populate_ge'
pop = 'mr_populate'   if g.mr_emitters is True else  pop
pop = 'tagcore.' + pop

# import populators for core, sensor, and sirf decode/emitters
try:
    importlib.import_module(pop)
except ImportError:
    print()
    print('*** could not find populator: {}'.format(pop))
    print()
    raise

import tagcore.sensor_populate
import tagcore.ubx_populate
