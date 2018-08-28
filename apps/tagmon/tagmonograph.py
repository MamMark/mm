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

    cluster_near=pydot.Cluster(
        'Near',
        label='near',
        labeljust='l',
        fontsize=24)
    cluster_near.add_node(
        pydot.Node(
            'near_recv',
            label='recv',
            fontsize=16))
    cluster_near.add_node(
        pydot.Node(
            'near_stby',
            label='stby',
            fontsize=16))
    cluster_near.add_node(
        pydot.Node(
            'near_recv_wait',
            label='recv_wait',
            fontsize=16))
    cluster_near.add_node(
        pydot.Node(
            'near_stby_wait',
            label='stby_wait',
            fontsize=16))
    g_radio.add_subgraph(cluster_near)

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

    cluster_home=pydot.Cluster(
        'Home',
        label='home',
        labeljust='r',
        fontsize=24)
    cluster_home.add_node(
        pydot.Node(
            'home_recv',
            label='recv',
            fontsize=16))
    cluster_home.add_node(
        pydot.Node(
            'home_stby',
            label='stby',
            fontsize=16))
    cluster_home.add_node(
        pydot.Node(
            'home_recv_wait',
            label='recv_wait',
            fontsize=16))
    cluster_home.add_node(
        pydot.Node(
            'home_stby_wait',
            label='stby_wait',
            fontsize=16))
    g_radio.add_subgraph(cluster_home)


    # create edge between two main nodes:
    # when creating edges, don't need to
    # predefine the nodes
    #
    g_radio.add_edge(
        pydot.Edge(
            "off","home_recv_wait",
            label="booted / r_on,t_start"))

    g_radio.add_edge(
        pydot.Edge(
            "home_recv","home_stby_wait",
            label="not_forme / r_stby,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "home_recv","home_stby_wait",
            label="timer_expired / r_stby,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "home_stby","home_recv_wait",
            label="timer_expired / r_on,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "home_recv","home_recv",
            label="forme / t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "home_recv_wait","home_recv",
            label="radio_done / t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "home_stby_wait","near_stby",
            label="radio_done & !cycles / t_start(w/rtc)"))
    g_radio.add_edge(
        pydot.Edge(
            "home_stby_wait","home_stby",
            label="radio_done & cycles / t_start"))

    g_radio.add_edge(
        pydot.Edge(
            "near_recv","near_stby_wait",
            label="not_forme / r_stby,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "near_recv","near_stby_wait",
            label="timer_expired / r_stby,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "near_stby","near_recv_wait",
            label="timer_expired / r_on,t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "near_recv","home_recv",
            label="forme / t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "near_recv_wait","near_recv",
            label="radio_done / t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "near_stby_wait","near_stby",
            label="radio_done & cycles / t_start"))
    g_radio.add_edge(
        pydot.Edge(
            "near_stby_wait","lost_stby",
            label="radio_done & !cycles / t_start"))

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
            "lost_recv","home_recv",
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
