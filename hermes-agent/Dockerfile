ARG HERMES_IMAGE=nousresearch/hermes-agent:sha-bec2250d2c8349fc85201bcd1aa39bcaa766a555
FROM ${HERMES_IMAGE}

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        poppler-utils \
    && rm -rf /var/lib/apt/lists/*
