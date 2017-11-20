from dumpsd import dump
import argparse

print('dumpsd/__main__.py executed')
from __init__ import main

parser = argparse.ArgumentParser(
        description='Pretty print content of Tag Data logfile')
parser.add_argument('input',
                    type=argparse.FileType('rb'),
                    help='input file')
parser.add_argument('-V', '--version',
                    action='version',
                    version='%(prog)s 0.0.0')
parser.add_argument('--rtypes',
                    type=str,
                    help='output records matching types in list')
parser.add_argument('-f', '--first_sector',
                    type=int,
                    help='begin with START_SECTOR')
parser.add_argument('-l', '--last_sector',
                    type=int,
                    help='sector to stop with.')
parser.add_argument('-j', '--jump',
                    type=int,
                    help='set input file position')
# not working yet
parser.add_argument('-s', '--start_time',
                    type=int,
                    help='include records with datetime greater than START_TIME')
# not working yet
parser.add_argument('-e', '--end_time',
                    type=int,
                    help='stop with records after END_TIME')
# 0v print record details, suppress recoverable errors
# v  also print the record header and all errors
# vv also print the record buffer
parser.add_argument('-v', '--verbosity',
                    action='count',
                    default=1,
                    help='increase output verbosity')

args = parser.parse_args()
main(args)
