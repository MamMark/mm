"""
ubxdump :  decode and display ubl0x binary messages
@author:   Eric B. Decker
"""

from ubxdump      import dump
from ubxdumpargs  import parseargs

def main():
    dump(parseargs())

if __name__ == '__main__':
    main()
