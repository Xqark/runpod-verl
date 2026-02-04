ARG VERL_BASE_IMAGE=verlai/verl:base-verl0.4-cu124-cudnn9.8-torch2.6-fa2.7.4
FROM ${VERL_BASE_IMAGE}
ARG VERL_PIP_SPEC=verl

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    SSH_PORT=22 \
    SSH_USER=poduser \
    SSH_UID=1000 \
    SSH_GID=1000 \
    REQUIRE_SSH_KEY=true

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    ca-certificates \
    tini \
    gosu \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir --upgrade pip && \
    python -m pip install --no-cache-dir "${VERL_PIP_SPEC}"

RUN mkdir -p /run/sshd /etc/ssh/templates

COPY docker/sshd_config.template /etc/ssh/templates/sshd_config.template
COPY docker/entrypoint.sh /opt/runpod/entrypoint.sh
RUN chmod +x /opt/runpod/entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/usr/bin/tini", "--", "/opt/runpod/entrypoint.sh"]
