#!/usr/bin/env python

import os, re
from setuptools import setup, find_packages

DESCRIPTION = 'Core Tag access library.'

try:
    long_description = open('README.md', 'rt').read()
except IOError:
    long_description = ''

def get_version():
    VERSIONFILE = os.path.join('tagcore', '__init__.py')
    initfile_lines = open(VERSIONFILE, 'rt').readlines()
    VSRE = r"^__version__ = ['\"]([^'\"]*)['\"]"
    for line in initfile_lines:
        mo = re.search(VSRE, line, re.M)
        if mo:
            return mo.group(1)
    raise RuntimeError('version string not found in %s' % VERSIONFILE)

setup(
    name             = 'tagcore',
    version          = get_version(),

    description      = DESCRIPTION,
    long_description = long_description,

    url              = 'https://github.com/MamMark/mm/tools/utils/tagcore',
    author           = 'Eric B. Decker',
    author_email     = 'cire831@gmail.com',
#   license_file     = 'LICENSE.txt',
#   license          = 'LICENSE.txt',
    license          = 'GPL3',

    classifiers = [
        'Development Status      :: 2 - Pre-Alpha',
        'License :: OSI Approved :: GNU General Public License v3 (GPLv3)'
        'Programming Language    :: Python',
        'Programming Language    :: Python :: 2',
        'Programming Language    :: Python :: 2.7',
#       'Programming Language    :: Python :: 3',
#       'Programming Language    :: Python :: 3.2',
        'Intended Audience       :: Developers',
        'Environment             :: Console',
    ],

    platforms            = [ 'Any' ],

    install_requires = [],
    scripts          = [],
    provides         = ['tagcore'],
    packages         = ['tagcore'],
    keywords         = ['tagcore', 'tagdump', 'sirfdump', 'tagctl'],
)
