FROM alpine:3.23.4

ARG TARGETARCH
ARG HUB_VERSION=2.14.2

# Copy all needed files
COPY entrypoint.sh /
COPY scripts/ /scripts/
COPY alpine-packages.txt /tmp/alpine-packages.txt

# Install needed packages
SHELL ["/bin/sh", "-euxo", "pipefail", "-c"]
# hadolint ignore=DL3018
RUN set -eux; \
  xargs -r apk add --no-cache < /tmp/alpine-packages.txt; \
  chmod +x /entrypoint.sh /scripts/replace-template-diff.sh /scripts/split_content_bytes.py; \
  targetarch="${TARGETARCH:-}"; \
  if [ -z "${targetarch}" ]; then \
    case "$(uname -m)" in \
      x86_64) targetarch="amd64" ;; \
      aarch64|arm64) targetarch="arm64" ;; \
      *) echo "Unsupported host architecture: $(uname -m)"; exit 1 ;; \
    esac; \
  fi; \
  case "${targetarch}" in amd64|arm64) ;; *) echo "Unsupported TARGETARCH: ${targetarch}"; exit 1 ;; esac; \
  hub_archive="hub-linux-${targetarch}-${HUB_VERSION}.tgz"; \
  hub_url="https://github.com/mislav/hub/releases/download/v${HUB_VERSION}/${hub_archive}"; \
  curl -fsSL "${hub_url}" -o /tmp/hub.tgz; \
  tar -xzf /tmp/hub.tgz -C /tmp; \
  install -m 0755 "/tmp/hub-linux-${targetarch}-${HUB_VERSION}/bin/hub" /usr/bin/hub; \
  gh --version; \
  test -x /usr/bin/hub; \
  git --version; \
  jq --version; \
  python3 --version; \
  rm -rf /var/cache/*; \
  rm -rf /root/.cache/*; \
  rm -rf /tmp/*

# Finish up
WORKDIR /github/workspace
ENTRYPOINT ["/entrypoint.sh"]
