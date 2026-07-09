# 🚀 GitHub Action for creating Pull Requests
**GitHub Action that will create a pull request from the currently selected branch.**


## 📦 Available on
- **Docker Hub:** [devopsinfra/action-pull-request:latest](https://hub.docker.com/repository/docker/devopsinfra/action-pull-request)
- **GitHub Packages:** [ghcr.io/devops-infra/action-pull-request:latest](https://github.com/devops-infra/action-pull-request/pkgs/container/action-pull-request)


## ✨ Features
* Creates pull request if triggered from a current branch or any specified by `source_branch` to a `target_branch`
* Title and body of a pull request can be specified with `title` and `body`
* Can assign `assignee`, `reviewer`, one or more `label`, a `milestone` or mark it as a `draft`
* Can replace any `old_string` inside a pull request template with a `new_string`. Or put commits' subjects in place of `old_string`
* When `get_diff` is `true` will add list of commits in place of `<!-- Diff commits -->` and list of modified files in place of `<!-- Diff files -->` in a pull request template
* When `allow_no_diff` is set to true will continue execution and create pull request even if both branches have no differences, e.g. having only a merge commit
* Supports both `amd64` and `arm64` architectures


## 🔗 Related Actions
**Useful in combination with my other action [devops-infra/action-commit-push](https://github.com/devops-infra/action-commit-push).**

Both actions are compatible when you use `actions/checkout` with a custom `path`:
- set `repository_path` in `devops-infra/action-commit-push`
- set the same `repository_path` in `devops-infra/action-pull-request`

This action isolates global Git config in a temporary file (via `GIT_CONFIG_GLOBAL`) to avoid modifying runner/user-level Git config.


## 📊 Badges
[
![GitHub repo](https://img.shields.io/badge/GitHub-devops--infra%2Faction--pull--request-blueviolet.svg?style=plastic&logo=github)
![GitHub last commit](https://img.shields.io/github/last-commit/devops-infra/action-pull-request?color=blueviolet&logo=github&style=plastic&label=Last%20commit)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/devops-infra/action-pull-request?color=blueviolet&label=Code%20size&style=plastic&logo=github)
![GitHub license](https://img.shields.io/github/license/devops-infra/action-pull-request?color=blueviolet&logo=github&style=plastic&label=License)
](https://github.com/devops-infra/action-pull-request "shields.io")
<br>
[
![DockerHub](https://img.shields.io/badge/DockerHub-devopsinfra%2Faction--pull--request-blue.svg?style=plastic&logo=docker)
![Docker version](https://img.shields.io/docker/v/devopsinfra/action-pull-request?color=blue&label=Version&logo=docker&style=plastic&sort=semver)
![Image size](https://img.shields.io/docker/image-size/devopsinfra/action-pull-request/latest?label=Image%20size&style=plastic&logo=docker)
![Docker Pulls](https://img.shields.io/docker/pulls/devopsinfra/action-pull-request?color=blue&label=Pulls&logo=docker&style=plastic)
](https://hub.docker.com/r/devopsinfra/action-pull-request "shields.io")


## 🏷️ Version Tags: vX, vX.Y, vX.Y.Z
This action supports three tag levels for flexible versioning:
- `vX`: latest patch of the major version (e.g., `v1`).
- `vX.Y`: latest patch of the minor version (e.g., `v1.2`).
- `vX.Y.Z`: fixed to a specific release (e.g., `v1.2.3`).




## 📖 API Reference
```yaml
    - name: Run the Action
      uses: devops-infra/action-pull-request@v1.4.0
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        repository: devops-infra/action-pull-request
        repository_path: .
        source_branch: development
        target_branch: master
        title: My pull request
        template: .github/PULL_REQUEST_TEMPLATE.md
        body: "**Automated pull request**"
        reviewer: octocat
        assignee: octocat
        label: enhancement
        create_missing_labels: false
        milestone: My milestone
        project: Engineering Roadmap
        draft: true
        old_string: "<!-- Add your description here -->"
        new_string: "** Automatic pull request**"
        get_diff: true
        ignore_users: "dependabot"
        allow_no_diff: false
        max_body_bytes: 65000
        max_diff_lines: 0
```


### 🔧 Input Parameters
| Input Variable          | Required | Default                       | Description                                                                                                             |
|-------------------------|----------|-------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| `github_token`          | **Yes**  | `""`                          | GitHub token `${{ secrets.GITHUB_TOKEN }}`                                                                              |
| `repository`            | No       | `${{ github.repository }}`    | Target repository in `owner/name` format used for API calls and git remote auth                                         |
| `repository_path`       | No       | `.`                           | Relative path under `GITHUB_WORKSPACE` to the checked-out repository                                                    |
| `source_branch`         | No       | *current branch*              | Name of the source branch                                                                                               |
| `target_branch`         | No       | `master`                      | Name of the target branch. Change it if you use `main`                                                                  |
| `title`                 | No       | *subject of the first commit* | Pull request title                                                                                                      |
| `template`              | No       | `""`                          | Template file location                                                                                                  |
| `body`                  | No       | *list of commits*             | Pull request body                                                                                                       |
| `reviewer`              | No       | `""`                          | Reviewer's username                                                                                                     |
| `assignee`              | No       | `""`                          | Assignee's usernames                                                                                                    |
| `label`                 | No       | `""`                          | Labels to apply, comma separated. GitHub-supported special characters such as `/` work; commas remain the separator.    |
| `create_missing_labels` | No       | `false`                       | Create labels that do not exist yet before PR creation. Existing labels are reused without being refreshed.             |
| `milestone`             | No       | `""`                          | Milestone                                                                                                               |
| `project`               | No       | `""`                          | GitHub Project title to add the pull request to                                                                         |
| `draft`                 | No       | `false`                       | Whether to mark it as a draft                                                                                           |
| `old_string`            | No       | `""`                          | Old string for the replacement in the template                                                                          |
| `new_string`            | No       | `""`                          | New string for the replacement in the template. If not specified, but `old_string` was, it will gather commits subjects |
| `get_diff`              | No       | `false`                       | Whether to replace predefined comments with differences between branches - see details below                            |
| `ignore_users`          | No       | `"dependabot"`                | List of users to ignore, comma separated                                                                                |
| `allow_no_diff`         | No       | `false`                       | Allows to continue on merge commits with no diffs                                                                       |
| `max_body_bytes`        | No       | `65000`                       | Maximum PR body size in bytes before overflow is posted as managed PR comments                                          |
| `max_diff_lines`        | No       | `0`                           | Maximum lines per generated diff section (`0` means unlimited)                                                          |


### 🔐 Required Workflow Permissions

Set explicit job/workflow token permissions when using this action:

```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
```

- `contents: read` is required to read repository state.
- `pull-requests: write` is required to create and update pull requests.
- `issues: write` is required when managed overflow comments are created, updated, or deleted (including cleanup on later runs).
- `issues: write` is also required when `create_missing_labels=true`, because label creation uses the repository labels API.
- Project assignment via `project` requires a token/auth context that `gh` can use with project access.


### 📤 Output Parameters
| Output      | Description                   |
|-------------|-------------------------------|
| `url`       | Pull request URL              |
| `pr_number` | Number of GitHub pull request |


### ➿ How get_diff works
In previous versions occurrences of following strings in a template result with replacing them with list of commits and list of modified files (`<!-- Diff commits -->` and `<!-- Diff files -->`).

Now this action will expect to have three types of comment blocks. Meaning anything between `START` and `END` comment will get replaced. This is especially important when updating pull request with new commits.

* `<!-- Diff summary - START -->` and `<!-- Diff summary - END -->` - show first lines of each commit in the pull request
* `<!-- Diff commits - START -->` and `<!-- Diff commits - END -->` - show graph of commits in the pull request, with authors' info and time
* `<!-- Diff files - START -->` and `<!-- Diff files - END -->` - show list of modified files

When the generated PR body exceeds `max_body_bytes`, the action keeps the main body within the configured size and publishes remaining content in managed PR comments.
Managed comments are updated/deleted on subsequent runs.

Set `max_diff_lines` to cap each generated diff section before insertion.

If your template uses old comment strings it will try to adjust them in the pull request body to a new standard when pull request is created. It will not modify the template.

**CAUTION**: Remember to not use default `fetch-depth` for [actions/checkout](https://github.com/actions/checkout) action. Rather set it to `0` - see example below.


## 💻 Usage Examples

Red areas show fields that can be dynamically expanded based on commits to the current branch.
Blue areas show fields that can be set in action configuration.

![Example screenshot](https://github.com/devops-infra/action-pull-request/raw/master/action-pull-request.png)


### 📝 Basic Example
Create pull request for non-master branches:

```yaml
name: Run the Action
on:
  push:
    branches-ignore: master

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  action-pull-request:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Create pull request
        uses: devops-infra/action-pull-request@v1.4.0
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          title: Automatic pull request
```

### 🔀 Advanced Example
Use first commit as a title and part of body, add a label based on a branch name, add git differences in the template:

```yaml
name: Run the Action
on:
  push:
    branches-ignore: master

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  action-pull-request:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6
        with:
          fetch-depth: 0
          path: repo

      - name: Run the Action
        if: startsWith(github.ref, 'refs/heads/feature')
        uses: devops-infra/action-pull-request@v1.4.0
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          repository: ${{ github.repository }}
          repository_path: repo
          title: ${{ github.event.commits[0].message }}
          assignee: ${{ github.actor }}
          label: automatic,team/platform
          create_missing_labels: true
          project: Engineering Roadmap
          template: .github/PULL_REQUEST_TEMPLATE/FEATURE.md
          old_string: "**Write your description here**"
          new_string: ${{ github.event.commits[0].message }}
          get_diff: true
```

### 🎯 Use specific version
Pick the tag level based on your stability needs:
- `vX.Y.Z`: exact immutable release (most predictable)
- `vX.Y`: latest patch within one minor line
- `vX`: latest patch within one major line

```yaml
name: Run the Action
on:
  push:
    branches-ignore: master

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  action-pull-request:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - uses: devops-infra/action-pull-request@v1.4.0
        id: Pin patch version

      - uses: devops-infra/action-pull-request@v1.4
        id: Pin minor version

      - uses: devops-infra/action-pull-request@v1
        id: Pin major version
```


## 🤝 Contributing
Contributions are welcome! See [CONTRIBUTING](https://github.com/devops-infra/.github/blob/master/CONTRIBUTING.md).
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


## 💬 Support
If you have any questions or need help, please:
- 📝 Create an [issue](https://github.com/devops-infra/action-pull-request/issues)
- 🌟 Star this repository if you find it useful!

## 🧪 End-to-End Validation
Use the manual workflow `.github/workflows/manual-e2e-validate.yml` to validate this action against the centralized E2E repository.

- `mode=ref` validates ref-oriented E2E paths against stable pinned action refs.
- `mode=image` is wired but currently placeholder-only in the central E2E workflow for this action.

CI/CD automation also runs these E2E checks automatically:

- Pull requests: E2E validation runs through reusable org workflows.
- Release branch prepare: E2E validation runs against release candidate refs.
- Release create: E2E validation runs against production release refs.

Example trigger inputs:

```text
mode=ref
```

```text
mode=image
image_tag=v1.2.3-test
```

## Forking
To publish images from a fork, set these variables so Task uses your registry identities:
`DOCKER_USERNAME`, `DOCKER_ORG_NAME`, `GITHUB_USERNAME`, `GITHUB_ORG_NAME`.

Two supported options (environment variables take precedence over `.env`):
```bash
# .env (local only, not committed)
DOCKER_USERNAME=your-dockerhub-user
DOCKER_ORG_NAME=your-dockerhub-org
GITHUB_USERNAME=your-github-user
GITHUB_ORG_NAME=your-github-org
```

```bash
# Shell override
DOCKER_USERNAME=your-dockerhub-user \
DOCKER_ORG_NAME=your-dockerhub-org \
GITHUB_USERNAME=your-github-user \
GITHUB_ORG_NAME=your-github-org \
task docker:build
```

Recommended setup:
- Local development: use a `.env` file.
- GitHub Actions: set repo variables for the four values above, and secrets for `DOCKER_TOKEN` and `GITHUB_TOKEN`.

Publish images without a release:
- Run the `(Manual) Release Create` workflow with `build_only: true` to build and push images without tagging a release.
