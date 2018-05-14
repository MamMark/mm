# Tagnet Protocol Stack

A network protocol for micro-powered, constraint-based mobile
devices to collect location and sensor data using named data
objects over ad hoc radio networks.

## Copyright

Copyright (c) 2017, 2018 Daniel J. Maltbie
All rights reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
See COPYING in the top level directory of this source tree.

@author Daniel J. Maltbie <dmaltbie@daloma.org>


## Introduction

 This component provides the main configuration for the Tagnet
 protocol stack.
<p>
 The Tagnet protocol stack provides the network oriented access
 to Tag local device information. This information consists of
 variables exposed by the underlying software and hardware.
 For instance sensors provide readings and may have settings
 that can be configured.
</p>
<p>
 In Tagnet, each variable in the Tag device is represented by
 a unique name. A Tagnet name is similar to a Unix file path in
 that it is constructed from a list of elements (sub-directories)
 that together identify a specific item in the system. For Tagnet,
 the name identifies a variable of a specific type (e.g, integer,
 string, file). The collection of Tagnet names represents all of
 the externally accessible variables and functions provided by
 this node using the Tagnet protocol.
 All of the possible names are defined in a directed acyclical
 graph, or tree, where each node in the graph represents an
 element of a name. The terminal element of the name is connected
 to an individual variable in the system. The stack provides the
 means to traverse a name in a given message through the tree and
 perform the requested operation on that element when a match
 is found.
</p>
<p>
 The Tagnet protocol defines different message types for operating
 on the Tag device named variables, including reading and writing
 the variable as well as retrieving metadata associated with the
 variable.
</p>
<p>
 Processing a message request consists of traversing the elements
 of the name in the message according to the nodes of the tree
 until reaching the terminus of the name. The terminus can refer
 to any intermediate element in the tree or else the leaf node. In
 the case of intermediate nodes, the request operates like a
 reference to a sub-directory in a file path, whereas a match
 to a leaf node provides access to the contents of the system
 variable of the specified type. Once the terminus node is matched,
 the operation defined by the message is performed on the object
 and an optional result is returned in a response message.
</p>
<p>
</p>
 The Tagnet stack is defined in a collection of interfaces and
 components that operate on Tagnet messages to perform network
 initiated operations on local system variables.
<p>
 interfaces:
</p>
<dl>
   <dt>Tagnet</dt> <dd>primary user methods for accessing the Tagnet stack</dd>
   <dt>TagnetMessage</dt> <dd>methods used to travers the name tree</dd>
   <dt>TagnetHeader</dt> <dd>methods for accessing a Tagnet message header</dd>
   <dt>TagnetName</dt> <dd>methods for acessing and evaluating a Tagnet message name</dd>
   <dt>TagnetPayload</dt> <dd>methods for accessing a Tagnet message payload</dd>
   <dt>TagnetTLV</dt> <dd>methods for parsing and building Tagnet TLVs</dd>
</dl>
<p>
 Components:
</p>
<dl>
   <dt>TagnetUtilsC</dt> <dd>configuration with functions to access Tagnet messages</dd>
   <dt>TagnetNameElementP</dt> <dd>generic module handles intermediate elements of a name</dd>
   <dt>TagnetNameRootP</dt> <dd>module handles the name root starting point</dd>
   <dt>TagnetNamePollP</dt> <dd>generic module processes Tagnet poll request (special)</dd>
   <dt>TagnetIntegerAdapterP</dt> <dd>generic module for adapting local integer variable to the network TLV</dd>
<dl>


## Tagnet Implementation Files

The following lists the various files that make up the Tagnet stack
implementation. From the system standpoint, all user interfaces are
exposed through the TagnetC configuration component. The other
configurations simplify wiring for the network stack building block
modules and utility functions.

  * Configurations (6):
     * TagnetC
     * TagnetNameRootP
     * TagnetNameElementP
     * TagnetNamePollP
     * TagnetNameIntegerP
     * TagnetUtilsC

  * Interfaces (7):
     * Tagnet
     * TagnetMessage
     * TagnetName
     * TagnetHeader
     * TagnetPayload
     * TagnetTLV
     * TagnetAdapter

  * Modules (8):
     * TagnetNameP
     * TagnetHeaderP
     * TagnetPayloadP
     * TagnetTlvP
     * TagnetNameElementImplP
     * TagnetNameRootImplP
     * TagnetNamePollImplP
     * TagnetNameIntegerImplP

  * Includes (2):
     * Tagnet.h
     * TagnetTLV.h

## Implementation Model

The implementation model for the Tagnet Stack utilizes nesC generic components and hierarchical wiring of parameterized interfaces to construct the search tree for matching network names and wiring to the associated action. This makes it easy to modify and extend the object names through simple changes to module instantiation and wiring, which is all found in TagnetC.nc. The Tagnet Stack diagram below illustrates the Tagnet stack implementation model for a simple configuration that exposes just three named data objects.

