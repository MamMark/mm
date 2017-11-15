from __future__ import unicode_literals
import os
import csv
from treelib import Node, Tree
from binascii import hexlify
from tagtlv import tlv_types, TagTlv
import re

"""
root
+-- tag
    |-- info
    |   +-- <node_id:>
    |       +-- sens
    |           +-- gps
    |               +-- xyz
    |-- poll
    |   +-- <node_id:>
    |       |-- cnt
    |       +-- ev
    |-- sd
    |   +-- <node_id:>
    |       +-- 0
    |           |-- config
    |           |-- data
    |           |-- img
    |           |-- panic
    |           +-- rules
    +-- sys
        +-- <node_id:>
            |-- active
            |-- backup
            |-- golden
            |-- nib
            +-- running
"""


def OutputNesC(_tree):
     """
     Write output file containing all of the component instantiations
     and wirings. This file is then included in TagnetC.nc
     """
     def ThisElementID(node):
          return "TN_{}_ID".format(node.identifier)

     def ThisElementUQ(node):
          return "TN_{}_UQ".format(node.identifier)

     def ThisModuleID(node):
          return "tn_{}_Vx".format(node.identifier)

     def CompRoot(fd):
          #   components             TagnetNameRootP  as  RootVx;
          fd.write("  {:25} {:<28}  as {:>10};\n".format(
               "components",
               "TagnetNameRootP",
               ThisModuleID(_tree[_tree.root]))
          )

     def WireRoot(fd):
          #  Tagnet              =  RootVx.Tagnet;
          fd.write("  {:15}  =  {:>10};\n".format(
               "Tagnet",
               ThisModuleID(_tree[_tree.root]))
          )

     def CompVertex(fd, node):
          #  components new TagnetNameElementP (TN_POLL_ID, UQ_TN_POLL) as PollVx;
          fd.write("  {:15} {:>25} ({:^10})  as {:>10};\n".format(
               "components new",
               "TagnetNameElementP",
               ThisElementID(node),
               ThisModuleID(node))
          )

     def WireVertex(fd, node):
          #  PollVx.Super  -> TagVx.Sub[unique(UQ_TN_TAG)];
          fd.write("  {:>10}.Super ->  {:>10}.Sub[unique({})];\n".format(
               ThisModuleID(node),
               ThisModuleID(_tree[node.bpointer]),
               ThisElementUQ(_tree[node.bpointer]))
          )

     def CompLeaf(fd, node):
          #  components new    TagnetNamePollP   (TN_POLL_EV_ID) as PollEvLf;
          fd.write("  {:15} {:>25} ({:^10})  as {:>10};\n".format(
               "components new",
               node.data["Adapter Type"],
               ThisElementID(node),
               ThisModuleID(node))
          )

     def WireLeaf(fd, node):
          #  PollEvLf.Super  -> PollNidVx.Sub[unique(UQ_TN_POLL_NID)];
          #  PollCount       =  PollEvLf.Adapter;
          fd.write("  {:>10}.Super ->  {:>10}.Sub[unique({})];\n".format(
               ThisModuleID(node),
               ThisModuleID(_tree[node.bpointer]),
               ThisElementUQ(_tree[node.bpointer]))
          )
          fd.write("  {:15}  =  {:>11}.Adapter;\n".format(
               node.data["Interface"],
               ThisModuleID(node))
          )

     # write out the NesC component and wiring instructions
     #
     with open("TagnetWiring.h", "w") as outfd:
          for node in _tree.all_nodes():
               if node.is_leaf():
                    CompLeaf(outfd, node)
               elif node.is_root():
                    CompRoot(outfd)
               else:
                    CompVertex(outfd, node)
          for node in _tree.all_nodes():
               if node.is_leaf():
                    WireLeaf(outfd, node)
               elif node.is_root():
                    WireRoot(outfd)
               else:
                    WireVertex(outfd, node)

     # write out the NesC include file for enums and descriptor information
     #
     with open("TagnetDefines.h", "w") as outfd:
          outfd.write("typedef enum {                   //      (parent) name\n")
          for node in _tree.all_nodes():
               parent = _tree[node.bpointer].tag if (node.bpointer) else '_'
               outfd.write("  {:<20}  =  {:>4}, //  ({:^10}) {:<10}\n".format(
                    ThisElementID(node),
                    node.identifier,
                    parent, node.tag)
               )
          outfd.write("  {:<20}  =  {:>4},\n".format(
               "TN_LAST_ID",
               _tree.size()-1)
          )
          outfd.write("  {:<20}  =  {:>4},\n".format(
               "TN_MAX_ID",
               "65000")
          )
          outfd.write("} tn_ids_t;\n\n")

          for node in _tree.all_nodes():
               parent = _tree[node.bpointer].tag if (node.bpointer) else '_'
               outfd.write("#define  {:<20}    \"{}\"\n".format(
                    ThisElementUQ(node),
                    ThisElementUQ(node))
               )
          outfd.write("\n")

          outfd.write("const TN_data_t tn_name_data_descriptors[TN_LAST_ID]={\n")
          for i in range(_tree.size()):
               node = _tree[str(i)]
               # TN_ID, name tlv, help tlv, UQ_ID
               outfd.write('  {{ {}, "{}", "{}", {} }},\n'.format(
                    ThisElementID(node),
                    re.match("^bytearray\(b'(.*)'\)", # build tlv and ascii format
                            repr(TagTlv(str(node.tag)).build())).group(1),
                    re.match("^bytearray\(b'(.*)'\)", # build tlv and ascii format
                             repr(TagTlv(tlv_types.STRING, str("help")).build())).group(1),
                    ThisElementUQ(node))
               )
          outfd.write("};\n\n")



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
     with open(fn) as tsv:
          name_tree = Tree()
          first_line = True
          for line in csv.reader(tsv, dialect="excel-tab"):
               if (first_line):
                    first_line = False
                    column_names = line
                    idx = column_names.index("Name",0)
               else:
                    if (not line[0]):
                         vars = dict(zip(column_names[1:idx], line[1:idx]))
                         AddNodesFromName(name_tree, line[idx:], vars)
     return name_tree


def DisplayStuff(_tree):
     def nf(node):
          if (node.tag == name): return True
          return False

     print("leaves")
     for node in _tree.leaves():
          print(node)

     print("paths")
     paths = _tree.paths_to_leaves()
     for path in paths:
          print([_tree[n].tag for n in path])


if __name__ == '__main__':
     my_tree = BuildTree("TagNames.tsv")
     my_tree.show(line_type="ascii")
     DisplayStuff(my_tree)
     OutputNesC(my_tree)
     os.remove("Tree.txt")
     my_tree.save2file("Tree.txt",line_type="ascii")
