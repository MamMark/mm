#!/usr/bin/env python

# generate c-code structures for data-driven finite state machine

import sys
import getopt
import csv

########## read_input
#
# read input file FSM.txt that describes the state machine. This is the ascii results file 
# exported from QFSM program, or can any other type of FSM editor.
#
# The first line of the input file defines states (first field is ignored):
# "Events/States";"SDN";"POR_W";"PWR_UP_W";"CONFIG_W";"RXON";"RX_ACTVE";"TX_ACTIVE";"STANDBY"
#
# Each additional line contains information about each event, first field is event name
# followed by a list of next_state/action pairs, one for each defined state. A value of "-"
# means that no transition pair is defined for that event/state combination.
# " TURNOFF";"-";"-";"-";"-";"SDN pwr_dn";"SDN pwr_dn";"-";"-"

def read_input(fn):
    states = []
    events = ['E_0NOP']
    actions = ['a_break', 'a_nop']
    trans = {}

    file = csv.reader(open(fn, "rb"), delimiter = ';')

    row = file.next()
    row.reverse()    # make it easier to manipulate the list
    row.pop()        # remove the comment in first position of first row (top of stack)
    states = map(lambda orig: 'S_' + orig, row)  # save name of state

    for row in file:
        if not row:
            continue
        row.reverse()
        ev = 'E_' + row.pop().strip(' ')
        events.append(ev)    # save name of event
        st = list(states)    # intermediate copy of states used to process event transition
        while (row):
            cs = st.pop()
            tr = row.pop()
            if (tr == '-'):  # no transition defined for this event/state combination
                continue
            ns, ac = tr.split()
            ns = 'S_' + ns
            ac = 'a_' + ac
            if ev in trans:  # save current_state/next_state/action transition tuple 
                trans[ev].append([cs, ac, ns])   # append to existing list of tuples
            else:
                trans.update({ev: [[cs, ac, ns]]})  # create a new dict entry for even
            if ac not in actions:
                actions.append(ac)                  # save name of action
        trans.update({'E_0NOP': [['S_DEFAULT', 'A_NOP', 'S_DEFAULT']]}) # add E_NOP transition

    return (states, events, actions, trans)

########## write_enums
#
# write out the enum structs for states, events, and actions
#
def write_types():
    print '\ntypedef struct {'
    print '  fsm_state_t    current_state;'
    print '  fsm_action_t   action;'
    print '  fsm_state_t    next_state;'
    print '} fsm_transition_t;'

    print '\ntypedef struct {'
    print '  fsm_event_t    e;'
    print '  fsm_state_t    s;'
    print '} fsm_result_t;'

########## write_enums
#
# write out the enum structs for states, events, and actions
#
def write_enums(sl, el, al):
    # example:
    #   typedef enum {
    #     S_SDN = 0,
    #     S_DEFAULT,
    #   } fsm_state_t;

    # states enum type
    print "\ntypedef enum {"
    print "  S_SDN = 0,"
    for s in sorted(sl):
        if (s == 'S_SDN'):
            continue
        print '  ' + s + ','
    print '  S_DEFAULT,'
    print '} fsm_state_t;'

    # events enum type
    print '\ntypedef enum {'
    print "  E_0NOP = 0,"
    print '  E_NONE = 0,'
    for e in sorted(el):
        if (e == 'E_0NOP'):
            continue
        print '  ' + e + ','
    print '} fsm_event_t;'

    # actions enum type
    print '\ntypedef enum {'
    print '  A_BREAK = 0,'
    for a in sorted(al):
        if (a == 'a_break'):
            continue
        print '  ' + a.upper() + ','
    print '} fsm_action_t;'


########## write_fdecs
#
# write out forward declarations for event transition tables and
# action functions
#
def write_fdecs(el, al):
    # example: const fsm_transition_t fsm_e_nop[];
    print ""
    for e in sorted(el):
        print 'const fsm_transition_t fsm_' + e.lower() + '[];'

    # example: fsm_result_t a_nop(fsm_transition_t *t);
    print ""
    for a in sorted(al):
        if a == 'a_break':
            continue
        print 'fsm_result_t ' + a + '(fsm_transition_t *t);'

########## write_transitions
#
# write out the event transition tables
#
def write_transitions(tr):
    for ev, ts in tr.items():
        print '\nconst fsm_transition_t fsm_' + ev.lower() + '[] = {'
        for t in ts:
            if t:
                print '  {' + t[0] + ', ' + t[1].upper() + ', ' + t[2] + '},'
        print '  { S_DEFAULT, A_BREAK, S_DEFAULT },'
        print '};'

        
########## write_variables
#
# write out the event FSm related variables, including: the list of event lists
#
def write_variables(el):
    print '\nconst fsm_transition_t *fsm_events_group[] = {'
    for e in sorted(el):
        print 'fsm_' + e.lower() + ', ',
    print '};'

########## print results
#
def print_results(results):
    print results[0]
    print results[1]
    print results[2]
    transitions = {}
    transitions = results[3]
    for ev, ts in transitions.items():
        print ev, ts


def usage():
    print 'Usage: '+sys.argv[0]+' -i <file> -o <file>\n'

########## main
#
def main(argv):
    input = "FSM.txt"
    output = "FSM.h"
    try:
        opts, args = getopt.getopt(argv, "hi:o:d", ["help", "input=", "outout="])
    except getopt.GetoptError:
        usage()
        sys.exit(2)
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            usage()
            sys.exit()
        elif opt == '-d':
            global _debug
            _debug = 1
        elif opt in ("-i", "--input"):
            input = arg
        elif opt in ("-o", "--output"):
            output = arg
#    source = "".join(args)

    results = read_input(input)

    target = open(output, 'w')              # a writable object
    sys.stdout = target                         # redirection
    write_enums(results[0], results[1], results[2])
    write_types()
    write_fdecs(results[1], results[2])
    write_transitions(results[3])
    write_variables(results[1])
#    sys.stdout = sys.__stdout__              # remember to reset sys.stdout!
#    print "'s content:", target.content     # show the result of the writing
    target.close()

if __name__ == "__main__":
    main(sys.argv[1:])
