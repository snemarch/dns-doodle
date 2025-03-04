FROM alpine:3.21

RUN apk add --no-interactive --no-cache curl drill helix hyperfine ripgrep zsh
RUN apk add --no-interactive --no-cache iptables ipvsadm tcpdump

WORKDIR /root
COPY --chown=root:root sleep.sh /
COPY --chown=root:root banner.txt magic.sh benchmark.sh watcher.sh .zshrc ./


CMD ["/bin/zsh"]
