ARG VERL_BASE_IMAGE=verlai/verl:vllm011.latest
FROM ${VERL_BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    SSH_PORT=22 \
    SSH_USER=poduser \
    SSH_UID=1000 \
    SSH_GID=1000 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANGUAGE=en_US:en

RUN sed -i 's|https://mirrors.tuna.tsinghua.edu.cn/ubuntu|http://archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true && \
    sed -i 's|http://mirrors.tuna.tsinghua.edu.cn/ubuntu|http://archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true && \
    apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    ca-certificates \
    curl \
    gnupg \
    locales \
    ncurses-term \
    build-essential \
    openssh-server \
    tini \
    gosu \
    fish \
    tmux \
    btop \
    nvtop \
    git-lfs \
    rclone \
    libsndfile1 \
    libgl1 \
    libglib2.0-0 \
    sudo \
    bubblewrap \
    && sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN npm config delete //registry.npmjs.org/:_authToken || true && \
    npm config set registry https://registry.npmjs.org/ && \
    npm install -g @openai/codex@latest

RUN git lfs install --system

RUN python -m pip install --no-cache-dir --upgrade pip

COPY requirements/sdpo-overlay.txt /tmp/requirements/sdpo-overlay.txt
RUN python -m pip install --no-cache-dir --no-deps -r /tmp/requirements/sdpo-overlay.txt && \
    rm -rf /tmp/requirements

RUN mkdir -p /run/sshd /etc/ssh/templates

COPY docker/sshd_config.template /etc/ssh/templates/sshd_config.template
COPY docker/entrypoint.sh /opt/runpod/entrypoint.sh
RUN chmod +x /opt/runpod/entrypoint.sh

COPY .tmux.conf /etc/skel/.tmux.conf
RUN cp /etc/skel/.tmux.conf /root/.tmux.conf

EXPOSE 22

ENTRYPOINT ["/usr/bin/tini", "-s", "--", "/opt/runpod/entrypoint.sh"]
