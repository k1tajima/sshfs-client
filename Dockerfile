ARG TAG=latest
FROM alpine:${TAG}

ARG TAG
ENV BASE_IMAGE=alpine:${TAG}
RUN apk update && \
    apk --no-cache add sshfs rsync openssh-client && \
    mkdir -p -m 700 /config/.ssh && ln -s /config/.ssh ~/.ssh && \
    ls -al ~/

VOLUME [ "/config/.ssh", "/mnt/local", "/mnt/remote" ]
