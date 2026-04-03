#!/usr/bin/env bash
set -euo pipefail


#--- args (from action.yml) ---#
CHART_DIR="${1:-charts}"
OCI_REGISTRY="${2:-}"
OCI_REPOSITORY="${3:-}"
VERSION_PREFIX="${4:-0.1.0}"
PUSH_CHART="${5:-true}"
UPDATE_REPO="${6:-true}"
TARGET_BRANCH_INPUT="${7:-}"
PACKAGE_OUTPUT_DIR="${8:-./}"
INPUT_AUTH_TOKEN="${9:-}"



# ---- GitHub runner envs (fallback defaults) ----

GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-/github/workspace}"
GITHUB_RUN_ID="${GITHUB_RUN_ID:-0}"
GITHUB_SHA="${GITHUB_SHA:-}"
GITHUB_ACTOR="${GITHUB_ACTOR:-github-actions}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
GITHUB_REF="${GITHUB_REF:-refs/heads/main}"

# Prefer provided token, else fallback to GITHUB_TOKEN
AUTH_TOKEN="${INPUT_AUTH_TOKEN:-${GITHUB_TOKEN:-}}"



cd "${GITHUB_WORKSPACE}" 

echo "::group::Inputs"
echo "CHART_DIR=${CHART_DIR}"
echo "OCI_REGISTRY=${OCI_REGISTRY}"
echo "OCI_REPOSITORY=${OCI_REPOSITORY}"
echo "VERSION_PREFIX=${VERSION_PREFIX}"
echo "PUSH_CHART=${PUSH_CHART}"
echo "UPDATE_REPO=${UPDATE_REPO}"
echo "TARGET_BRANCH_INPUT=${TARGET_BRANCH_INPUT}"
echo "PACKAGE_OUTPUT_DIR=${PACKAGE_OUTPUT_DIR}"
echo "::endgroup::"


# ---- Sanity Checks ----   

# ---- sanity checks ----

if [ -z "${OCI_REGISTRY}" ] || [ -z "${OCI_REPOSITORY}" ]; then
  echo "ERROR: OCI_REGISTRY and OCI_REPOSITORY are required inputs."
  exit 2
fi

if [ ! -d "${CHART_DIR}" ]; then
  echo "ERROR: chart_dir '${CHART_DIR}' not found."
  exit 3
fi



# ---- compute tags & versions ----
SHORT_SHA="${GITHUB_SHA:0:7}"
IMAGE_TAGS="${GITHUB_RUN_ID}-${SHORT_SHA}"
FINAL_VERSION="${VERSION_PREFIX}-${IMAGE_TAGS}"
echo "Computed IMAGE_TAGS=${IMAGE_TAGS}"
echo "Computed FINAL_VERSION=${FINAL_VERSION}"


# ------- update values & version in Chart.yaml -----
echo "::group::Update chart files"
# Update image tag in values.yaml
yq e '.image.tag = strenv(IMAGE_TAGS)' "${CHART_DIR}/values.yaml" -i
# Update version in Chart.yaml
yq e '.version = strenv(FINAL_VERSION)' "${CHART_DIR}/Chart.yaml" -i
# Update appVersion in Chart.yaml
yq e '.appVersion = strenv(IMAGE_TAGS)' "${CHART_DIR}/Chart.yaml" -i
echo "Updated ${CHART_DIR}/values.yaml:"
cat "${CHART_DIR}/values.yaml" || true
echo "Updated ${CHART_DIR}/Chart.yaml:"
cat "${CHART_DIR}/Chart.yaml" || true
echo "::endgroup::"


# ------- helm lint ----
echo "::group::Linting Helm chart"
helm lint "${CHART_DIR}"
echo "::endgroup::"


# ---- helm package ----
echo "::group::Helm Package"
mkdir -p "${PACKAGE_OUTPUT_DIR}"
helm package "${CHART_DIR}" -d "${PACKAGE_OUTPUT_DIR}"
CHART_TGZ=$(ls -1t "${PACKAGE_OUTPUT_DIR}"/*.tgz 2>/dev/null | head -n1 || true)
if [ -z "${CHART_TGZ}" ]; then
  echo "ERROR: packaged chart not found in ${PACKAGE_OUTPUT_DIR}"
  exit 4
fi
echo "Packaged chart: ${CHART_TGZ}"
echo "::endgroup::"


# ---- push to OCI (GHCR) if requested ----

if [ "${PUSH_CHART}" = "true" ] || [ "${PUSH_CHART}" = "True" ]; then
  echo "::group::Helm OCI Login & Push"

  if [ -z "${AUTH_TOKEN}" ]; then
    echo "ERROR: auth token is required to push to OCI registry. Provide auth_token input or ensure GITHUB_TOKEN is available."
    exit 5
  fi

  # login
  echo "${AUTH_TOKEN}" | helm registry login "${OCI_REGISTRY}" -u "${GITHUB_ACTOR}" --password-stdin

  # push (Helm expects full path to tgz)
  helm push "${CHART_TGZ}" "oci://${OCI_REGISTRY}/${OCI_REPOSITORY}"

  # logout
  helm registry logout "${OCI_REGISTRY}" || true

  echo "::endgroup::"
else
  echo "PUSH_CHART is false: skipping push to OCI registry"
fi



# ---- update repo with version ----

if [ "${UPDATE_REPO}" = "true" ] || [ "${UPDATE_REPO}" = "True" ]; then
  echo "::group::Update Repo with Helm Chart Version"

  if [ -z "${AUTH_TOKEN}" ]; then
    echo "ERROR: auth token required to push changes back to repo. Provide auth_token or ensure GITHUB_TOKEN is available."
    exit 6
  fi

  # git config
  git config --global user.name "github-actions"
  git config --global user.email "github-actions@github.com"

  # Determine branch
  if [ -n "${TARGET_BRANCH_INPUT}" ]; then
    TARGET_BRANCH="${TARGET_BRANCH_INPUT}"
  else
    TARGET_BRANCH=$(echo "${GITHUB_REF}" | sed 's|refs/heads/||' || true)
    if [ -z "${TARGET_BRANCH}" ]; then
      TARGET_BRANCH="main"
    fi
  fi

  echo "Target branch: ${TARGET_BRANCH}"

  # set remote with token
  REMOTE_URL="https://${GITHUB_ACTOR}:${AUTH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
  git remote set-url origin "${REMOTE_URL}"

  # write version file
  echo "VERSION=${FINAL_VERSION}" > HELMCHART-VERSION

  git add HELMCHART-VERSION || true

  if git diff --cached --quiet; then
    echo "No changes to commit for HELMCHART-VERSION"
  else
    git commit -m "Updated Helm Chart Version to ${FINAL_VERSION}" || true
    git push origin "HEAD:${TARGET_BRANCH}"
  fi

  echo "::endgroup::"
else
  echo "UPDATE_REPO is false: skipping commit of HELMCHART-VERSION"
fi


# ---- set outputs ----
echo "chart_version=${FINAL_VERSION}" >> "${GITHUB_OUTPUT}"
echo "image_tag=${IMAGE_TAGS}" >> "${GITHUB_OUTPUT}"
echo "package_file=$(basename "${CHART_TGZ}")" >> "${GITHUB_OUTPUT}"
echo "Action finished successfully"