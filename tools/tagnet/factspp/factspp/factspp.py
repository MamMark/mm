from __future__ import unicode_literals
import os
import csv
from treelib import Node, Tree
from binascii import hexlify
from tagnet import tlv_types, TagTlv
import re

"""
factsapp -  main module for the Facts Preprocessor

Top level module performs the input processing, formating,
outputing, and displaying operations.
"""

from nesc_TagnetC import nesc_fmt_TagnetC
from nesc_TagnetDefines import nesc_fmt_TagnetDefines
from BuildTree import BuildTree

def OutputNesC(args, _tree):
    """
    output to files all NESC code generated from
    the name tree
    """
    nesc_fmt_TagnetC(args, _tree)
    nesc_fmt_TagnetDefines(args, _tree)
#    TagnetNamesh_mft(args, _tree)

def DisplayStuff(args, _tree):
    """
    display the input in tree format, followed
    by details of individual tree nodes and
    full paths of all named objects
    """
    print('display tree')
    _tree.show(line_type="ascii")

#    print("leaves")
#    for node in _tree.leaves():
#        print(node)

#    print("paths")
#    paths = _tree.paths_to_leaves()
#    for path in paths:
#        print([_tree[n].tag for n in path])

def SaveStuff(args, _tree):
    """
    save artifacts from processing, including the
    name tree in text format.
    """
    filename =  args.output+'/' if (args.output) else ''
    filename += "TagNameTree.txt"
    try:
        os.remove(filename)
    except:
        pass
    _tree.save2file(filename,line_type="ascii")

def preprocessor(args):
    """
    main entry point, performs all operations as specuified in 'args'
    to construct a name tree and output NESC compiler files
    """
    my_tree = BuildTree(args.input)
    DisplayStuff(args, my_tree)
    OutputNesC(args, my_tree)
    SaveStuff(args, my_tree)
