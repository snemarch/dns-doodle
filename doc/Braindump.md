Denne fil er én stor rodebunke lige nu ;-)


Muligvis kan keepalived konfigureres med startup_script? {
  #  Using the startup_script option you could set net.ipv4.vs.exipre_nodest_conn = 1,
}

```
docker run --rm --privileged --network host alpine sysctl net.ipv4.vs.conntrack=1
docker run --rm --privileged --network host alpine sysctl net.ipv4.vs.expire_nodest_conn=1

ip link add dnsnet-host link eth0.53 type ipvlan mode l3
ip addr add 192.168.100.254/24 dev dnsnet-host
ip link set dnsnet-host up

iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o dnsnet-host -j SNAT --to-source 192.168.100.100
```

Iptables reglen skal nok præciseres lidt?




iptables -t nat -L POSTROUTING -v -n --line

Slette iptables
iptables -t nat -D POSTROUTING Xxx


{
    To solve this you need to source nat the traffic on the LVS server:
sysctl net.ipv4.vs.conntrack=1
iptables -t nat -A POSTROUTING -s 172.16.0.0/24 -m ipvs --vaddr 192.168.200.100/32 -j MASQUERADE

I'd do "-j SNAT" to the internal VIP (172.16.0.1???) instead of
MASQUERADING to have the same behavior no matter which LVS box is active.
}




net.ipv4.vs.expire_nodest_conn=1    # optimering?
net.ipv4.vs.conntrack=1         # nødvendig!
net.ipv4.ip_nonlocal_bind=1     # muligvis ikke nødvendig?

# behold andre timeouts, sæt til 1s for UDP... hjælper på failover, men er ikke godt
# nok, og det ser ud til at være globalt for ipvs, hvilket nok ikke er så fedt.
ipvsadm --set 0 0 1

Er der noget med den her?
net.ipv4.vs.expire_nodest_conn=1
net.ipv4.vs.conntrack=1       (default 0)

net.ipv4.ip_nonlocal_bind = 1   (default 0)
net.ipv4.ip_forward = 1         (default 1)

2025-03-02 findings: {
    net.ipv4.vs.conntrack=1 er en vigtig del af løsningen, uden den ser det ikke ud til at SNAT rewrite kan virke.

    Og er det noget i stil med den her?
    iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o dnsnet-host -j SNAT --to-source 192.168.100.100

# de her virker ikke
#    iptables -t nat -A POSTROUTING -d 192.168.100.100 -o dnsnet-host -j SNAT --to-source 192.168.100.100
#    iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -d 192.168.100.100 -o dnsnet-host -j SNAT --to-source 192.168.100.100



    Nu hvor tingene virker ish... docker smider stadig sin egen dns i /etc/resolv.conf, så:

    root@alpine# nslookup mst.dk
    Server:		127.0.0.11
    Address:	127.0.0.11:53

    Unbound ser det som: 192.168.100.254

    root@alpine# nslookup mst.dk 192.168.100.100
    Server:		192.168.100.100
    Address:	192.168.100.100:53

    Unbound ser det (stadig) som 192.168.100.254


    # hyperfine --runs 100000 "nslookup mst.dk"
    Benchmark 1: nslookup mst.dk
      Time (mean ± σ):      32.3 µs ± 200.5 µs    [User: 3.0 µs, System: 27.4 µs]
      Range (min … max):     0.0 µs … 40673.1 µs    100000 runs

    # hyperfine --runs 10000 "nslookup mst.dk 192.168.100.100"
    Benchmark 1: nslookup mst.dk 192.168.100.100
      Time (mean ± σ):       1.1 µs ±  47.9 µs    [User: 0.9 µs, System: 17.9 µs]
      Range (min … max):     0.0 µs … 4550.0 µs    10000 runs

    Oh wow, det er altså en del at spare ved at få docker til at fucke af og gå direkte på VIP'en!

    Desværre er alt det isolation ikke nok til at undgå error hvis man tager en af unbound containerne ned,
    så der skal anden tweaking til... i går aftes havde jeg ca. tilsvarende niveau uden alt det her komplicerede
    vlan og nat halløj, så... hvad har jeg vundet? Isolering? :P
}


