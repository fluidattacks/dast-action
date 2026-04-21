# Fluid Attacks DAST

Free, open-source dynamic application security testing (DAST) action for your GitHub repositories. No account, API key, or registration required.

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
- No account, token, or API key is needed. The action is 100% open source.

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
- **`strict`** — when `false`, the scanner reports findings but does not fail the pipeline. Set to `true` to break the build on any detected vulnerability.
- **`output.file_path`** — path where results are written. When format is `SARIF`, this path is also exposed as the `sarif_file` action output.
- **`output.format`** — `SARIF` produces the standard format. Use `CSV` for a spreadsheet-friendly report.
- **`dast.urls`** — list of URLs the scanner will probe. The target application must be running and reachable from the GitHub Actions runner.

## Action inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `scan_config_path` | Yes | — | Path to the YAML configuration file, relative to the repository root. The job fails if the file does not exist at the given path. |

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

Set `strict: true` in your configuration file and enable **Require status checks to pass before merging** in your repository's branch protection settings.

```yaml
strict: true
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

If `strict: true` is set, the pipeline fails whenever vulnerabilities are found. Set `strict: false` to report findings without failing the pipeline.

### The job fails with "not found in repository"

The path provided to `scan_config_path` does not exist in the repository. Verify the path is correct and relative to the repository root.

## More information

- [Source code on GitHub](https://github.com/fluidattacks/dast-action)
- [Vulnerability database](https://db.fluidattacks.com)
- [Fluid Attacks documentation](https://docs.fluidattacks.com)
- [SARIF format specification](https://sarifweb.azurewebsites.net/)
