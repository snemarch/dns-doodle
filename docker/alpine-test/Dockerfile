FROM alpine:3.21

ARG USER="Anonymouse"
ARG GROUP="Anonymouse"

RUN apk add --no-interactive --no-cache curl drill helix hyperfine ripgrep zsh

RUN addgroup -S ${GROUP} && adduser -S ${USER} -G ${GROUP}

USER ${USER}
WORKDIR /home/${USER}
COPY --chown=${USER}:${GROUP} sleep.sh /
COPY --chown=${USER}:${GROUP} banner.txt benchmark.sh .zshrc ./

CMD ["/bin/zsh"]
