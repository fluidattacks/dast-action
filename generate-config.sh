#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/tmp/dast-config.yaml"

RESOLVED="${GITHUB_WORKSPACE}/${SCAN_CONFIG_PATH}"
if [[ ! -f "${RESOLVED}" ]]; then
  echo "::error::scan_config_path '${SCAN_CONFIG_PATH}' not found in repository"
  exit 1
fi

prepare_config() {
  python3 -c "
import yaml, os, sys

fa_config_path = os.path.join(os.environ['GITHUB_WORKSPACE'], os.environ['SCAN_CONFIG_PATH'])

if os.path.isfile(fa_config_path):
    print(f'::notice::Reading config from {fa_config_path}')
    with open(fa_config_path) as f:
        user_cfg = yaml.safe_load(f) or {}

    output_path = user_cfg.get('output',{}).get('file_path')
    output_format = user_cfg.get('output',{}).get('format')

    if not (output_path and output_format):
        output_path = '.fluidattacks-dast-results.sarif'
        output_format = 'SARIF'

    cfg_output = {'format': output_format, 'file_path': output_path}

    user_cfg['output'] = cfg_output
    if not user_cfg.get('namespace'):
        user_cfg['namespace'] = os.environ['GITHUB_REPOSITORY'].split('/', 1)[-1]

    with open('${CONFIG_FILE}', 'w') as f:
        yaml.dump(user_cfg, f, default_flow_style=False, sort_keys=False)
else:
    print(f\"::error::scan_config_path '{os.environ['SCAN_CONFIG_PATH']}' not found in repository\")
    sys.exit(1)
"
}

# Authentication is best-effort: any problem falls back to an unauthenticated scan.
build_auth_args() {
  DOCKER_ENV=()
  SCAN_ARGS=()

  if [[ -z "${FLUID_GROUP:-}" ]]; then
    if [[ -n "${INTEGRATES_API_TOKEN:-}" ]]; then
      echo "::warning::'api_token' ignored because 'group' is not set. Running unauthenticated."
    fi
    return 0
  fi

  if [[ ! "${FLUID_GROUP}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "::warning::Invalid 'group' value. Running unauthenticated."
    return 0
  fi

  if [[ -n "${INTEGRATES_API_TOKEN:-}" ]]; then
    DOCKER_ENV+=(-e INTEGRATES_API_TOKEN)
    echo "Authenticating group '${FLUID_GROUP}' with a Group token"
  elif [[ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" && -n "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]]; then
    DOCKER_ENV+=(-e ACTIONS_ID_TOKEN_REQUEST_URL -e ACTIONS_ID_TOKEN_REQUEST_TOKEN)
    echo "Authenticating group '${FLUID_GROUP}' with OIDC"
  else
    echo "::warning::'group' is set but no credentials are available (grant 'permissions: id-token: write' or provide 'api_token'; fork pull requests get neither). Running unauthenticated."
    return 0
  fi

  SCAN_ARGS+=(--group "${FLUID_GROUP}")
}

run_scan() {
  build_auth_args
  echo "::group::Generated configuration"
  cat "${CONFIG_FILE}"
  echo "::endgroup::"

  local exit_code=0
  docker run --rm \
    ${DOCKER_ENV[@]+"${DOCKER_ENV[@]}"} \
    -v "${GITHUB_WORKSPACE}:/src" \
    -v "${CONFIG_FILE}:${CONFIG_FILE}:ro" \
    "ghcr.io/fluidattacks/dast:latest" \
    dast scan ${SCAN_ARGS[@]+"${SCAN_ARGS[@]}"} "${CONFIG_FILE}" || exit_code=$?

  if [[ ${exit_code} -eq 0 ]]; then
    echo "vulnerabilities_found=false" >> "${GITHUB_OUTPUT}"
  elif [[ ${exit_code} -eq 1 ]]; then
    echo "vulnerabilities_found=true" >> "${GITHUB_OUTPUT}"
  else
    echo "::error::Scanner exited with code ${exit_code}"
    exit "${exit_code}"
  fi

  python3 -c "
import yaml, re
with open('${CONFIG_FILE}') as f:
    cfg = yaml.safe_load(f)
fmt = cfg.get('output', {}).get('format', '')
if fmt == 'SARIF':
    path = cfg['output']['file_path']
    sanitized = re.sub(r'[\r\n]', '', str(path))
    print('sarif_file=' + sanitized)
" >> "${GITHUB_OUTPUT}" 2> /dev/null || true
}

main() {
  prepare_config
  echo "skip=false" >> "${GITHUB_OUTPUT}"
  run_scan
}

main
