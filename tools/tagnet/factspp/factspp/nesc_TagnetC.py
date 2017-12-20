import os

#  Adapter Component
#  Interface Name
#  Interface Type
#  Interface Alternate
#  Direction
#  Tag Name

def nesc_fmt_TagnetC(args, _tree):
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
          fd.write("    {:22} {:<28}        as {:>10};\n".format(
               "components",
               "TagnetNameRootP",
               ThisModuleID(_tree[_tree.root]))
          )

     def WireRoot(fd):
          #  Tagnet              =  RootVx.Tagnet;
          fd.write("    {:15}  =  {:>10};\n".format(
               "Tagnet",
               ThisModuleID(_tree[_tree.root]))
          )

     def CompVertex(fd, node):
          #  components new TagnetNameElementP (TN_POLL_ID, UQ_TN_POLL) as PollVx;
          ids = '({},{})'.format(ThisElementID(node), ThisElementUQ(node))
          ids += ' ' * (20 - len(ids))
          fd.write("    {:15} {:>22} {}as {:>10};\n".format(
               "components new",
               "TagnetNameElementP",
               ids,
               ThisModuleID(node))
          )

     def WireVertex(fd, node):
          #  PollVx.Super  -> TagVx.Sub[unique(UQ_TN_TAG)];
          fd.write("    {:>10}.Super ->  {:>10}.Sub[unique({})];\n".format(
               ThisModuleID(node),
               ThisModuleID(_tree[node.bpointer]),
               ThisElementUQ(_tree[node.bpointer]))
          )

     def CompLeaf(fd, node):
          #  components new    TagnetNamePollP   (TN_POLL_EV_ID) as PollEvLf;
          fd.write("    {:15} {:>22} ({:^10})        as {:>10};\n".format(
               "components new",
               node.data["Adapter Component"],
               ThisElementID(node),
               ThisModuleID(node))
          )

     def WireLeaf(fd, node):
          #  PollEvLf.Super  -> PollNidVx.Sub[unique(UQ_TN_POLL_NID)];
          #  PollCount       =  PollEvLf.Adapter;
          fd.write("    {:>10}.Super ->  {:>10}.Sub[unique({})];\n".format(
               ThisModuleID(node),
               ThisModuleID(_tree[node.bpointer]),
               ThisElementUQ(_tree[node.bpointer]))
          )
          if (node.data["Interface Alternate"]):
               fd.write("    {:15}  =  {:>11}.Adapter;\n".format(
                    node.data["Interface Alternate"],
                    ThisModuleID(node))
               )

     def WriteInterfaces(fd, direction):
          for node in _tree.leaves():
               if (node.data['Interface Name']) and \
                  (node.data['Direction'] == direction):
                    if_type = '<' + node.data['Interface Type'] + '>' \
                              if (node.data['Interface Type']) \
                                 else ''
                    if_type = if_type + ' ' * (19-len(if_type)) + ' '
                    fd.write("    interface {:>25}{} as {};\n".format(
                         node.data['Interface Name'],
                         if_type,
                         node.data['Interface Alternate'])
                    )

     def WriteImplementation(fd):
          # write out all component instantiations of name objects
          def nodename(node):
               return int(node.identifier)
          for node in sorted(_tree.all_nodes(), key=nodename):
               if node.is_leaf():
                    CompLeaf(outfd, node)
               elif node.is_root():
                    CompRoot(outfd)
               else:
                    CompVertex(outfd, node)
          outfd.write('\n')
          # write out all wiring and interface descriptions
          for node in sorted(_tree.all_nodes(), key=nodename):
               if node.is_leaf():
                    WireLeaf(outfd, node)
               elif node.is_root():
                    WireRoot(outfd)
               else:
                    WireVertex(outfd, node)

     # write out the NesC component and wiring instructions
     #
     filename =  args.output+'/' if (args.output) else ''
     filename += "TagnetC.nc"
     templatename = os.path.dirname(os.path.abspath(__file__)) + '/'
     templatename += 'template_TagnetC.nc'
     print(filename, templatename)
     with open(filename, 'w') as outfd, \
          open(templatename, 'r') as tplate:
          # write out first part of the template file
          for line in tplate:
               if (line.startswith('# >>>> uses HERE')):
                    WriteInterfaces(outfd, 'uses')
               elif (line.startswith('# >>>> provides HERE')):
                    WriteInterfaces(outfd, 'provides')
               elif (line.startswith('# >>>> implementation HERE')):
                    WriteImplementation(outfd)
               else:
                    # write out template line
                    outfd.write(line)
