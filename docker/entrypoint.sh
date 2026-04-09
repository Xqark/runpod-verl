#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[entrypoint] %s\n' "$*" >&2
}

write_shell_env() {
  local home_dir="$1"
  local codex_home="$2"
  local codex_sqlite_home="$3"
  local claude_config_dir="$4"

  mkdir -p /etc/profile.d /etc/fish/conf.d
  cat > /etc/profile.d/codex.sh <<EOF
export PATH="${home_dir}/.local/bin:\$PATH"
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export LANGUAGE="${LANGUAGE:-en_US:en}"
export CODEX_HOME="${codex_home}"
export CODEX_SQLITE_HOME="${codex_sqlite_home}"
export CLAUDE_CONFIG_DIR="${claude_config_dir}"
if ! infocmp "\${TERM:-xterm-256color}" >/dev/null 2>&1; then
  export TERM="xterm-256color"
fi
EOF
  cat > /etc/fish/conf.d/codex.fish <<EOF
fish_add_path -g "${home_dir}/.local/bin"
set -gx LANG "${LANG:-en_US.UTF-8}"
set -gx LC_ALL "${LC_ALL:-en_US.UTF-8}"
set -gx LANGUAGE "${LANGUAGE:-en_US:en}"
set -gx CODEX_HOME "${codex_home}"
set -gx CODEX_SQLITE_HOME "${codex_sqlite_home}"
set -gx CLAUDE_CONFIG_DIR "${claude_config_dir}"
if not infocmp "\$TERM" >/dev/null 2>&1
    set -gx TERM xterm-256color
end
EOF
}

