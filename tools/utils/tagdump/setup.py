#!/usr/bin/env python

DESCRIPTION = 'Utility to extract and/or dump Tag Data in a readable format'

import os, re
def get_version():
    VERSIONFILE = os.path.join('tagdump', '__init__.py')
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
    name             = 'tagdump',
    version          = get_version(),
    url              = 'https://github.com/MamMark/mm/tools/utils/tagdump',
    author           = 'Dan Maltbie/Eric B. Decker',
    author_email     = 'dmaltbie@daloma.org',
#    license_file     = 'LICENCE.txt',
    license          = 'GPL3',
    packages         = ['tagdump'],
    install_requires = [ 'tagcore' ],
    entry_points     = {
        'console_scripts': ['tagdump=tagdump.__main__:main'],
    }
)
