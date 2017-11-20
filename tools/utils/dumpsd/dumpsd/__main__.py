print('dumpsd/__main__.py executed')

from dumpsd import dump
from dumpargs import parseargs

if __name__ == '__main__':
    dump(parseargs())
