# helm-actions-vidhya101

GitHub Action for Helm Tasks

Package a Helm chart, push it to an OCI registry (e.g. GHCR), and optionally update a `HELMCHART-VERSION` file back to the repository.

This action uses a prebuilt toolset image (Helm, yq, Git, etc.) and a lightweight action image that executes the `entrypoint.sh` logic.

---

## Features

- Updates `values.yaml` and `Chart.yaml`
  - image.tag
  - version
  - appVersion
- Runs `helm lint` and `helm package`
- Pushes packaged chart to OCI registry (e.g. GHCR)
- Optionally commits `HELMCHART-VERSION` back to repository
- Provides outputs:
  - chart_version
  - image_tag
  - package_file

---

## Inputs

| Input                | Required | Default      | Description |
|---------------------|----------|--------------|-------------|
| chart_dir           | No       | charts       | Path to Helm chart directory |
| oci_registry        | Yes      | -            | OCI registry host (e.g. ghcr.io) |
| oci_repository      | Yes      | -            | OCI repository (e.g. my-org/my-helm-charts) |
| version_prefix      | No       | 0.1.0        | Base semantic version prefix |
| push_chart          | No       | true         | Whether to push chart to OCI |
| update_repo         | No       | true         | Commit HELMCHART-VERSION back to repo |
| target_branch       | No       | current      | Target branch for version commit |
| package_output_dir  | No       | ./           | Output directory for packaged chart |
| auth_token          | yes       | GITHUB_TOKEN | Token for registry login and git push |

---

## Outputs

| Output         | Description |
|----------------|------------|
| chart_version  | Final chart version (e.g. 0.1.0-1234-abcd123) |
| image_tag      | Generated image tag (e.g. 1234-abcd123) |
| package_file   | Packaged chart filename |

---

## Example Usage

```
name: Publish Helm Chart

on:
  push:
    branches:
      - main

permissions:
  contents: write
  packages: write

jobs:
  publish-helm-chart:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Publish Helm Chart
        id: helm
        uses: ./.github/actions/helm-actions   # local action path
        with:
          chart_dir: charts
          oci_registry: ghcr.io
          oci_repository: my-org/my-helm-charts
          version_prefix: 0.1.0
          push_chart: "true"
          update_repo: "true"
          target_branch: main
          auth_token: ${{ secrets.GHCR_TOKEN }}
```