TODO: tuning {
    https://github.com/kubernetes/kubernetes/blob/master/pkg/proxy/ipvs/proxier.go#L88-L91
    net.netfilter.nf_conntrack_buckets, net.netfilter.nf_conntrack_max

}


docker > ipvsadm -l --timeout
Timeout (tcp tcpfin udp): 900 120 15
...det ser ud til at "livs_timeouts udp 15" fra keepalived konfigurationen virker.


Keepalived issue-post om policy-based routing og SNAT:
https://github.com/acassen/keepalived/issues/2243 {

    If the IP addresses of the real servers are only used for those services, in other words all packets from the real server hosts with the source address being the address configured in the keepalived real server entries), then it is possible to use source based routing to return packets sent from the real server addresses via the keepalived server(s). It would require a keepalived virtual router to be configured on the private side of the keepalived host, so that the real servicice packets are returned via the VIP.

Suppose a real service is on address 10.0.0.1 TCP port 80, and the private address of your keepalived host is 192.168.0.1. You could specify the following:

ip rule add from 10.0.0.1 ipproto TCP sport 80 table 30000
ip route add default via 192.168.0.1 table 30000


}

docker run -it --rm --privileged --cap-add=NET_ADMIN --cap-add=NET_BROADCAST --cap-add=NET_RAW --network host --volume ./keepalived.conf:/etc/keepalived/keepalived.conf:ro --name keepalived --rm visibilityspots/keepalived:latest
privilegede burde ikke være nødvendig hvis jeg laver keepalive på anden måde end ping?


Current ip route

"ip monitor" er ret interessant, specielt hvis man connecter til docker host vm'en (med nsenter debian tricket fx)

/ # ip route
default via 172.18.0.1 dev eth0
172.18.0.0/16 dev eth0 scope link  src 172.18.0.4
192.168.100.0/24 dev eth1 scope link  src 192.168.100.4

/ # traceroute 192.168.100.2
traceroute to 192.168.100.2 (192.168.100.2), 30 hops max, 46 byte packets
 1  dns-keepalive-unbound1-1.dns-keepalive_dnsnet (192.168.100.2)  0.265 ms  0.004 ms  0.005 ms

/ # traceroute 192.168.100.100
traceroute to 192.168.100.100 (192.168.100.100), 30 hops max, 46 byte packets
 1  192.168.100.100 (192.168.100.100)  0.013 ms  0.044 ms  0.008 ms

ip route get to {IPv4_address_here}




Hvis man "docker debug --privileged <en container på host netværket>", så... {
lsns -t net
        NS TYPE NPROCS PID USER    NETNSID NSFS COMMAND
4026531840 net       5   1 root unassigned      /usr/sbin/keepalived --dont-fork --log-console -f /etc/keepalived/keepalived.conf

"unassigned" skulle betyde at det er docker vm "root" man ændrer på, så altså fx globale netfilter regler.
}

iptables -t nat -A PREROUTING -d 192.168.100.100 -p udp --dport 53 -j DNAT --to-destination 192.168.100.2
iptables -t nat -A PREROUTING -d 192.168.100.100 -p udp --dport 53 -j SNAT --to-source 192.168.100.100
iptables -t nat -D POSTROUTING -s 192.168.100.3 -o dnsnet-host -j MASQUERADE








Hack:
nsenter -n -t $(docker inspect --format {{.State.Pid}} $dockername) ip route add something.
nsenter -n -t $(docker inspect --format {{.State.Pid}} $dockername) ip route del something.

Byg evt. eget docker image baseret på https://github.com/klutchell/unbound-docker
Yeah, det kunne være en god idé - få rippet nogle af de defaults ud jeg ikke bryder mig om,
og få tilføjet en "envsubst" så Unbond config kan sættes i hvert fald delvist med environment variables.
envsubst er en del af gettext, find evt. en mere standalone ting?

docker debug, tools:
    Standard "ip" tools: install iproute2
    Måske helix editoren?
    diff eller diffr , eller anden diff?
    ipvsadm
    iptables - jeg troede docker brugte legacy, men docker-debug-nix har ikke iptables-legacy
    nftables ?
    conntrack-tools
    iptstate , top-like firewall display

Vis socket bindings and stuff:
ss -ltnup


sysctls på compose service niveau?

Jeg skal grokke hvordan macvlan virker – og spiller sammen med custom networks vs host-mode network.

