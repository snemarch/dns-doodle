Simple setup
============

The simple setup has no failover mechanism, and relies on Docker's builtin DNS
resolver to do retries etc.

It creates two networks, the `dnsnet` and `normalnet` - while it doesn't make
much difference in this sample, the idea is that the `dnsnet` network and the
resolver containers should be created separately from the other application
containers, which can then attaach to the `dnsnet`.

When running a Docker Compose setup (or a manually created container, for that
matter) using custom networks, the specified DNS servers don't get added to
/etc/resolv.conf – insted Docker adds a single entry for it's own internal DNS
resolver. This means that even for this simple setup, Alpine/musl won't shotgun
blast resolvers.

There's no extra isolation apart from bridged networking, and as for resolving,
Docker seems to follow the glibc method - that is, try the primary DNS server
first, and the secondary on failure. It will do this for every single DNS
request, so performance will be severely degraded until the primary resolver
container is working again.
