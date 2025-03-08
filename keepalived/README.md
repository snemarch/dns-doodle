Keepalived
==========

The Keepalived setup has a more sophisticated setup with failover load balancing
handled by [Keepalived](https://www.keepalived.org/) and Linux
[IPVS](http://www.linuxvirtualserver.org/).

This approach manages a single Virtual IP that is mapped to several real IPs.
Keepalived does the liveness detection and mapping, utilizing the underlying
Linux kernel IPVS support. This should be pretty efficient, as there is no
traditional usermode load balancer involved. Unlike the [Simple](../simple/)
example, this one does round-robin between the Unbound resolvers.

The `dnsnet` is now an l3s ipvlan, using a `eth0.53` subdevice of the main
network interface. This way, we get decent isolation between `dnsnet` and the
host network, to ensure the host and docker resolvers don't interfere with
eachother. The `eth0.53` interface is mapped as `eth1` in the containers.

The use of Keepalived is overkill, since we only need it for monitoring the
Unbound resolver containers, not any of the fancy VRRP failover stuff. But it
was the best initial tool I found that can manage the IPVS RealIP management.

The failover is a bit slower than I would like – if you bring down one of the
Unbound containers, there will be a few seconds "burp" where DNS lookups stall,
but at least no dropped requets. Keepalived measures it's timeouts in seconds,
and using `nslookup` to detect liveness is probably a bit heavyweight.

The Unbound config has been hardened slightly, specifying listen-interface and
access-control.

So, IPVS only does DNAT, but we need SNAT for replies from Unbound to be routed
back to the requesting containers. We need to apply a couple of fixes to the
**host network**, done by fix-network.sh, run by a **privileged** init container.
The `vs.conntrack` setting (requiring priviliged mode to set) is absolute necessary,
and the `iptables` rule finishes that part of the magic.

The `expire_nodest_conn` makes IPVS remove dead RIP connections faster, reducing
the risk of dropped requests.

The `ip link` section is necessary to let the host network communicate with the
ipvlan. Yes, it's not just the host that is isolated from the containers,
without the explicit link the subinterface is isolated from the hsot as well.
Neat.

NOTE: unbound.conf from the `klutchell/unbound` image has been added here, but
odified to remove the interface and access-control configurations, since that
can't be removed in the override config - but we're still using the override
conf for our specific settings of interest, so it's easy to see how it differs
from [simple](../simple/).

TODO: figure out if e.g. the `net.ipv4.vs.*` sysctls are global, or namespaced.
During testing, I *think* they're actually namespaced, but they need to be run
in privilegede containers if set on the host network. Now that I have the setup
working, it would be interesting to see if Keepalived *needs* to be on the host
network, or if things can be shuffled around...

TODO: check the performance implications of the vlan'ing.

TODO: check if we might actually *need* this (or perhaps just some subnetting
instead) to get the necessary packet rewrite working.

TODO: fork `klutchell/unbound` to allows config from environment variables,
so `listen-interface` could use IP address instead of the `eth1` interface.
