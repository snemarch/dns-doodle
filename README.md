DNS Doodle: local resolver for containers
=========================================

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
