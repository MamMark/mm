from tagnet import tlv_types, TagTlv
import re

# s = eval('tlv_types.'+gs[0].upper()+'.value')

def nesc_fmt_TagnetDefines(args, _tree):
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

     def printable_tlv(tlv):
          rt = ''
          for a in tlv.build():
               rt += '\\' + oct(a) if (a) else '\\00'
          return rt

     def ThisNameTlv(node):
          if node.tag.startswith('<'):
               # r'<([a-zA-Z]+?):(.*)>' '<nid:000000>' => groups('nid','000000')
               exp=re.compile(r'<([a-zA-Z]+?):(.*)>')
               gs = exp.match(node.tag).groups()
               # extract values from pattern matched
               if (gs[0].upper() == 'NODEID'):
                    return printable_tlv(TagTlv(tlv_types.NODE_ID, gs[1]))
               else:
                    return None
          elif node.tag.isdigit():
               return printable_tlv(TagTlv(int(node.tag)))
          else:
               tlv = TagTlv(str(node.tag))
               return '\\' \
                    + oct(tlv_types.STRING.value) \
                    + '\\' \
                    + oct(len(node.tag)) \
                    + str(node.tag) \

     def ThisHelpTlv(node):
          # 1=int(tlv_types.STRING.value)
          help_str = 'help'
          return '\\' \
               + oct(int(tlv_types.STRING.value)) \
               + '\\' \
               + oct(len(help_str)) \
               + help_str

     def nodename(node):
          return int(node.identifier)

     # write out the NesC include file for enums and descriptor information
     #
     filename =  args.output+'/' if (args.output) else ''
     filename += "TagnetDefines.h"
     with open(filename, "w") as outfd:
          outfd.write('// THIS IS AN AUTO-GENERATED FILE, DO NOT EDIT\n\n')

          outfd.write("typedef enum {                   //      (parent) name\n")
          for node in sorted(_tree.all_nodes(), key=nodename):
               parent = _tree[node.bpointer].tag if (node.bpointer) else '_'
               outfd.write("  {:<20}  =  {:>4}, //  ({:^10}) {:}\n".format(
                    ThisElementID(node),
                    node.identifier,
                    parent,
                    node.tag)
               )
          outfd.write("  {:<20}  =  {:>4},\n".format(
               "TN_LAST_ID",
               _tree.size())
          )
          outfd.write("  {:<20}  =  {:>4},\n".format(
               "TN_ROOT_ID",
               0)
          )
          outfd.write("  {:<20}  =  {:>4},\n".format(
               "TN_MAX_ID",
               "65000")
          )
          outfd.write("} tn_ids_t;\n\n")

          for node in sorted(_tree.all_nodes(), key=nodename):
               parent = _tree[node.bpointer].tag if (node.bpointer) else '_'
               outfd.write("#define  {:<20}    \"{}\"\n".format(
                    ThisElementUQ(node),
                    ThisElementUQ(node))
               )
          outfd.write(
               ('#define UQ_TAGNET_ADAPTER_LIST  "UQ_TAGNET_ADAPTER_LIST"\n'
                '#define UQ_TN_ROOT               TN_0_UQ'
               )
          )
          outfd.write("\n")

          outfd.write(
               ('/* structure used to hold configuration values for each of the elements\n'
                '* in the tagnet named data tree\n'
                '*/\n'
                'typedef struct TN_data_t {\n'
                '  tn_ids_t    id;\n'
                '  char*       name_tlv;\n'
                '  char*       help_tlv;\n'
                '  char*       uq;\n'
                '} TN_data_t;\n\n'
               )
          )

          outfd.write("const TN_data_t tn_name_data_descriptors[TN_LAST_ID]={\n")
          for i in range(_tree.size()):
               node = _tree[str(i)]
               # TN_ID, name tlv, help tlv, UQ_ID
               outfd.write('  {{ {}, "{}", "{}", {} }},\n'.format(
                    ThisElementID(node),
                    ThisNameTlv(node),
                    ThisHelpTlv(node),
                    ThisElementUQ(node))
               )
          outfd.write("};\n\n")
