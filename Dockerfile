FROM golang:latest
RUN cd /go/src && git clone https://github.com/JackieYou/harborperftest.git && mv harborperftest perftest
WORKDIR /go/src/perftest/