user_can_write_dir() {
  local user_name="$1"
  local dir_path="$2"
  local probe="${dir_path}/.codex-write-test.$$"

  mkdir -p "${dir_path}"
  if gosu "${user_name}" bash -lc "touch '$probe' && rm -f '$probe'" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

pick_user_dir() {
  local user_name="$1"
  local preferred="$2"
  local fallback="$3"

  if user_can_write_dir "${user_name}" "${preferred}"; then
    printf '%s\n' "${preferred}"
    return 0
  fi

  log "Directory ${preferred} is not writable by ${user_name}; falling back to ${fallback}"
  mkdir -p "${fallback}"
  chown "${user_name}:${user_name}" "${fallback}" 2>/dev/null || true
  printf '%s\n' "${fallback}"
}

install_claude_for_user() {
  local user_name="$1"
  local home_dir="$2"
  local user_path="${home_dir}/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

  if gosu "${user_name}" env HOME="${home_dir}" PATH="${user_path}" bash -lc 'command -v claude >/dev/null 2>&1'; then
    return 0
  fi

  log "Starting Claude Code install for ${user_name} in background"
  nohup gosu "${user_name}" env HOME="${home_dir}" PATH="${user_path}" \
    bash -lc 'curl -fsSL https://claude.ai/install.sh | bash' \
    >/tmp/claude-install.log 2>&1 &
}

ensure_group() {
  local group_name="$1"
  local group_id="$2"

  if getent group "${group_name}" >/dev/null 2>&1; then
    return
  fi

  if getent group "${group_id}" >/dev/null 2>&1; then
    group_name="$(getent group "${group_id}" | cut -d: -f1)"
    log "Reusing existing group ${group_name} for gid ${group_id}"
    return
  fi

  groupadd --gid "${group_id}" "${group_name}"
}

ensure_user() {
  local user_name="$1"
  local user_id="$2"
  local group_name="$3"
  local user_shell="$4"

  if id -u "${user_name}" >/dev/null 2>&1; then
    if [[ -n "${user_shell}" ]]; then
      usermod -s "${user_shell}" "${user_name}" || true
    fi
    return
  fi

  if getent passwd "${user_id}" >/dev/null 2>&1; then
    user_name="$(getent passwd "${user_id}" | cut -d: -f1)"
    log "Reusing existing user ${user_name} for uid ${user_id}"
    if [[ -n "${user_shell}" ]]; then
      usermod -s "${user_shell}" "${user_name}" || true
    fi
    return
  fi

  useradd --uid "${user_id}" --gid "${group_name}" --create-home --shell "${user_shell:-/bin/bash}" "${user_name}"
}

main() {
  local ssh_user="${SSH_USER:-poduser}"
  local ssh_uid="${SSH_UID:-1000}"
  local ssh_gid="${SSH_GID:-1000}"
  local ssh_port="${SSH_PORT:-22}"
  local require_key="${REQUIRE_SSH_KEY:-true}"
  local keys="${SSH_AUTHORIZED_KEYS:-${SSH_PUBLIC_KEY:-${RUNPOD_PUBLIC_KEY:-${PUBLIC_KEY:-}}}}"
  local root_password="${ROOT_PASSWORD:-123456}"
  local ssh_password="${SSH_USER_PASSWORD:-123456}"
  local user_shell="/bin/bash"

  if command -v fish >/dev/null 2>&1; then
    user_shell="$(command -v fish)"
  fi

  ensure_group "${ssh_user}" "${ssh_gid}"
  ensure_user "${ssh_user}" "${ssh_uid}" "${ssh_user}" "${user_shell}"
  if getent group sudo >/dev/null 2>&1; then
    usermod -aG sudo "${ssh_user}" || true
  fi

  if [[ -n "${root_password}" ]]; then
    printf 'root:%s\n' "${root_password}" | chpasswd
  fi
  if [[ -n "${ssh_password}" ]]; then
    printf '%s:%s\n' "${ssh_user}" "${ssh_password}" | chpasswd
  fi

  local home_dir
  home_dir="$(getent passwd "${ssh_user}" | cut -d: -f6)"
  if [[ -z "${home_dir}" || "${home_dir}" == "/" ]]; then
    log "Refusing to use unsafe home directory for ${ssh_user}: '${home_dir}'"
    exit 1
  fi
  local codex_home
  local codex_sqlite_home
  local claude_config_dir
  codex_home="$(pick_user_dir "${ssh_user}" "${CODEX_HOME:-${home_dir}/workspace/.codex}" "${home_dir}/.codex")"
  codex_sqlite_home="$(pick_user_dir "${ssh_user}" "${CODEX_SQLITE_HOME:-${home_dir}/workspace/.codex}" "${home_dir}/.codex")"
  claude_config_dir="$(pick_user_dir "${ssh_user}" "${CLAUDE_CONFIG_DIR:-${home_dir}/workspace/.claude}" "${home_dir}/.claude")"
  mkdir -p "${home_dir}"
  chown "${ssh_user}:${ssh_user}" "${home_dir}" 2>/dev/null || true
  chmod 755 "${home_dir}"
  write_shell_env "${home_dir}" "${codex_home}" "${codex_sqlite_home}" "${claude_config_dir}"
  if [[ -f /etc/skel/.tmux.conf && ! -f "${home_dir}/.tmux.conf" ]]; then
    cp /etc/skel/.tmux.conf "${home_dir}/.tmux.conf"
    chown "${ssh_user}:${ssh_user}" "${home_dir}/.tmux.conf" 2>/dev/null || true
  fi

  local ssh_dir="${home_dir}/.ssh"
  local auth_keys_file="${ssh_dir}/authorized_keys"

  mkdir -p "${ssh_dir}" /run/sshd
  chmod 700 "${ssh_dir}"

  if [[ -n "${keys}" ]]; then
    printf '%s\n' "${keys}" > "${auth_keys_file}"
    chmod 600 "${auth_keys_file}"
    chown -R "${ssh_user}:${ssh_user}" "${ssh_dir}" 2>/dev/null || true
  elif [[ "${require_key}" == "true" ]]; then
    log "No SSH key found in SSH_AUTHORIZED_KEYS/SSH_PUBLIC_KEY/RUNPOD_PUBLIC_KEY/PUBLIC_KEY."
    log "Set REQUIRE_SSH_KEY=false only for debugging and non-production use."
    exit 1
  else
    log "Starting without SSH keys because REQUIRE_SSH_KEY=false"
    touch "${auth_keys_file}"
    chmod 600 "${auth_keys_file}"
    chown -R "${ssh_user}:${ssh_user}" "${ssh_dir}" 2>/dev/null || true
  fi

  ssh-keygen -A
  sed \
    -e "s/__SSH_PORT__/${ssh_port}/g" \
    -e "s/__SSH_USER__/${ssh_user}/g" \
    /etc/ssh/templates/sshd_config.template > /etc/ssh/sshd_config
  /usr/sbin/sshd -e
  log "sshd started on port ${ssh_port} for user ${ssh_user}"
  export CODEX_HOME="${codex_home}"
  export CODEX_SQLITE_HOME="${codex_sqlite_home}"
  export CLAUDE_CONFIG_DIR="${claude_config_dir}"
  export LANG="${LANG:-en_US.UTF-8}"
  export LC_ALL="${LC_ALL:-en_US.UTF-8}"
  export LANGUAGE="${LANGUAGE:-en_US:en}"
  export PATH="${home_dir}/.local/bin:${PATH}"
  if ! infocmp "${TERM:-xterm-256color}" >/dev/null 2>&1; then
    export TERM="xterm-256color"
  fi
  install_claude_for_user "${ssh_user}" "${home_dir}"

  if [[ "$#" -eq 0 ]]; then
    log "No command provided; keeping container alive."
    exec sleep infinity
  fi

  exec "$@"
}

main "$@"