system container:
❯ docker run -it --privileged --pid=host debian nsenter -t 1 -m -u -n -i sh


Since network isolation is tightly coupled to the network's parent interface the result of leaving the -o parent= option off of a docker network create is the exact same as the --internal option.


https://serverfault.com/questions/973578/docker-symmetric-policy-based-routing

TODO: "onlink" parameter til "ip route"

iptables -t nat -A POSTROUTING -m ipvs --vaddr 192.168.42.1/24 --vport 80 -j SNAT --to-source 192.168.10.10



TODO:
Using Keepalived for VIP Failover
If you want an active-passive failover instead of round-robin:

Assign a Virtual IP (VIP) that always points to the active resolver.
Use keepalived in a lightweight container:

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    virtual_ipaddress {
        192.168.1.100
    }
}

der skal måske enables
net.ipv4.ip_nonlocal_bind=1


docker run --cap-add=NET_ADMIN --cap-add=NET_BROADCAST --cap-add=NET_RAW --net=host -d osixia/keepalived:2.0.20


docker run -it --rm --privileged --cap-add=NET_ADMIN --cap-add=NET_BROADCAST --cap-add=NET_RAW --network host --volume ./keepalived.conf:/usr/local/etc/keepalived/keepalived.conf osixia/keepalived

docker run -it --rm --privileged --cap-add=NET_ADMIN --cap-add=NET_BROADCAST --cap-add=NET_RAW --network host --volume ./keepalived.conf:/etc/keepalived/keepalived.conf:ro --name keepalived --rm visibilityspots/keepalived:latest




docker run --cap-add=NET_ADMIN --cap-add=NET_BROADCAST --cap-add=NET_RAW --net=host --env KEEPALIVED_INTERFACE="eno1" --env KEEPALIVED_PASSWORD="password" --env KEEPALIVED_PRIORITY="100" --name keepalived --rm visibilityspots/keepalived:latest




# tilføj tcp og udp services. Dunno om det skal være round-robin eller en anden type,
# eller om det skal væres masquerading eller andet, men... THIS FUCKNG WORKS!
# https://medium.com/google-cloud/load-balancing-with-ipvs-1c0a48476c4d
# https://manpages.debian.org/unstable/ipvsadm/ipvsadm.8.en.html
# https://dev.to/douglasmakey/how-to-setup-simple-load-balancing-with-ipvs-demo-with-docker-4j1d
# https://serverfault.com/questions/503211/per-packet-round-robin-load-balancing-for-udp
# https://serverfault.com/questions/925807/ipvs-keepalived-doesnt-balance-udp-connections
# i denne mode hænger nslookup dog hvis den dns-host som round-robin ville vælge ikke svarer...
# Note: ipvsadm masq laver kun dnat, ikke snat?
# https://www.kernel.org/doc/Documentation/networking/ipvs-sysctl.txt
# noget macvland keealived relateret: https://github.com/acassen/keepalived/blob/master/doc/NOTE_vrrp_vmac.txt
# https://oxpedia.org/wiki/index.php?title=Keepalived - noget info om routing og tunnel devices for de forskellige modes
https://docs.kernel.org/networking/index.html
https://dustinspecker.com/posts/ipvs-how-kubernetes-services-direct-traffic-to-pods/


Måske policy-based routing der rammer dnsnet adresser specifikt? source eller dest routing?
https://blog.scottlowe.org/2013/05/29/a-quick-introduction-to-linux-policy-routing/


# https://developers.500px.com/udp-load-balancing-with-keepalived-167382d7ad08?gi=ddf1fb79ad56  {
    It turns out that caution was to our benefit. After some more research, we came across something called “the ARP problem”. The ARP problem occurs when using LVS with direct routing or IP tunnelling. Since all of the machines in the LVS (ie. the load balancers and real servers) believe that they have ownership of the virtual IP address, it’s possible for clients to receive the MAC address of one of the real servers instead of the load balancer when making an ARP request. Put simply, there was a significant chance that the clients of the rate limiter were going to bypass the load balancer and access one of the rate limiters directly, rendering all of our work useless.

    Luckily, there is a simple solution to the ARP problem. Linux allows dummy networking interfaces to be added to machines. A dummy interface mocks a real IP address and does not respond to ARP requests. All we had to do was add dummy interfaces with the virtual IP address to the rate limiter servers and the ARP problem was avoided. Here’s how we did it:
}


