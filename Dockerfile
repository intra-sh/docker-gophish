FROM node:latest AS build-js

ENV GITHUB_USER="kgretzky"
ENV GOPHISH_REPOSITORY="github.com/${GITHUB_USER}/gophish"
ENV GOPHISH_VERSION="v0.12.1"

RUN npm install gulp gulp-cli -g

RUN git clone https://${GOPHISH_REPOSITORY} /build
WORKDIR /build
RUN git checkout ${GOPHISH_VERSION}
RUN npm install
RUN gulp

# Build Golang binary
FROM golang:1.22 AS build-golang

ENV GITHUB_USER="kgretzky"
ENV GOPHISH_REPOSITORY="github.com/${GITHUB_USER}/gophish"
ENV GOPHISH_VERSION="v0.12.1"

RUN git clone https://${GOPHISH_REPOSITORY} /go/src/github.com/gophish/gophish
WORKDIR /go/src/github.com/gophish/gophish
RUN git checkout ${GOPHISH_VERSION}
RUN go get -v && go build -v

# Runtime container
FROM debian:stable-slim

ENV GITHUB_USER="kgretzky"
ENV GOPHISH_REPOSITORY="github.com/${GITHUB_USER}/gophish"
ENV PROJECT_DIR="${GOPATH}/src/${GOPHISH_REPOSITORY}"
ENV GOPHISH_VERSION="v0.12.1"

ARG BUILD_RFC3339="1970-01-01T00:00:00Z"
ARG COMMIT="local"
ARG VERSION="${GOPHISH_VERSION}"

RUN useradd -m -d /opt/gophish -s /bin/bash app

RUN apt-get update && \
	apt-get install --no-install-recommends -y jq libcap2-bin && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /opt/gophish
COPY --from=build-golang /go/src/github.com/warhorse/gophish/ ./
COPY --from=build-js /build/static/js/dist/ ./static/js/dist/
COPY --from=build-js /build/static/css/dist/ ./static/css/dist/
COPY --from=build-golang /go/src/github.com/warhorse/gophish/config.json ./
COPY ./docker-entrypoint.sh /opt/gophish
RUN chmod +x /opt/gophish/docker-entrypoint.sh
RUN chown app. config.json docker-entrypoint.sh

RUN setcap 'cap_net_bind_service=+ep' /opt/gophish/gophish

USER app
RUN sed -i 's/127.0.0.1/0.0.0.0/g' config.json
RUN touch config.json.tmp


EXPOSE 3333 8080 8443 80

CMD ["/opt/gophish/docker-entrypoint.sh"]

STOPSIGNAL SIGKILL

# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.name="Gophish Docker" \
  org.label-schema.description="Gophish Docker Build" \
  org.label-schema.url="https://github.com/${GITHUB_USER}/docker-gophish" \
  org.label-schema.vcs-ref=$VCS_REF \
  org.label-schema.vcs-url="https://github.com/${GITHUB_USER}/docker-gophish" \
  org.label-schema.vendor="${GITHUB_USER}" \
  org.label-schema.version=$VERSION \
  org.label-schema.schema-version="1.0"
