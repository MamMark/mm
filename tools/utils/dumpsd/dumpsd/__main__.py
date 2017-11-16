from dumpsd import dump
import argparse

print('dumpsd/__main__.py executed')
from __init__ import main

parser = argparse.ArgumentParser(
        description='Pretty print content of Tag Data logfile')
parser.add_argument('input',
                    type=argparse.FileType('rb'),
                    help='output file')
parser.add_argument('-V', '--version',
                    action='version',
                    version='%(prog)s 0.0.0')
parser.add_argument('-o', '--output',
                    type=argparse.FileType('w'),
                    help='this is an option')
parser.add_argument("--rtypes",
                    type=str,
                    help="output records matching types in list")
parser.add_argument("--start_sector",
                    type=int,
                    help="begin with START_SECTOR")
parser.add_argument("--end_sector",
                    type=int,
                    help="sector to stop with.")
parser.add_argument("--start_time",
                    type=int,
                    help="include records with datetime greater than START_TIME")
parser.add_argument("--end_time",
                    type=int,
                    help="stop with records after END_TIME")
parser.add_argument('-v', '--verbosity',
                    action='count',
                    default=0,
                    help="increase output verbosity")
args = parser.parse_args()
if args.rtypes:
    print(args.rtypes)
    for rtype_str in args.rtypes.split(' '):
        print(rtype_str)
        for dt_n, dt_val in dt_records.iteritems():
            print(dt_val)
            if (dt_val[2] == rtype_str):
                print(rtype_str)

main(args)
