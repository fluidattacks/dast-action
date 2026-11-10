# Fluid Attacks DAST

Free, open-source dynamic application security testing (DAST) action for your GitHub repositories. No account, API key, or registration required to run the scan. Authentication is optional; see [Authentication](#authentication).

## Quick Start

### 1. Create the configuration file

Create a YAML configuration file anywhere in your repository. For example, `.github/dast-config.yaml`:

```yaml
language: EN
strict: false
output:
  file_path: results-dast.sarif
  format: SARIF
dast:
  urls:
    - url: https://www.myapp.com
    - url: https://www.myapp.com/api
```

### 2. Create the GitHub Actions workflow

Add `.github/workflows/fa-dast.yml` to your repository:

```yaml
name: DAST
on:
  push:
  pull_request:
    types: [opened, synchronize, reopened]
  schedule:
    - cron: '0 8 * * 1'  # optional: weekly scan every Monday at 8am

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: fluidattacks/dast-action@<version>
        id: scan
        with:
          scan_config_path: .github/dast-config.yaml
```

Replace `<version>` with the latest release tag. Find it on the [Marketplace page](https://github.com/marketplace/actions/fluid-attacks-dast).

- The target application must be publicly reachable or accessible from the runner when the workflow runs.

### 3. Push and run

Commit both files and push. The scan runs automatically on the next push or pull request.

## Prerequisites

- A GitHub repository (public or private).
- GitHub Actions enabled on the repository.
- A **Linux runner** (`ubuntu-latest` or equivalent) — the action requires Docker, which is only available on Linux-hosted runners.
- No account, token, or API key is needed to run the scan. The action is 100% open source. Authentication is optional; see [Authentication](#authentication).

## Authentication

Authenticating attributes the run to your Fluid Attacks group and applies the group's platform policy. Supply credentials in one of two ways.

### OpenID Connect (recommended)

No secret to store. Set the `group` input (required for OIDC) and grant the job `id-token: write`:

```yaml
permissions:
  id-token: write
  contents: read
jobs:
  dast:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: fluidattacks/dast-action@<version>
        with:
          scan_config_path: .github/dast-config.yaml
          group: my-group
```

In Fluid Attacks, add a trust for issuer `https://token.actions.githubusercontent.com` with the bound claim `repository` = `my-org/my-repo` and enable it for the group. See the [OIDC federation guide](https://docs.fluidattacks.com/find-fix/use-cli/authentication/oidc-federation).

### Group token

```yaml
- uses: fluidattacks/dast-action@<version>
  with:
    scan_config_path: .github/dast-config.yaml
    api_token: ${{ secrets.FLUID_GROUP_TOKEN }}
```

The token identifies the group by itself, so the `group` input is not needed. It takes precedence over OIDC.

Authentication is best-effort: if `group` is missing or invalid for OIDC or no credentials are available (for example, pull requests from forks get neither `id-token` nor secrets), the action logs a warning and runs the scan unauthenticated.

## Configuration

The `scan_config_path` input is required. The action fails immediately if the file does not exist at the given path.

```yaml
dast:
  urls:
    # URLs to scan
    - url: https://www.endpoint1.com
    - url: https://www.endpoint2.com
output:
  file_path: results.sarif
  format: SARIF
```

- **`language`** — language for vulnerability descriptions in the output (`EN` for English, `ES` for Spanish).
- **`strict`** and **`strictness_threshold`** — control whether the scan breaks the build. See [Breaking the build](#breaking-the-build) for how they work and how the inputs of the same name interact with them.
- **`output.file_path`** — path where results are written. When format is `SARIF`, this path is also exposed as the `sarif_file` action output.
- **`output.format`** — `SARIF` produces the standard format. Use `CSV` for a spreadsheet-friendly report.

`output.file_path` and `output.format` must be set together. The scanner decides what to do when only one is present (currently it fails).

- **`dast.urls`** — list of URLs the scanner will probe. The target application must be running and reachable from the GitHub Actions runner.

## Action inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `scan_config_path` | Yes | — | Path to the YAML configuration file, relative to the repository root. The job fails if the file does not exist at the given path. |
| `strict` | No | — | `true` or `false`. Breaks the build when vulnerabilities are found. Overrides `strict` in the configuration file. When omitted, the configuration file decides. See [Breaking the build](#breaking-the-build). |
| `strictness_threshold` | No | — | `low`, `medium`, `high` or `critical`. Breaks the build only for vulnerabilities at or above this severity. Overrides `strictness_threshold` in the configuration file. When omitted, the configuration file decides. See [Breaking the build](#breaking-the-build). |
| `group` | No | — | Fluid Attacks group to authenticate as. Required only for OpenID Connect. See [Authentication](#authentication). |
| `api_token` | No | — | Group token, used when OpenID Connect is not an option. Takes precedence over OIDC. See [Authentication](#authentication). |

### Breaking the build

By default the action reports vulnerabilities without failing the job. Two inputs make it fail, and you only need one of them.

Fail on any vulnerability:

```yaml
- uses: fluidattacks/dast-action@<version>
  id: scan
  with:
    strict: true
```

Fail only on vulnerabilities at or above a severity (`low`, `medium`, `high` or `critical`):

```yaml
- uses: fluidattacks/dast-action@<version>
  id: scan
  with:
    strictness_threshold: high
```

`strictness_threshold` breaks the build by itself, with or without `strict`. The scan always reports every vulnerability and fails only on those that reach the threshold.

How the decision is made:

- **Unauthenticated runs:** `strict: true` breaks the build on any vulnerability, and `strictness_threshold` on those at or above that severity.
- **Authenticated runs:** the minimum CVSS score defined in your group's platform policy also applies. When both a policy and `strictness_threshold` are present, the stricter of the two applies, so the workflow can only make the gate stricter than the platform, never looser.
- **Precedence:** the inputs override `strict` and `strictness_threshold` in the configuration file, including `strict: false` over a file that says `true`. When an input is omitted, the file decides.
- **Invalid values:** a value that is not `true`/`false` (for `strict`) or not one of `low`, `medium`, `high`, `critical` (for `strictness_threshold`, lowercase only) is ignored with a warning, so the configuration file decides.

## Action outputs

| Output | Description |
|---|---|
| `sarif_file` | Path to the SARIF results file (only set when `output.format` is `SARIF`) |
| `vulnerabilities_found` | `true` if any vulnerabilities were detected, `false` otherwise |

You can use these outputs in subsequent workflow steps:

```yaml
- name: Comment on PR
  if: steps.scan.outputs.vulnerabilities_found == 'true'
  run: echo "Vulnerabilities detected — check the Security tab."
```

## Common scenarios

### Scan a staging environment on pull requests only

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
```

Point the URL in your config file to a staging environment that is deployed as part of the PR workflow.

### Strict mode: block merges with vulnerabilities

Set `strict: true` to fail on any vulnerability, or `strictness_threshold` to fail only from a severity up (as an action input or in your configuration file), and enable **Require status checks to pass before merging** in your repository's branch protection settings:

```yaml
- uses: fluidattacks/dast-action@<version>
  with:
    scan_config_path: .github/dast-config.yaml
    strictness_threshold: high
```

### Export results as CSV

```yaml
output:
  file_path: results-dast.csv
  format: CSV
```

## Troubleshooting

### No results appear in the Security tab

DAST findings cannot be uploaded to the GitHub Security tab. GitHub's code scanning API requires each vulnerability to reference a specific file and line number, which does not apply to web application vulnerabilities detected at runtime.

To review DAST results, use the output file produced by the scanner. Set `output.format: SARIF` or `CSV` in your config file and read the file as a workflow artifact.

### The scanner cannot reach the target URL

The GitHub Actions runner must have network access to the URLs configured in `dast.urls`. Private or internal URLs require a self-hosted runner on the same network.

### The pipeline fails unexpectedly

If `strict: true` or a `strictness_threshold` is set (as an action input or in your configuration file), the pipeline fails when the scan finds vulnerabilities, or ones at or above the threshold. This is intentional. Remove them, or raise `strictness_threshold`, if you want the scan to report vulnerabilities without failing the pipeline. The action input wins over the configuration file.

### The job fails with "not found in repository"

The path provided to `scan_config_path` does not exist in the repository. Verify the path is correct and relative to the repository root.

## More information

- [Source code on GitHub](https://github.com/fluidattacks/dast-action)
- [Vulnerability database](https://db.fluidattacks.com)
- [Fluid Attacks documentation](https://docs.fluidattacks.com)
- [SARIF format specification](https://sarifweb.azurewebsites.net/)
