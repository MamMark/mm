"""
TagNet Monitor State Machine.
"""
import pydotplus as pydot
#from PIL import Image

def main():
    g_radio = pydot.Dot(
        graph_type='digraph',
        rankdir="LR",
        nodesep=0.7)

    cluster_off=pydot.Cluster(
        'Off',
        label='',
        labeljust='l',
        fontsize=24)
    cluster_off.add_node(
        pydot.Node(
            'off',
            label='OFF',
            fontsize=20))
    g_radio.add_subgraph(cluster_off)

    cluster_hunt=pydot.Cluster(
        'Hunt',
        label='hunt',
        labeljust='l',
        fontsize=24)
    cluster_hunt.add_node(
        pydot.Node(
            'hunt_recv',
            label='recv',
            fontsize=16))
    cluster_hunt.add_node(
        pydot.Node(
            'hunt_stby',
            label='stby',
            fontsize=16))
    cluster_hunt.add_node(
        pydot.Node(
            'hunt_recv_wait',
            label='recv_wait',
            fontsize=16))
    cluster_hunt.add_node(
        pydot.Node(
            'hunt_stby_wait',
            label='stby_wait',
            fontsize=16))
    g_radio.add_subgraph(cluster_hunt)

    cluster_lost=pydot.Cluster(
        'Lost',
        label='lost',
        labeljust='r',
        fontsize=24)
    cluster_lost.add_node(
        pydot.Node(
            'lost_recv',
            label='recv',
            fontsize=16))
    cluster_lost.add_node(
        pydot.Node(
            'lost_stby',
            label='stby',
            fontsize=16))
    cluster_lost.add_node(
        pydot.Node(
            'lost_recv_wait',
            label='recv_wait',
            fontsize=16))
    cluster_lost.add_node(
        pydot.Node(
            'lost_stby_wait',
            label='stby_wait',
            fontsize=16))
    g_radio.add_subgraph(cluster_lost)

    cluster_base=pydot.Cluster(
        'Base',
        label='base',
        labeljust='r',
        fontsize=24)
    cluster_base.add_node(
        pydot.Node(
            'base_recv',
            label='recv',
            fontsize=16))
    cluster_base.add_node(
        pydot.Node(
            'base_stby',
            label='stby',
            fontsize=16))
    cluster_base.add_node(
        pydot.Node(
            'base_recv_wait',
            label='recv_wait',
            fontsize=16))
    cluster_base.add_node(
        pydot.Node(
            'base_stby_wait',
            label='stby_wait',
            fontsize=16))
    g_radio.add_subgraph(cluster_base)


    # create edge between two main nodes:
    # when creating edges, don't need to
    # predefine the nodes
    #
    g_radio.add_edge(
        pydot.Edge(
            "off","base_recv_wait",
            label="booted / r_on,t_start"))

    g_radio.add_edge(
        pydot.Edge(
            "base_recv","base_stby_wait",
            label="not_forme / r_stby,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "base_recv","base_stby_wait",
            label="timer_expired / r_stby,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "base_stby","base_recv_wait",
            label="timer_expired / r_on,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "base_recv","base_recv",
            label="forme / t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "base_stby","hunt_stby",
            label="tries_exceeded / t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "base_recv_wait","base_recv",
            label="radio_done / t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "base_stby_wait","base_stby",
            label="radio_done / t_start"))

    g_radio.add_edge(
        pydot.Edge(
            "hunt_recv","hunt_stby_wait",
            label="not_forme / r_stby,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "hunt_recv","hunt_stby_wait",
            label="timer_expired / r_stby,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "hunt_stby","hunt_recv_wait",
            label="timer_expired / r_on,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "hunt_recv","base_recv",
            label="forme / t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "hunt_stby","lost_stby",
            label="tries_exceeded / t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "hunt_recv_wait","hunt_recv",
            label="radio_done / t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "hunt_stby_wait","hunt_stby",
            label="radio_done / t_start"))

    g_radio.add_edge(
        pydot.Edge(
            "lost_recv","lost_stby_wait",
            label="not_forme / r_stby,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "lost_recv","lost_stby_wait",
            label="timer_expired / r_stby,t_start"))
    # infinite retries in LOST state
    g_radio.add_edge(
        pydot.Edge(
            "lost_stby","lost_recv_wait",
            label="timer_expired / r_on,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "lost_recv","base_recv",
            label="forme / t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "lost_recv_wait","lost_recv",
            label="radio_done / t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "lost_stby_wait","lost_stby",
            label="radio_done / t_start"))

    # output:
    # write dot file, then render as png
    fname='tagmonograph.dot'
    g_radio.write_raw(fname)
    print "wrote", fname

    fname='tagmonograph.png'
    g_radio.write_png(fname)
    print "wrote", fname

if __name__=="__main__":
    main()
