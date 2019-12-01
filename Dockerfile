ARG TAG=latest
FROM alpine:${TAG}
ARG TAG

RUN echo "alpine:${TAG}" > baseimage_tag && cat baseimage_tag && \
    # apk update && apk upgrade && \
    apk --no-cache add sshfs rsync openssh-client && \
    mkdir -p -m 700 /config/.ssh && ln -s /config/.ssh ~/.ssh && \
    ls -al ~/

VOLUME [ "/config/.ssh", "/mnt/local", "/mnt/remote" ]
