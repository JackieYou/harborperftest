FROM golang:latest
RUN cd /go/src && git clone https://github.com/JackieYou/harbortest.git && mv harbortest perftest
WORKDIR /go/src/perftest/
