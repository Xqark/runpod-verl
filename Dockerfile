ARG VERL_BASE_IMAGE=verlai/verl:app-verl0.5-vllm0.10.0-mcore0.13.0-te2.2
FROM ${VERL_BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    SSH_PORT=22 \
    SSH_USER=poduser \
    SSH_UID=1000 \
    SSH_GID=1000

RUN sed -i 's|https://mirrors.tuna.tsinghua.edu.cn/ubuntu|http://archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true && \
    sed -i 's|http://mirrors.tuna.tsinghua.edu.cn/ubuntu|http://archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true && \
    apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    ca-certificates \
    curl \
    gnupg \
    build-essential \
    openssh-server \
    tini \
    gosu \
    fish \
    tmux \
    btop \
    nvtop \
    git-lfs \
    libsndfile1 \
    libgl1 \
    libglib2.0-0 \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
#     apt-get update && apt-get install -y --no-install-recommends \
#     nodejs \
#     && rm -rf /var/lib/apt/lists/*
#
# RUN npm config delete //registry.npmjs.org/:_authToken || true && \
#     npm config set registry https://registry.npmjs.org/ && \
#     npm install -g @openai/codex opencode-ai

RUN git lfs install --system

RUN python -m pip install --no-cache-dir --upgrade pip

COPY requirements/sdpo-overlay.txt /tmp/requirements/sdpo-overlay.txt
RUN python -m pip install --no-cache-dir --no-deps -r /tmp/requirements/sdpo-overlay.txt && \
    rm -rf /tmp/requirements

RUN mkdir -p /run/sshd /etc/ssh/templates

COPY docker/sshd_config.template /etc/ssh/templates/sshd_config.template
COPY docker/entrypoint.sh /opt/runpod/entrypoint.sh
COPY scripts/bootstrap-sdpo.sh /usr/local/bin/bootstrap-sdpo.sh
RUN chmod +x /opt/runpod/entrypoint.sh
RUN chmod +x /usr/local/bin/bootstrap-sdpo.sh

COPY .tmux.conf /etc/skel/.tmux.conf
RUN cp /etc/skel/.tmux.conf /root/.tmux.conf

EXPOSE 22

ENTRYPOINT ["/usr/bin/tini", "--", "/opt/runpod/entrypoint.sh"]
