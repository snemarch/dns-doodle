DNS Doodle: local resolver for containers
=========================================

2025-04-04 {
  HMMMMM! Så, det ser ud til at man faktisk IKKE BEHØVER at lave ipvsadm (og
  dermod nok heller ikke keepalived) på host netværket. Hvis jeg har en
  container med de CAP_ADD jeg har givet til Keepalived, kan jeg manuelt lave
  ipvsadm - og uden ipvs.conntrack og netfilter (dvs. kun med DNAT) kan svaret
  routes direkte tilbage:

```
root@alpine-test ~ # drill google.dk @192.168.100.100
;; ->>HEADER<<- opcode: QUERY, rcode: NOERROR, id: 15590
;; flags: qr rd ra ; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0
;; QUESTION SECTION:
;; google.dk.	IN	A

;; ANSWER SECTION:
google.dk.	301	IN	A	142.251.9.94

;; AUTHORITY SECTION:

;; ADDITIONAL SECTION:

;; Query time: 1 msec
;; SERVER: 192.168.100.100
;; WHEN: Tue Mar  4 07:04:53 2025
;; MSG SIZE  rcvd: 43
```

  Fra tcpdump i en anden shell på test-alpine containeren:
```
07:04:53.044721 IP 192.168.100.4.43528 > 192.168.100.3.53: 15590+ A? google.dk. (27)
07:04:53.045406 IP 192.168.100.3.53 > 192.168.100.4.43528: 15590 1/0/0 A 142.251.9.94 (43)
```

  Til gengæld snakker vi nu millisekund i stedet for microsekund timing >_<
  Men hmm, det er lige meget om jeg også sætter ipvland mode til l2 (dvs både
  i forhold til det virker og til perf), og om jeg går på @192.168.100.100 eller
  @192.168.100.2 , så der er et eller andet *ANDET* der har effekt her...


ipvsadm --set 0 0 15
ipvsadm -A -u 192.168.100.100:53 -s rr
ipvsadm -a -u 192.168.100.100:53 -r 192.168.100.2:53 -m
ipvsadm -a -u 192.168.100.100:53 -r 192.168.100.3:53 -m

  Oh wait, det er drill der er langsommere end nslookup? Yeeeeeps!
  root@alpine-test ~ # hyperfine --runs 10000 "nslookup google.dk 192.168.100.100"
Benchmark 1: nslookup google.dk 192.168.100.100
  Time (mean ± σ):       0.6 µs ±  11.1 µs    [User: 1.1 µs, System: 19.3 µs]
  Range (min … max):     0.0 µs … 481.9 µs    10000 runs


}



This is a research playground for testing various methods of achieving local
(staying within the Docker host machine for cached entries) DNS lookups for
containers. The purpose is performance and resilience, and being independent
of hosting providers without clashing with the operating system resolver.

More [documentation](./doc/) to come, but so far, the implementations:

1. [Simple](./simple/) has no failover mechanism, and relies on Docker's
   builtin DNS resolver to do retries etc.
2. [Keepalived](./keepalived/) has a more sophisticated setup with failover
   load balancing handled by [Keepalived](https://www.keepalived.org/) and
   Linux [IPVS](http://www.linuxvirtualserver.org/).


## A few quick notes on implementation

Docker Compose files are provided to get the examples quickly up and running,
but they're not expected to be units of deployments - the examples have **not**
been made production-ready!

The compose stacks start an [Alpine-test](./docker/alpine-test/) container that
is attached to the `dnsnet`, and has a few preinstalled tools and scripts.
```sh
❯ docker compose exec alpine-test zsh
·▄▄▄▄   ▐ ▄ .▄▄ ·     ·▄▄▄▄              ·▄▄▄▄  ▄▄▌  ▄▄▄ .
██▪ ██ •█▌▐█▐█ ▀.     ██▪ ██ ▪     ▪     ██▪ ██ ██•  ▀▄.▀·
▐█· ▐█▌▐█▐▐▌▄▀▀▀█▄    ▐█· ▐█▌ ▄█▀▄  ▄█▀▄ ▐█· ▐█▌██▪  ▐▀▀▪▄
██. ██ ██▐█▌▐█▄▪▐█    ██. ██ ▐█▌.▐▌▐█▌.▐▌██. ██ ▐█▌▐▌▐█▄▄▌
▀▀▀▀▀• ▀▀ █▪ ▀▀▀▀     ▀▀▀▀▀•  ▀█▄▀▪ ▀█▄▀▪▀▀▀▀▀• .▀▀▀  ▀▀▀

Extra tools available: curl drill helix hyperfine ripgrep
Anonymouse@alpine-test ~ % ./benchmark.sh 1000 192.168.10.2
Benchmark 1: drill google.com @192.168.10.2
  Time (mean ± σ):       2.3 ms ±   0.5 ms    [User: 1.6 ms, System: 0.6 ms]
  Range (min … max):     2.1 ms …  12.3 ms    1000 runs
```

[Unbound](https://www.nlnetlabs.nl/projects/unbound/aboutd) has been chosen
as the resolver, since it has a good performance and security track record,
and is lightweight and easy to configure.

The [klutchell/unbound](https://hub.docker.com/r/klutchell/unbound) image
was chosen slightly at random (high pull count, recently updated), but it
turns out to be pretty nice - small distroless image, thus it starts super
fast, and has a low surface area wrt. vulnerabilities.
