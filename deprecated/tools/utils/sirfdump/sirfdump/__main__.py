"""
sirfdump:  decode and display sirfbin messages
@author:   Eric B. Decker
"""

from sirfdump     import dump
from sirfdumpargs import parseargs

def main():
    dump(parseargs())

if __name__ == '__main__':
    main()
