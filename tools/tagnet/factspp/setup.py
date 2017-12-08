DESCRIPTION = 'Tagnet Name Preprocessor'

import os, re
def get_version():
    VERSIONFILE = os.path.join('factspp', '__init__.py')
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
    name             = 'factspp',
    version          = get_version(),
    url              = 'https://github.com/mammark/mm/tools/tagnet/factspp',
    author           = 'Dan Maltbie',
    author_email     = 'dmaltbie@daloma.org',
    licence_file     = 'LICENCE.txt',
    licence          = 'MIT',
    install_requires = ['future',
                        'treelib',
                        'temporenc',
                        'enum34',
    ],
    provides         = ['factspp'],
    packages         = ['factspp'],
    package_data     = {
        'factspp.': ['template.*'],
        'factspp.': ['*.tsv'],
    },
    entry_points     = {
        'console_scripts': ['factspp=factspp.__main__:main'],
    },
)
