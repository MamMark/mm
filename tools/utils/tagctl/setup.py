#!/usr/bin/env python

import os, re
from setuptools import setup, find_packages

DESCRIPTION = 'utility to control/interact with remote tags'

try:
    long_description = open('README.md', 'rt').read()
except IOError:
    long_description = ''

def get_version():
    VERSIONFILE = os.path.join('tagctl', '__init__.py')
    initfile_lines = open(VERSIONFILE, 'rt').readlines()
    VSRE = r"^__version__ = ['\"]([^'\"]*)['\"]"
    for line in initfile_lines:
        mo = re.search(VSRE, line, re.M)
        if mo:
            return mo.group(1)
    raise RuntimeError('version string not found in %s' % VERSIONFILE)

setup(
    name             = 'tagctl',
    version          = get_version(),

    description      = DESCRIPTION,
    long_description = long_description,

    url              = 'https://github.com/MamMark/mm/tools/utils/tagctl',
    author           = 'Eric B. Decker',
    author_email     = 'cire831@gmail.com',
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

    scripts              = [],

    provides             = [],
    install_requires     = [ 'cliff', 'tagcore' ],

    namespace_packages   = [],
#   packages             = [ 'tagctl' ],
    packages             = find_packages(),
    include_package_data = True,

    entry_points         = {
        'console_scripts' : [
            'tagctl = tagctl.__main__:main'
        ],
        'ctl_main': [
            'cmd  = tagctl.tagctl:Cmd',
            'send = tagctl.tagctl:Send',
            'can  = tagctl.tagctl:Can',
        ],
    },
    zip_safe             = False,
)