1. /tag/poll/NID/ev
2. /tag/poll/NID/cnt
3. /tag/info/NID/sens/gps/pos

The first two objects are somewhat special in that the Tagnet POLL message has some special handling requirements. The third name, on the other hand, shows a typical example of how the stack translates from a network name to a specific variable exposed by the appropriate module (in this case the GPS module). The '/tag/poll/NID/ev' object is a function-based object that handles the special poll request requirements and is implemented inside of the stack. The '/tag/poll/NID/cnt' object provides an integer variable that reflects the count of the number of times this device has received a poll request message. The '/tag/info/NID/sens/gps/pos' object refers to a gps position type variable and contains the last read GPS location fix.

The stack is implemented by constructing a tree with each node representing one element of the object name. This is done pre-compile time by instantiating modules and wiring them together to create the tree containing all exposed variables in the system (in this case, there are just three).

The root of the Tagnet stack is exposed through the *Tagnet* interface. The root module will insure that the stack is properly initialized for processing a new request message and will verify that a response is required upon return. A TagnetNameElementP is a generic module instantiated for each unique element at each level of the name. This module is responsible for matching it's element to the name in the request, and continuing down the tree if it matches. Once all elements in the request name have been matched, successfully, the terminal element module will perform the requested action.

For leaf nodes this typically involves an adapter module that know how to convert a C Type into a Tagnet TLV. If the match completes at an intermediate element, the action will behave more like a directory entry. For instance, a GET on '/tag/poll/NID' would get the name and value for each of its sub-elements. In this case, four TLVs are returned [(name:ev, value:35)(name:ev, value:POLL_RSP)]. Each intermediate node will sequentially call its subordinate elements to see if any of them match. When a match is found, the result is returned. If matching fails at any point or all choices are exhausted, nothing is returned.

![Tagnet Stack](TagnetC-pict.png "Overall Code Model for Tagnet Stack")

In addition to interface for accessing the name tree, there are a set of utility interfaces available for operating on Tagnet messages. Typically user applications don't need to use these. They provide the following capabilties to access the various fields of a Tagnet message (header, name, and payload) as well as for manipulating Tagnet TLVs.

![Tagnet Utilities](TagnetUtilsC-pict.png "Tagnet Utilities")

## Protocol Features
  - Named Data Objects
    - A name is an arbitrary string consisting of distinct substrings to represent hierarchical structures
      - substrings are typed
    - Nodes in the network use names to specify access of information structured in a key/value store
    - Names allow arbitrary depth and breadth of information hierarchy
    - Names can refer to static information (e.g, serial number) or dynamic content (current GPS location)
    - separation of name (index) and data
      - A named data object allows the network to separate the identification of the content from the contents itself
      - index can be copied separately from data
        - allows caching of index at user for fast lookup
      - the index provides the hierarchical address for a unit of data
      - support untrusted storage service by encrypting data prior to storing it
        - index is separately readable
      - Objects can be cached in the network, allowing intermediate storage to be used with the potential for multiple identical copies providing network efficiency and data resiliency
  - Get/Put Operations
    - information hierarchy is accessed with put and get commands
    - get on intermediate node in hierarchy returns a list of its sub nodes
  - Object Store
    - each blob has a unique name
    - the name consists of a hierarchical list of sub names
    - subnames can be ascii strings or they can be predefined types
    - pre-defined types support protocol features
      - block and byte indexing
      - error codes
  - Schema
    - The schema provides three distinct uses:
      - Data Structure Definition
        - Documentation and validation
      - Persistent Storage Attributes
        -  Information pertinent to persisting data
      - Interaction Control
        - Hints on how to render UI where data can be manipulated
    - the flexibility in uses reduces the level of complexity in maintenance while enabling several important features:
      - Naming individual resources and attributes of Control Plane resources using TagNet content names
      - A tree naming system for creating collection and resource hierarchies
      - Each resource can maintain a base set of attributes as well as can be decorated with additional runtime or user-specific attributes
      - Bundled documentation that is run-time accessible
      - Add, modify, remove resources or update attributes at any node of the network (with proper security keys)
        - As little as one attribute, as many as all resources, and everything in between
    - provide constraints on the data (e.g. data types, required properties, minimum lengths), which can be used to provide a default editing interface.
    - can reference/link to other schemas, and specify complex behaviours - for example, conditional schemas that only apply if a particular property is present, or lists of sub-schemas of which only one may apply. However, each schema has a unique URI, so they are perfect for selecting custom renderers.
  - segmentation
    - blob is the basic unit of transfer and retrieval
    - contiguous sequence of blobs in a resource
    - typically a single blob can fit into a message
      - if not, then byte indexing can be used to retrieve portions
      - not a good idea to have over-size blobs
    - optional append-only blob writes to resources
      - ensures data is immutable
    - blobs can be signed and encrypted
    - blobs can be stored at different (even multiple) locations

