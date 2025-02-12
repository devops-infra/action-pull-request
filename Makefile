.PHONY: phony
phony: help

# Release tag for the action
VERSION := v0.6.0

# GitHub Actions bogus variables
GITHUB_REF ?= refs/heads/null
GITHUB_SHA ?= aabbccddeeff
VERSION_PREFIX ?=

# Other variables and constants
CURRENT_BRANCH := $(shell echo $(GITHUB_REF) | sed 's/refs\/heads\///')
GITHUB_SHORT_SHA := $(shell echo $(GITHUB_SHA) | cut -c1-7)
DOCKER_USERNAME := christophshyper
DOCKER_ORG_NAME := devopsinfra
DOCKER_IMAGE := action-pull-request
DOCKER_NAME := $(DOCKER_ORG_NAME)/$(DOCKER_IMAGE)
GITHUB_USERNAME := ChristophShyper
GITHUB_ORG_NAME := devops-infra
GITHUB_NAME := ghcr.io/$(GITHUB_ORG_NAME)/$(DOCKER_IMAGE)
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Recognize whether docker buildx is installed or not
DOCKER_CHECK := $(shell docker buildx version 1>&2 2>/dev/null; echo $$?)
ifeq ($(DOCKER_CHECK),0)
DOCKER_COMMAND := docker buildx build --platform linux/amd64,linux/arm64
else
DOCKER_COMMAND := docker build
endif

# Some cosmetics
SHELL := bash
TXT_RED := $(shell tput setaf 1)
TXT_GREEN := $(shell tput setaf 2)
TXT_YELLOW := $(shell tput setaf 3)
TXT_RESET := $(shell tput sgr0)
define NL


endef

# Main actions

.PHONY: help
help: ## Display help prompt
	$(info Available options:)
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(TXT_YELLOW)%-25s $(TXT_RESET) %s\n", $$1, $$2}'


.PHONY: build
build: ## Build Docker images
	$(info $(NL)$(TXT_GREEN) == STARTING BUILD ==$(TXT_RESET))
	$(info $(TXT_GREEN)Release tag:$(TXT_YELLOW)        $(VERSION)$(TXT_RESET))
	$(info $(TXT_GREEN)Current branch:$(TXT_YELLOW)     $(CURRENT_BRANCH)$(TXT_RESET))
	$(info $(TXT_GREEN)Commit hash:$(TXT_YELLOW)        $(GITHUB_SHORT_SHA)$(TXT_RESET))
	$(info $(TXT_GREEN)Build date:$(TXT_YELLOW)         $(BUILD_DATE)$(TXT_RESET))
	$(info $(NL)$(TXT_GREEN)Building image: $(TXT_YELLOW)$(DOCKER_NAME):$(VERSION_PREFIX)$(VERSION) $(TXT_GREEN)and $(TXT_YELLOW)$(GITHUB_NAME):$(VERSION_PREFIX)$(VERSION)$(TXT_RESET)$(NL))
	@$(DOCKER_COMMAND) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg VCS_REF=$(GITHUB_SHORT_SHA) \
		--build-arg VERSION=$(VERSION) \
		--file=Dockerfile \
		--tag=$(DOCKER_NAME):$(VERSION_PREFIX)$(VERSION) \
		--tag=$(DOCKER_NAME):$(VERSION_PREFIX)latest \
		--tag=$(GITHUB_NAME):$(VERSION_PREFIX)$(VERSION) \
		--tag=$(GITHUB_NAME):$(VERSION_PREFIX)latest .
	@echo -e "\n$(TXT_GREEN)Build images: $(TXT_YELLOW)$(DOCKER_NAME):$(VERSION_PREFIX)$(VERSION) $(TXT_GREEN)and $(TXT_YELLOW)$(GITHUB_NAME):$(VERSION_PREFIX)$(VERSION)$(TXT_RESET)"


.PHONY: login
login: ## Log into all registries
	@echo -e "\n$(TXT_GREEN)Logging to: $(TXT_YELLOW)Docker Hub$(TXT_RESET)"
	@echo $(DOCKER_TOKEN) | docker login -u $(DOCKER_USERNAME) --password-stdin
	@echo -e "\n$(TXT_GREEN)Logging to: $(TXT_YELLOW)GitHub Packages$(TXT_RESET)"
	@echo $(GITHUB_TOKEN) | docker login ghcr.io -u $(GITHUB_USERNAME) --password-stdin


.PHONY: push
push: login ## Push Docker images
	$(info $(NL)$(TXT_GREEN) == STARTING DEPLOYMENT == $(TXT_RESET))
	$(info $(NL)$(TXT_GREEN)Pushing image: $(TXT_YELLOW)$(DOCKER_NAME):$(VERSION_PREFIX)$(VERSION) $(TXT_GREEN)and $(TXT_YELLOW)$(GITHUB_NAME):$(VERSION_PREFIX)$(VERSION)$(TXT_RESET)$(NL))
	@$(DOCKER_COMMAND) --push \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg VCS_REF=$(GITHUB_SHORT_SHA) \
		--build-arg VERSION=$(VERSION) \
		--file=Dockerfile \
		--tag=$(DOCKER_NAME):$(VERSION_PREFIX)$(VERSION) \
		--tag=$(DOCKER_NAME):$(VERSION_PREFIX)latest \
		--tag=$(GITHUB_NAME):$(VERSION_PREFIX)$(VERSION) \
		--tag=$(GITHUB_NAME):$(VERSION_PREFIX)latest .
	@echo -e "\n$(TXT_GREEN)Pushed images: $(TXT_YELLOW)$(DOCKER_NAME):$(VERSION_PREFIX)$(VERSION) $(TXT_GREEN)and $(TXT_YELLOW)$(GITHUB_NAME):$(VERSION_PREFIX)$(VERSION)$(TXT_RESET)"
