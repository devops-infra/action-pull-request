FROM alpine:3.23.4

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
  gh --version; \
  git --version; \
  jq --version; \
  python3 --version; \
  rm -rf /var/cache/*; \
  rm -rf /root/.cache/*; \
  rm -rf /tmp/*

# Finish up
WORKDIR /github/workspace
ENTRYPOINT ["/entrypoint.sh"]