## Tagnet Protocol BNF Description
```
frame          =  frame_length
                  + response_flag[7:1] + version[4:3] payload_type[0:1]
                  + message_type[5:3] + options[0:5]
                  + name_length
                  + packet
frame_length   =  6..255
response_flag  =  Enum( 'REQUEST'=0, 'RESPONSE'=1 )
version        =  1
payload_type   =  Enum( 'RAW'=0 | 'TLV_LIST'=1 )
message_type   =  Enum( 'POLL'=0 | 'BEACON'=1 | 'HEAD'=2
                       | 'PUT'=3 | 'GET'=4 | 'DELETE'=5 | 'OPTION'=6  )
options        =  [error_code if (frame.response_flag) else hop_count]
name_length    =  2..251

packet         =  poll | beacon | put | get | delete | head | options
name           =  tlv | tlv + name
*(rsp)         =  (frame.response_flag set to TRUE)

poll           =  name('tag' + 'poll' + tlv_node_id(my_mac()) + 'ev')
                  + payload(tlv_time(now())
                            + tlv_integer(SLOT_TIME)   // milliseconds
                            + tlv_integer(SLOT_COUNT))
poll(rsp)      =  poll.name
                  + payload(tlv_node_id(my_mac())
                            + tlv_node_name(hostname())
                            + tlv_time(now()))
head           =  name
head(rsp)      =  head.name + payload
beacon         =  name('tag' + 'beacon' + tlv_node_id(my_mac()) + 'id')
                  + payload(tlv_list(list of tagnet_tlv_t tuples))
beacon(rsp)    =  beacon.name
                  + payload(tlv_list(list of tagnet_tlv_t tuples))
put            =  name + payload
put(rsp)       =  put.name
get            =  name [+ payload]
get(rsp)       =  get.name + payload
delete         =  name
delete(rsp)    =  delete.name
option         =  name + payload
option(rsp)    =  option.name + payload

payload        =  raw_bytes | tlv_list
raw_bytes      =  BYTE[frame_length - name_length]

hop_count      =  1..31
error_code     =  Enum( 'OK'=0 | 'NO_ROUTE'=1 | 'TOO_MANY_HOPS'=2
                  | 'MTU_EXCEEDED'=3 | 'UNSUPPORTED'=4
                  | 'BAD_MESSAGE'=5 | 'FAILED'=6 | 'NO_MATCH'=7 )

tlv_list       =  tlv | tlv + tlv_list
tlv            =  tlv_type + tlv_length + tlv_value
tlv_type       =  Enum( 'NONE'=0, 'STRING'=1 | 'INTEGER'=2 | 'GPS_XYZ=3
                  | 'UTC_TIME'=4 | 'NODE_ID'=5 | 'NODE_NAME'=6
                  | 'SEQ_NO'=7, 'VER_NO'=8 | 'FILE'=9 | '_COUNT'=10 )
tlv_length     =  0..254
tlv_value      =  is one of the following based on tlv_type
  tlv_string   =  BYTE[tlv_length]
  tlv_integer  =  BYTE[tlv_length]   // scales 1..n(value)

# potential conflict here....   rtctime_t is defined as
#                little endian  JJJJ.SS:MM:HH:DOW:DD:MM:YYYY

  tlv_rtctime  =  BYTE[10]           // encoded [YYYY-MM-DD HH:MM:SS.JJJJ.DOW]
  tlv_node_id  =  BYTE[6]
  tlv_node_name=  tlv_string
  tlv_tlv      =  tlv_list
  tlv_offset   =  tlv_integer
  tlv_count    =  tlv_integer
```

## Current Tag Network Name Tree

![Tagnet Name Tree](Tree.txt "Tagnet Name Tree")

# Facts Pre-Processor

The Facts Preprocessor (factspp) translates input file containing
TagNet FactSpace into NESC source code. It takes as input the
Tagnet Names representing all facts in the Tag (in TSV record
format). The Preprocessor outputs the wiring and definitions used
by the Tag TinyOS program.

## Naming Overview

The Tagnet protocol stack provides the network oriented access
to Tag local device information. This information consists of
variables exposed by the underlying software and hardware.
For instance sensors provide readings and may have settings
that can be configured.

In Tagnet, each variable in the Tag device is represented by
a unique name. A Tagnet name is similar to a Unix file path in
that it is constructed from a list of elements (sub-directories)
that together identify a specific item in the system. For Tagnet,
the name identifies a variable of a specific type (e.g, integer,
string, file). The collection of Tagnet names represents all of
the externally accessible variables and functions provided by
this node using the Tagnet protocol.

