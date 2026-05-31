ARG HERMES_IMAGE=ghcr.io/grycap/hermes-agent:v2026.5.29.2
FROM ${HERMES_IMAGE}

USER root

COPY requirements.txt /tmp/requirements.txt

RUN apt-get update \
    && xargs -r apt-get install -y --no-install-recommends < /tmp/requirements.txt \
    && rm -rf /var/lib/apt/lists/*
