#!/usr/bin/env python

DESCRIPTION = 'Utility to update tinyos META data'

import os, re
def get_version():
    VERSIONFILE = os.path.join('binfin', '__init__.py')
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
    name             = 'binfin',
    version          = get_version(),
    url              = 'https://github.com/MamMark/mm/tools/utils/binfin',
    author           = 'Dan Maltbie/Eric B. Decker/R. Li Fo Sjoe',
    author_email     = 'flyrlfs@gmail.com',
#    license_file     = 'LICENCE.txt',
    license          = 'GPL3',
    packages         = ['binfin'],
    install_requires = [ 'tagcore' ],
    entry_points     = {
        'console_scripts': ['binfin=binfin.__main__:main'],
    }
)
