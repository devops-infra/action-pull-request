# Use a clean tiny image to store artifacts in
FROM ubuntu:jammy-20220531

# Labels for http://label-schema.org/rc1/#build-time-labels
# And for https://github.com/opencontainers/image-spec/blob/master/annotations.md
# And for https://help.github.com/en/actions/building-actions/metadata-syntax-for-github-actions
ARG NAME="GitHub Action for creating Pull Requests"
ARG DESCRIPTION="GitHub Action that will create a pull request from the current branch"
ARG REPO_URL="https://github.com/devops-infra/action-pull-request"
ARG AUTHOR="Krzysztof Szyper / ChristophShyper / biotyk@mail.com"
ARG HOMEPAGE="https://christophshyper.github.io/"
ARG BUILD_DATE=2020-04-01T00:00:00Z
ARG VCS_REF=abcdef1
ARG VERSION=v0.0
LABEL \
  com.github.actions.name="${NAME}" \
  com.github.actions.author="${AUTHOR}" \
  com.github.actions.description="${DESCRIPTION}" \
  com.github.actions.color="purple" \
  com.github.actions.icon="upload-cloud" \
  org.label-schema.build-date="${BUILD_DATE}" \
  org.label-schema.name="${NAME}" \
  org.label-schema.description="${DESCRIPTION}" \
  org.label-schema.usage="README.md" \
  org.label-schema.url="${HOMEPAGE}" \
  org.label-schema.vcs-url="${REPO_URL}" \
  org.label-schema.vcs-ref="${VCS_REF}" \
  org.label-schema.vendor="${AUTHOR}" \
  org.label-schema.version="${VERSION}" \
  org.label-schema.schema-version="1.0"	\
  org.opencontainers.image.created="${BUILD_DATE}" \
  org.opencontainers.image.authors="${AUTHOR}" \
  org.opencontainers.image.url="${HOMEPAGE}" \
  org.opencontainers.image.documentation="${REPO_URL}/blob/master/README.md" \
  org.opencontainers.image.source="${REPO_URL}" \
  org.opencontainers.image.version="${VERSION}" \
  org.opencontainers.image.revision="${VCS_REF}" \
  org.opencontainers.image.vendor="${AUTHOR}" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.title="${NAME}" \
  org.opencontainers.image.description="${DESCRIPTION}" \
  maintainer="${AUTHOR}" \
  repository="${REPO_URL}"

# Copy all needed files
COPY entrypoint.sh /

# Install needed packages
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
# hadolint ignore=DL3008
RUN chmod +x /entrypoint.sh ;\
  apt-get update -y ;\
  apt-get install --no-install-recommends -y \
    gpg-agent \
    software-properties-common ;\
  add-apt-repository ppa:git-core/ppa ;\
  apt-get update -y ;\
  apt-get install --no-install-recommends -y \
    git \
    hub \
    jq ;\
  apt-get clean ;\
  rm -rf /var/lib/apt/lists/*

# Finish up
CMD ["hub version"]
WORKDIR /github/workspace
ENTRYPOINT ["/entrypoint.sh"]
