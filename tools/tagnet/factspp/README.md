FACTSPP
========

Dan Maltbie <dmaltbie@daloma.org>
copyright @ 2017 Dan Maltbie

*License*: [MIT](http://www.opensource.org/licenses/mit-license.php)

The Facts Preprocessor (factspp) translates input file containing TagNet FactSpace into NESC source code. It takes as input the Tagnet Names representing all facts in the Tag (in TSV record format). The Preprocessor outputs the wiring and definitions used by the Tag TinyOS program.

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
    |           +-- img
    +-- sys
        +-- <node_id:>
            |-- active
            |-- backup
            |-- golden
            |-- nib
            +-- running

# INPUT
Input file
- Represents the complete FactSpace for a given Tag software version
- Consists of a list of CSV records, one for each Fact
- A Fact is described by its TagNet Name and associated properties

Example of a TagNet Fact Record Descriptor
- consisting of: adapter name, interface type, interface name, and list of name_segments:
```
TagnetGpsXyzAdapterP,tagnet_gps_xyz_t,InfoSensGpsXyz,<node_id:>,"tag","info",<node_id:>,"sens","gps","xyz"
```
# OUTPUT
- Consists of these NESC files for instantiating all elements and wiring in the TagNet Fact Tree
  - TagnetC.nc
    - includes TagnetWiring.h
  - TagnetDefines.h
    - included by tagnet.h
  - tagnetnames.h
    - included by Rules Engine

## TagnetC.nc
#### New element instantiation parameters
The TagNet Factspace is represented in NESC code as a set of components
wired together in a tree where the root is the firt element in the TagNet
name and each subordinate component is the next element in the name. The
last element in the name is special, and is referred to as an adapter.
The adapter is responsible for handling the conversations from Tag native
data interfaces to the network representation. Other than the root and
the specialized adapters, every other element of a name in the tree is instantiated as a TagnetNameElement component.

Below is an example of the instantiation of one intermediate element of
the gps/xyz Fact name.
```
components new  TagnetNameElementP  (TN_INFO_ID, UQ_TN_INFO) as InfoVx;
```
  - TN_*_ID
    - enum value for this element among all elements
  - UQ_TN_*
    - string for referencing NESC unique number
  - Component names that are usable elements
    - TagnetNameElementP
    - TagnetNamePollP
    - TagnetGpsXyzAdapterP
    - TagnetImageAdapterP
    - TagnetSysExecAdapterP
    - TagnetNameRootP
#### Wiring
  - per tagnet name element
    - connect interface user to provider
    - for adapters, optionally assign public name
```
InfoVx.Super        -> TagVx.Sub[unique(UQ_TN_TAG)];
InfoSensGpsXyz      =  InfoSensGpsXyzLf.Adapter;
```
#### Adapter Example
This adapter example shows the typical definition for describing how
the Tagnet network stack connects to the Tag embedded variable. A Tagnet
name refers to this variable
name to get/put its value. The variable type is defined by the interface
type (the <tagnet_gps_xyz_t> name below).
The interface name is included in the components 'uses' section.
```
uses { interface TagnetAdapter<tagnet_gps_xyz_t>  as InfoSensGpsXyz; }
implementation {
```
#### Constant Code in TagnetC.nc
This code is always included in output.
```
components TagnetUtilsC;
TagnetName = TagnetUtilsC;
TagnetPayload = TagnetUtilsC;
TagnetTLV = TagnetUtilsC;
TagnetHeader = TagnetUtilsC;
// instantiate root of Name tree, provides the TagNet API
components             TagnetNameRootP  as  RootVx;
Tagnet              =  RootVx.Tagnet;
components new         TagnetNameElementP   (TN_TAG_ID, UQ_TN_TAG) as TagVx;
TagVx.Super         -> RootVx.Sub[unique(UQ_TN_ROOT)];
```
## tagnetname.h
#### UQ_TN_*
- string identifiers for generating unique NESC values
                    `#define UQ_TN_ROOT              "UQ_TN_ROOT"`
#### TN_name_data_descriptors
- table containing details used by runtime code to process tagnet names
  - each row consists of TN_data_t type
  - indexed by tn_ids_t enum
- tn_ids_t
  - enum value for every node in the tagnet name tree
  - up to 65000
- TN_data_t
  - struct def used for defining rows in the tn_name_data_descriptors table
```
  typedef struct {
     tn_ids_t    id;
     char*       name_tlv;
     char*       help_tlv;
     char*       uq;
  } TN_data_t;
```

## PREPROCESSOR STEPS
- Read input file and build tree of



## Rules Engine
- NESC files for instantiating and wiring Rules Engine with access to all TagNet named Facts
  - tbd

## gperf file
 - structs
 - tagnames as keywords
 - default code

# Changes to previous version
- TagnetC.h and tagnet.h are now auto-generated files
- added new auto-generated file tagnetnames.h

/**
 * This component provides the main configuration for the Tagnet
 * protocol stack.
 *<p>
 * The Tagnet protocol stack provides the network oriented access
 * to Tag local device information. This information consists of
 * variables exposed by the underlying software and hardware.
 * For instance sensors provide readings and may have settings
 * that can be configured.
 *</p>
 *<p>
 * In Tagnet, each variable in the Tag device is represented by
 * a unique name. A Tagnet name is similar to a Unix file path in
 * that it is constructed from a list of elements (sub-directories)
 * that together identify a specific item in the system. For Tagnet,
 * the name identifies a variable of a specific type (e.g, integer,
 * string, file). The collection of Tagnet names represents all of
 * the externally accessible variables and functions provided by
 * this node using the Tagnet protocol.
 * All of the possible names are defined in a directed acyclical
 * graph, or tree, where each node in the graph represents an
 * element of a name. The terminal element of the name is connected
 * to an individual variable in the system. The stack provides the
 * means to traverse a name in a given message through the tree and
 * perform the requested operation on that element when a match
 * is found.
 *</p>
 *<p>
 * The Tagnet protocol defines different message types for operating
 * on the Tag device named variables, including reading and writing
 * the variable as well as retrieving metadata associated with the
 * variable.
 *</p>
 *<p>
 * Processing a message request consists of traversing the elements
 * of the name in the message according to the nodes of the tree
 * until reaching the terminus of the name. The terminus can refer
 * to any intermediate element in the tree or else the leaf node. In
 * the case of intermediate nodes, the request operates like a
 * reference to a sub-directory in a file path, whereas a match
 * to a leaf node provides access to the contents of the system
 * variable of the specified type. Once the terminus node is matched,
 * the operation defined by the message is performed on the object
 * and an optional result is returned in a response message.
 *</p>
 *<p>
 *</p>
 * The Tagnet stack is defined in a collection of interfaces and
 * components that operate on Tagnet messages to perform network
 * initiated operations on local system variables. Below is listed
 * the files associated with the stack.
 *<p>
 * interfaces:
 *</p>
 *<dl>
 *   <dt>Tagnet</dt> <dd>primary user methods for accessing the Tagnet stack</dd>
 *   <dt>TagnetMessage</dt> <dd>methods used to travers the name tree</dd>
 *   <dt>TagnetHeader</dt> <dd>methods for accessing a Tagnet message header</dd>
 *   <dt>TagnetName</dt> <dd>methods for acessing and evaluating a Tagnet message name</dd>
 *   <dt>TagnetPayload</dt> <dd>methods for accessing a Tagnet message payload</dd>
 *   <dt>TagnetTLV</dt> <dd>methods for parsing and building Tagnet TLVs</dd>
 *</dl>
 *<p>
 * Components:
 *</p>
 *<dl>
 *   <dt>TagnetUtilsC</dt> <dd>configuration with functions to access Tagnet messages</dd>
 *   <dt>TagnetNameElementP</dt> <dd>generic module handles intermediate elements of a name</dd>
 *   <dt>TagnetNameRootP</dt> <dd>module handles the name root starting point</dd>
 *   <dt>TagnetNamePollP</dt> <dd>generic module processes Tagnet poll request (special)</dd>
 *   <dt>TagnetIntegerAdapterP</dt> <dd>generic module for adapting local integer variable to the network TLV</dd>
 *<dl>
 *
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 * Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 */
