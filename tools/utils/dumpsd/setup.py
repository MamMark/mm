DESCRIPTION = 'Dump the Tag Data logfile contents in readable format'

import os, re
def get_version():
    VERSIONFILE = os.path.join('dumpsd', '__init__.py')
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
    name             = 'dumpsd',
    version          = get_version(),
    url              = 'https://github.com/mammark/mm/tools/dumpsd',
    author           = 'Dan Maltbie',
    author_email     = 'dmaltbie@daloma.org',
    licence_file     = 'LICENCE.txt',
    licence          = 'MIT',
    install_requires = ['click',
    ],
    provides         = ['dumpsd'],
    packages         = ['dumpsd'],
)
