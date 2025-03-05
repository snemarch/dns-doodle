FROM alpine:3.21

ENV DOODLE_APP_TOOLS="curl drill helix hyperfine ripgrep zsh"
ENV DOODLE_SYS_TOOLS="iptables ipvsadm tcpdump"

# Separate "apk add" for layering purposes - sys tools probably changes less.
RUN apk add --no-interactive --no-cache ${DOODLE_SYS_TOOLS}
RUN apk add --no-interactive --no-cache ${DOODLE_APP_TOOLS}

WORKDIR /root
COPY --chown=root:root sleep.sh /
COPY --chown=root:root banner.txt magic.sh benchmark.sh watcher.sh .zshrc ./


CMD ["/bin/zsh"]
