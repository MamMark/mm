"""
tagdump:  decode and display Tag Data Stream file
@author: Dan Maltbie/Eric B. Decker
"""

from tagdump import dump
from tagdumpargs import parseargs

def main():
    dump(parseargs())

if __name__ == '__main__':
    main()
