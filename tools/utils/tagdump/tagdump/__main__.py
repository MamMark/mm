"""
tagdump:  Pretty print the content of a Tag data logfile

@author: Dan Maltbie
"""
#print('tagdump/__main__.py executed')

from tagdump import dump
from tagdumpargs import parseargs

def main():
    dump(parseargs())

if __name__ == '__main__':
    main()
