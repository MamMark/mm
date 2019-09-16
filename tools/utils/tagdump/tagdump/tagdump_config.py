'''configuration for tagdump'''

from   __future__         import print_function

import sys
import importlib
from tagcore.globals import gps_level

pop = 'core_populate' if gps_level is None else 'core_populate_ge'
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
import tagcore.sirf_populate
