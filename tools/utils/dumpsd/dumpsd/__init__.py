"""
dumpsd:  Pretty print the content of a Tag data logfile

@author: Dan Maltbie
"""

from dumpsd import dump
#__all__ = (dumpsd.__all__, __main__.__main__)

print('dumpsd/__init__.py executed')
def main(args):
    print('main executed')
    dump(args)
