from __future__ import unicode_literals
import os
import csv
from treelib import Node, Tree
from binascii import hexlify
from tagnet import tlv_types, TagTlv
import re


def BuildTree(fn):
     """
     Build the internal tree structure from the input file.
     This tree represents all of the names combined into a
     single tree structure, with intermediate node being a level
     of the hierarchy and each leaf representing an adapter.
     """
     def NidGenerator():
          node_number = 0
          while True:
               node_number += 1
               yield "{}".format(node_number)

     def AddNodesFromName(_tree, lname, vdict):
          lastnode = _tree.root if (_tree.root) else \
                     _tree.create_node("root","0").identifier
          for _name in lname:
               if (not _name): break
               found = False
               for child in _tree.children(lastnode):
                    if (child.tag == _name):
                         found = True
                         break
               if found:
                    lastnode = child.identifier
               else:
                    lastnode = _tree.create_node(_name,
                                   GetNid.next(),
                                   parent=lastnode).identifier
          _tree[lastnode].data = vdict

     GetNid = NidGenerator()
     name_tree = Tree()
     first_line = True
     for line in csv.reader(fn, dialect="excel-tab"):
          if (first_line):
               first_line = False
               column_names = line
               idx = column_names.index("Tag Name",0)
          else:
               if (not line[0]):
                    vars = dict(zip(column_names[1:idx], line[1:idx]))
                    AddNodesFromName(name_tree, line[idx:], vars)
     return name_tree