All of the possible names are defined in a directed acyclical
graph, or tree, where each node in the graph represents an
element of a name. The terminal element of the name is connected
to an individual variable in the system. The stack provides the
means to traverse a name in a given message through the tree and
perform the requested operation on that element when a match
is found.


```
root
+-- tag
    |-- .test
    |   |-- drop
    |   |   +-- byte
    |   |-- echo
    |   |   +-- byte
    |   |-- ones
    |   |   +-- byte
    |   |-- rssi
    |   |-- tx_pwr
    |   +-- zero
    |       +-- byte
    |-- info
    |   +-- sens
    |       +-- gps
    |           |-- cmd
    |           +-- xyz
    |-- poll
    |   |-- cnt
    |   +-- ev
    |-- sd
    |   +-- 0
    |       |-- dblk
    |       |   |-- .committed
    |       |   |-- .last_rec
    |       |   |-- .last_sync
    |       |   |-- .recnum
    |       |   |-- byte
    |       |   +-- note
    |       |-- img
    |       +-- panic
    |           +-- byte
    +-- sys
        |-- active
        |-- backup
        |-- golden
        |-- nib
        |-- rtc
        +-- running

```

A FileByteAdapter is a node that implements one additional level of
fan out, the context.  ie. The PanicByteStorage interface uses context
to indicate which of the panic files is being addressed.  ie.  context
0 indicates the whole container and 1 - n indicate which individual
panic container is being addressed.

In the case of Dblk, context 0 references the entire Dblk stream, and
other values of context are ignored.  sub-containers aren't defined
for the Dblk stream.

The Tagnet protocol defines different message types for operating
on the Tag device named variables, including reading and writing
the variable as well as retrieving metadata associated with the
variable.

Processing a message request consists of traversing the elements
of the name in the message according to the nodes of the tree
until reaching the terminus of the name. The terminus can refer
to any intermediate element in the tree or else the leaf node. In
the case of intermediate nodes, the request operates like a
reference to a sub-directory in a file path, whereas a match
to a leaf node provides access to the contents of the system
variable of the specified type. Once the terminus node is matched,
the operation defined by the message is performed on the object
and an optional result is returned in a response message.

## INPUT
Input file
- Represents the complete FactSpace for a given Tag software version
- Consists of a list of CSV records, one for each Fact
- A Fact is described by its TagNet Name and associated properties

Example of a TagNet Fact Record Descriptor
- consisting of: adapter name, interface type, interface name, and
list of name_segments:
```
TagnetGpsXyzAdapterP,tagnet_gps_xyz_t,InfoSensGpsXyz,<node_id:>,"tag","info",<node_id:>,"sens","gps","xyz"
```
## OUTPUT
- Consists of these NESC files for instantiating all elements and wiring
in the TagNet Fact Tree
  - TagnetC.nc
    - includes TagnetWiring.h
  - TagnetDefines.h
    - included by tagnet.h
  - TagNameTree.py
    - Python object representation of name tree for use by other applications
  - TagNameTree.txt
    - ascii text representation of the name tree

### TagnetC.nc
#### New element instantiation parameters
The TagNet Factspace is represented in NESC code as a set of components
wired together in a tree where the root is the firt element in the TagNet
name and each subordinate component is the next element in the name. The
last element in the name is special, and is referred to as an adapter.
The adapter is responsible for handling the conversations from Tag native
data interfaces to the network representation. Other than the root and
the specialized adapters, every other element of a name in the tree is
instantiated as a TagnetNameElement component.

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

## PREPROCESSOR Installation
- Change to directory  mm/tools/tagnet/factspp
- execute the following command
```
sudo ./setup.py install
```

## PREPROCESSOR Example
- Edit the 'TagName Mappings' file on Google Drive in 'tag_stuff/Design Documents'
  - Typically will just copy and edit an existing line
- Download from Google Drive to local file `mm/tos/comm/TagNames/TagNames.tsv`
- Change directory to `mm/tos/comm/TagNames`
- Invoke the preprocessor with the following command
```
 factspp -o . TagNames.tsv
```
- Results found in mm/tos/comm/TagNames
  - `TagnetC.nc`         contains all of the wiring for components in Tagnet Name tree
  - `TagnetDefines.h`    contains defines used by the Tagnet Name components
  - `TagNameTree.txt`    contains text drawing of the Tagnet Name tree


## Rules Engine
- NESC files for instantiating and wiring Rules Engine with access to all TagNet named Facts
  - tbd

## gperf file
 - structs
 - tagnames as keywords
 - default code

## Changes to previous version
- TagnetC.h and tagnet.h are now auto-generated files
- added new auto-generated file tagnetnames.h