https://groups.io/g/keepalived-users/message/277 {
    Enable expire_nodest_conn:

echo 1 > /proc/sys/net/ipv4/vs/expire_nodest_conn

If this feature is enabled, the load balancer will expire the
        connection immediately when a packet arrives and its
        destination server is not available, then the client program
        will be notified that the connection is closed.

This is what I expected to be the default behavior. I think, when You expect a real server to be up again in short time and want to reuse connections to it, you should configure the check delay and retry values long enough, so the real server does not get removed. If it gets removed, it should be considered as not usable anymore.
Hint: I needed to restart keepalived to make the above change effective.

Decrease LVS UDP timeout from 300 s to 15 s:

ipvsadm --set 0 0 15

(this took effect anytime, no restart of keepalived needed)

Only setting one of each, did not help.

Then I decreased in keepalived.conf
delay_loop, delay_before_retry and misc_timeout all to 5. To have a quick response on failure.

So, on real server failure, there should be a delay before keepalived removes it, between 10 s and 15 s, so at the same time also the UDP connections will time out.


}


Herfra er der noget der bliver interessant: https://groups.io/g/keepalived-users/message/289





fra 2020 {
    Unfortunately iptables and IPvlan don't do well together, especially
    the L3* modes. L3s mode is a little better but please keep in mind
    iptables functionality that involves "forwarding" path, is simply not
    compatible with IPvlan L3* modes. Your best bet is to use L2 mode and
    perform all IPtables operations inside the namespace if possible.
}


inhibit_on_failure på realserver definition? Så bliver mapping entry ikke fjernet hvis serveren er nede, men de skulle få weight=0 så der ikke routes trafik? Ser ikke ud til at gøre hiccup mindre.

Måske kan --ops bringes til at virke, hvis der laves noget manuel ipfilter snat stuff? Men så kommer der muligvis noget højre CPU load.

/proc/sys/net/ipv4/vs/expire_nodest_conn
"Setting expire_nodest_conn=1 will close the connection as soon as the RS is removed by sending a RST to the client."

conn_reuse_mode ? conntrack?


docker run -it --rm --privileged --network host alpine sh

apk add ipvsadm
ipvsadm -A -t 100.100.100.100:53 -s rr
ipvsadm -a -t 100.100.100.100:53 -r 192.168.100.2:53 -m
ipvsadm -a -t 100.100.100.100:53 -r 192.168.100.3:53 -m

ipvsadm -A -u 100.100.100.100:53 -s rr
ipvsadm -a -u 100.100.100.100:53 -r 192.168.100.2:53 -m
ipvsadm -a -u 100.100.100.100:53 -r 192.168.100.3:53 -m

ipvsadm -A -u 192.168.100.100:53 -s wrr
ipvsadm -a -u 192.168.100.100:53 -r 192.168.100.2:53 -m
ipvsadm -a -u 192.168.100.100:53 -r 192.168.100.3:53 -m

apk add hyperfine
hyperfine --runs  10000 "nslookup mst.dk 100.100.100.100"


# uden masq, virker ikke. Ip tunnelling virker heller ikke.
ipvsadm -a -u 100.100.100.100:53 -r 192.168.100.2:53
ipvsadm -a -u 100.100.100.100:53 -r 192.168.100.3:53



# failover og nq ser ikke ud til at være available på den Linux kernel
# docker shipper med - det var måske viable i hostmode på et rigtigt system,
# og så kunne vi muligvis slippe for at have andre moving parts... men det er
# måske rarest alligevel at have en daemon der kigger på container-liveness
# og laver "manuelt automatisk" failover?
ipvsadm -A -u 100.100.100.100:53 -s nq
ipvsadm -a -u 100.100.100.100:53 -r 192.168.100.2:53 -m
ipvsadm -a -u 100.100.100.100:53 -r 192.168.100.3:53 -m

# der er generelt måske ip_forward og ipcvs conntrack der skal enables for nogle scenarier.


--scheduler    -s scheduler         one of rr|wrr|lc|wlc|lblc|lblcr|dh|sh|sed|nq|fo|ovf|mh,
