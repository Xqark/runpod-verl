#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[entrypoint] %s\n' "$*"
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
  local root_password="${ROOT_PASSWORD:-}"
  local ssh_password="${SSH_USER_PASSWORD:-}"
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
  mkdir -p "${home_dir}"
  chown "${ssh_user}:${ssh_user}" "${home_dir}"
  chmod 755 "${home_dir}"
  if [[ -f /etc/skel/.tmux.conf && ! -f "${home_dir}/.tmux.conf" ]]; then
    cp /etc/skel/.tmux.conf "${home_dir}/.tmux.conf"
    chown "${ssh_user}:${ssh_user}" "${home_dir}/.tmux.conf"
  fi

  local ssh_dir="${home_dir}/.ssh"
  local auth_keys_file="${ssh_dir}/authorized_keys"

  mkdir -p "${ssh_dir}" /run/sshd
  chmod 700 "${ssh_dir}"

  if [[ -n "${keys}" ]]; then
    printf '%s\n' "${keys}" > "${auth_keys_file}"
    chmod 600 "${auth_keys_file}"
    chown -R "${ssh_user}:${ssh_user}" "${ssh_dir}"
  elif [[ "${require_key}" == "true" ]]; then
    log "No SSH key found in SSH_AUTHORIZED_KEYS/SSH_PUBLIC_KEY/RUNPOD_PUBLIC_KEY/PUBLIC_KEY."
    log "Set REQUIRE_SSH_KEY=false only for debugging and non-production use."
    exit 1
  else
    log "Starting without SSH keys because REQUIRE_SSH_KEY=false"
    touch "${auth_keys_file}"
    chmod 600 "${auth_keys_file}"
    chown -R "${ssh_user}:${ssh_user}" "${ssh_dir}"
  fi

  ssh-keygen -A
  sed \
    -e "s/__SSH_PORT__/${ssh_port}/g" \
    -e "s/__SSH_USER__/${ssh_user}/g" \
    /etc/ssh/templates/sshd_config.template > /etc/ssh/sshd_config
  /usr/sbin/sshd -e
  log "sshd started on port ${ssh_port} for user ${ssh_user}"

  if [[ "$#" -eq 0 ]]; then
    log "No command provided; keeping container alive."
    exec sleep infinity
  fi

  exec "$@"
}

main "$@"
