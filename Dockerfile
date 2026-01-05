FROM ubuntu:questing-20251217

# Disable interactive mode
ENV DEBIAN_FRONTEND=noninteractive

# Copy all needed files
COPY entrypoint.sh /

# Install needed packages
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
# hadolint ignore=DL3008
RUN chmod +x /entrypoint.sh ;\
  apt-get update -y ;\
  apt-get install --no-install-recommends -y \
    curl \
    gpg-agent \
    software-properties-common ;\
  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections ;\
  add-apt-repository ppa:git-core/ppa ;\
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg ;\
  chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg ;\
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null ;\
  apt-get update -y ;\
  apt-get install --no-install-recommends -y \
    git \
    gh \
    hub \
    jq ;\
  apt-get clean ;\
  rm -rf /var/lib/apt/lists/*

# Finish up
WORKDIR /github/workspace
ENTRYPOINT ["/entrypoint.sh"]
