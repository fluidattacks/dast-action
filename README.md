# Fluid Attacks DAST

Free, open-source dynamic application security testing (DAST) action for your GitHub repositories. No account, API key, or registration required.

## Quick Start (2 minutes)

### 1. Create the configuration file

Add a file called `.fluidattacks.yaml` in the root of your repository:

```yaml
language: EN
strict: true
output:
  file_path: results.sarif
  format: SARIF
dast:
  urls:
    - url: https://www.myincredibleapp.com
```

If you already have a `.fluidattacks.yaml` file in your repo, it works.
You only need to add the `dast` section and the action will work with the other
default keys.
That's it for configuration. This minimal setup will scan your entire repository.

### 2. Create the GitHub Actions workflow

Add the file `.github/workflows/fa-dast.yml` to your repository:

```yaml
name: DAST
on:
  push:
  pull_request:
    types: [opened, synchronize, reopened]
  schedule:
    - cron: '0 8 * * 1'  # optional: weekly full scan every Monday at 8am

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: fluidattacks/dast-action@main
        id: scan
```

Commit the file, push, and the scan will run automatically. Results will be written to `.fa-dast-results.sarif` in your workspace (Or the path you configured in the `.fluidattacks.yaml`).

## Prerequisites

- A GitHub repository (public or private).
- GitHub Actions enabled on the repository.
- A **Linux runner** (`ubuntu-latest` or equivalent) — the action requires Docker, which is only available on Linux-hosted runners.
- No account, token, or API key is needed. The action is 100% open source.

## How it works

### Scan types

The action scans the url targets that you have set in your configuration file.

## Viewing results

After the workflow runs, results are written to `.fa-dast-results.sarif` (or whatever path you configured in `output.file_path`).

### SARIF file

The raw SARIF file is always available in your workspace. You can download it as an artifact, process it with other tools, or upload it to a third-party platform.

### GitHub Security tab

DAST results cannot be uploaded to the GitHub Security tab. GitHub's Code Scanning feature requires findings to reference specific file paths and line numbers, but DAST vulnerabilities point to URLs and endpoints — there are no source file locations to annotate.

To review findings, download the SARIF file as a workflow artifact or export results as CSV.

## Configuration

The action reads a `.fluidattacks.yaml` file at the root of your repository. Only the `dast`, `strict` and `output` keys are used by this action.

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

## Action outputs

| Output | Description |
|---|---|
| `sarif_file` | Path to the SARIF results file |
| `vulnerabilities_found` | `true` if any vulnerabilities were detected, `false` otherwise |

You can use these outputs in subsequent workflow steps. For example:

```yaml
- name: Comment on PR
  if: steps.scan.outputs.vulnerabilities_found == 'true'
  run: echo "Vulnerabilities were found. Download the SARIF artifact for details."
```

## Common scenarios

### Export results as CSV

```yaml
output:
  file_path: results.csv
  format: CSV
```

## Troubleshooting

### Where do I view the results?

Download the SARIF file from the workflow run's **Artifacts** section, or set `output.format: CSV` to get a CSV report. DAST findings cannot be uploaded to the GitHub Security tab because they reference URLs, not source file locations.

## More information

- [Source code on GitHub](https://github.com/fluidattacks/dast-action)
- [Vulnerability database](https://db.fluidattacks.com)
- [Fluid Attacks documentation](https://docs.fluidattacks.com)
- [SARIF format specification](https://sarifweb.azurewebsites.net/)
