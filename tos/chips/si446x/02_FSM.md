The Si446x Driver uses a finite state machine (FSM) to control all major actions in the component. The state machine is embodied in c-code data structures that are created by a code generator taking a FSM definition as input and outputing the Si446xFSM.h file. In addtion to the primary structures used by the FSM, some helper structures are auto-generated, such as the forward declarations for all action functions.

Below is the graphical representation of the Si446x Driver Finite State Machine.

![Si446xDriverLayer](Si446xFSM.png)

PROCESS TO CREATE runtime code

The process steps required to produce the Si446xFSM.h file includes the precursor state machine representation file used by the QFSM graphical finite state machine editor. This Si446xFSM.fsm file is in XML format that QFSM knows how to handle. QFSM allows a human to edit, or change, the finite state machine through a graphical user interface and save the appropriate file formats needed for building the target program.

Here are the steps required to update the FSM:

- Checkout revision of Si446xFSM.fsm
- Open with Qfsm
- Use graphical interface to make changes
- Save .fsm file
- Export ASCII file
- Export .png file
- Export .html file
- run the fsmc.py code generator
- make the target platform

IMPORTANT ARTIFACTS that are saved in git

- .fsm file contains the QFSM native file
    - Defined by a Mealy-style machine where each arc (transition) is labeled with an output action.
    - format is XML
- .txt file contains the state table in ASCII plain text, used as fsmc.py input format
- .png file is a graphical representation of the state machine diagram
- .html file is a web page version of state machine table
- .h file is the intermediate generated file from the fsmc.py code generator it is checked in as well


FINITE STATE TABLE input format

The intermediate state machine format that is input to the fsmc.py code generator is the ASCII plain text formatted file exported from QFSM. It contains a set of records describing the event/state,action,next_state relationships. These names are used to create the enumerations and function names provided in the Si446xFSM.h file and used by Si446xDriverLayerP.

"Events/States";"SDN";"POR_W";"PWR_UP_W";"CONFIG_W";"RXON";"RX_ACTVE";"TX_ACTIVE";"STANDBY"
" CONFIG_DONE";"-";"-";"-";"RXON ready";"-";"-";"-";"-"
" PACKET_RX";"-";"-";"-";"-";"-";"RXON rx_cmp";"-";"-"
" PACKET_SENT";"-";"-";"-";"-";"-";"-";"RXON tx_cmp";"-"
" PREAMBLE_DETECT";"-";"-";"-";"-";"RXON nop";"-";"-";"-"
" RX_FIFO";"-";"-";"-";"-";"-";"RX_ACTVE rx_header";"-";"-"
" STANDBY";"-";"-";"-";"-";"STANDBY standby";"STANDBY standby";"STANDBY standby";"-"
" SYNC_DETECT";"-";"-";"-";"-";"RX_ACTVE rx_on";"-";"-";"-"
" TRANSMIT";"-";"-";"-";"-";"TX_ACTIVE tx_on";"-";"-";"-"
" TURNOFF";"-";"-";"-";"-";"SDN pwr_dn";"SDN pwr_dn";"-";"-"
" TURNON";"POR_W unshut";"-";"-";"-";"-";"-";"-";"RXON ready"
" WAIT_DONE";"-";"PWR_UP_W pwr_up";"-";"-";"-";"RXON rx_error";"RXON tx_error";"-"


FSM CODE GENERATOR

The process of converting the graphical representation of the state machine into a set of c-code definitions is performed by the FSM code generator in the utilities file fsmc.py. This program takes the nominal state table input definition found in Si446xFSM.txt, which was produced by the QFSM program, into the Si446xFSM.h file with the c-code state machine definitions.

The workflow by file is:

.fsm -> .txt -> .h -> .exe
     -> .png -> .md
     -> .html

Since some of this workflow is manual, some care must be taken with handling intermediate files. Right now some intermediate artifacts are included in the git repository.


QFSM

Sourceforge.net (http://qfsm.sourceforge.net)
Version 0.54
Development version 2015-01-01
Copyright 2000-2015 by Stefan Duffner, Rainer Strobel
email: qfsm@duffner-net.de

Qfsm is a graphical editor for finite state machines written in C++ using the graphical toolkit Qt.

Finite state machines are a model to describe complex objects or systems in terms of the states they may be in. In practice they are used to design integrated circuits or to create regular expressions, scanners or other program code.

Features of Qfsm are:

- Drawing, editing and printing of diagrams
- Binary, ASCII and "free text" condition codes
- Integrity check
- Interactive simulation
- HDL export in the file formats: AHDL, VHDL, Verilog HDL, KISS
- Creation of VHDL test code
- Diagram export in the formats: EPS, SVG, and PNG
- State table export in Latex, HTML and ASCII plain text format
- State Machine Compiler (SMC) export (supporting code generation in many programming languages)
- Ragel file export (used for C/C++, Java or Ruby code generation)
- Other export formats: SCXML, vvvv Automata code

You can download the source code of Qfsm 0.54 from here:
http://sourceforge.net/projects/qfsm/files/qfsm/qfsm-0.54/qfsm-0.54.0-Source.tar.bz2/download

QFSM RUNTIME REQUIREMENTS

- Qt SDK version 4.8.3 [4.8.6] http://qt.nokia.com/
- CMake 2.8 or higher [2.8.12.2] http://www.cmake.org/
- Graphviz library 2.38.0 or higher (optional) http://www.graphviz.org/