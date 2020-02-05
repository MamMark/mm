#!/usr/bin/env python

DESCRIPTION = 'Utility to extract versioning information from Tag Utilities'

import os, re
def get_version():
    VERSIONFILE = os.path.join('tagvers', '__init__.py')
    initfile_lines = open(VERSIONFILE, 'rt').readlines()
    VSRE = r"^__version__ = ['\"]([^'\"]*)['\"]"
    for line in initfile_lines:
        mo = re.search(VSRE, line, re.M)
        if mo:
            return mo.group(1)
    raise RuntimeError('Unable to find version string in %s.' % (VERSIONFILE,))

try:
    from setuptools import setup
except ImportError:
    from distutils.core import setup

setup(
    name             = 'tagvers',
    version          = get_version(),
    url              = 'https://github.com/MamMark/mm/tools/utils/tagvers',
    author           = 'Eric B. Decker',
    author_email     = 'cire831@gmail.com',
#    license_file     = 'LICENCE.txt',
    license          = 'GPL3',
    packages         = [ 'tagvers' ],
    install_requires = [ ],
    entry_points     = {
        'console_scripts': ['tagvers=tagvers.tagvers:main'],
    }
)
