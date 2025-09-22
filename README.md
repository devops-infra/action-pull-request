# 🚀 GitHub Action for creating Pull Requests

**GitHub Action that will create a pull request from the currently selected branch.**

**Useful in combination with my other action [devops-infra/action-commit-push](https://github.com/devops-infra/action-commit-push).**


## 📦 Available on
Dockerized as [devopsinfra/action-pull-request](https://hub.docker.com/repository/docker/devopsinfra/action-pull-request).
Built from [ghcr.io/devops-infra//action-pull-request](https://github.com/devops-infra/pkgs/container/template-action).


## ✨ Features
* Creates pull request if triggered from a current branch or any specified by `source_branch` to a `target_branch`
* Title and body of a pull request can be specified with `title` and `body`
* Can assign `assignee`, `reviewer`, one or more `label`, a `milestone` or mark it as a `draft`
* Can replace any `old_string` inside a pull request template with a `new_string`. Or put commits' subjects in place of `old_string`
* When `get_diff` is `true` will add list of commits in place of `<!-- Diff commits -->` and list of modified files in place of `<!-- Diff files -->` in a pull request template
* When `allow_no_diff` is set to true will continue execution and create pull request even if both branches have no differences, e.g. having only a merge commit
* Supports both `amd64` and `arm64` architectures


## Badge swag
[
![GitHub repo](https://img.shields.io/badge/GitHub-devops--infra%2Faction--pull--request-blueviolet.svg?style=plastic&logo=github)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/devops-infra/action-pull-request?color=blueviolet&label=Code%20size&style=plastic&logo=github)
![GitHub last commit](https://img.shields.io/github/last-commit/devops-infra/action-pull-request?color=blueviolet&logo=github&style=plastic&label=Last%20commit)
![GitHub license](https://img.shields.io/github/license/devops-infra/action-pull-request?color=blueviolet&logo=github&style=plastic&label=License)
](https://github.com/devops-infra/action-pull-request "shields.io")
<br>
[
![DockerHub](https://img.shields.io/badge/DockerHub-devopsinfra%2Faction--pull--request-blue.svg?style=plastic&logo=docker)
![Docker version](https://img.shields.io/docker/v/devopsinfra/action-pull-request?color=blue&label=Version&logo=docker&style=plastic)
![Image size](https://img.shields.io/docker/image-size/devopsinfra/action-pull-request/latest?label=Image%20size&style=plastic&logo=docker)
![Docker Pulls](https://img.shields.io/docker/pulls/devopsinfra/action-pull-request?color=blue&label=Pulls&logo=docker&style=plastic)
](https://hub.docker.com/r/devopsinfra/action-pull-request "shields.io")


## 📖 API Reference

```yaml
    - name: Run the Action
      uses: devops-infra/action-pull-request@v0.6
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        source_branch: development
        target_branch: master
        title: My pull request
        template: .github/PULL_REQUEST_TEMPLATE.md
        body: "**Automated pull request**"
        reviewer: octocat
        assignee: octocat
        label: enhancement
        milestone: My milestone
        draft: true
        old_string: "<!-- Add your description here -->"
        new_string: "** Automatic pull request**"
        get_diff: true
        ignore_users: "dependabot"
        allow_no_diff: false
```


### 🔧 Input Parameters

| Input Variable | Required | Default                       | Description                                                                                                             |
|----------------|----------|-------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| github_token   | **Yes**  | `""`                          | GitHub token `${{ secrets.GITHUB_TOKEN }}`                                                                              |
| source_branch  | No       | *current branch*              | Name of the source branch                                                                                               |
| target_branch  | No       | `master`                      | Name of the target branch. Change it if you use `main`                                                                  |
| title          | No       | *subject of the first commit* | Pull request title                                                                                                      |
| template       | No       | `""`                          | Template file location                                                                                                  |
| body           | No       | *list of commits*             | Pull request body                                                                                                       |
| reviewer       | No       | `""`                          | Reviewer's username                                                                                                     |
| assignee       | No       | `""`                          | Assignee's usernames                                                                                                    |
| label          | No       | `""`                          | Labels to apply, comma separated                                                                                        |
| milestone      | No       | `""`                          | Milestone                                                                                                               |
| draft          | No       | `false`                       | Whether to mark it as a draft                                                                                           |
| old_string     | No       | `""`                          | Old string for the replacement in the template                                                                          |
| new_string     | No       | `""`                          | New string for the replacement in the template. If not specified, but `old_string` was, it will gather commits subjects |
| get_diff       | No       | `false`                       | Whether to replace predefined comments with differences between branches - see details below                            |
| ignore_users   | No       | `"dependabot"`                | List of users to ignore, comma separated                                                                                |
| allow_no_diff  | No       | `false`                       | Allows to continue on merge commits with no diffs                                                                       |


### 🔧 Input Parameters

| Output    | Description                   |
|-----------|-------------------------------|
| url       | Pull request URL              |
| pr_number | Number of GitHub pull request |


### ➿ How get_diff works

In previous versions occurrences of following strings in a template result with replacing them with list of commits and list of modified files (`<!-- Diff commits -->` and `<!-- Diff files -->`).

Now this action will expect to have three types of comment blocks. Meaning anything between `START` and `END` comment will get replaced. This is especially important when updating pull request with new commits.

* `<!-- Diff summary - START -->` and `<!-- Diff summary - END -->` - show first lines of each commit in the pull request
* `<!-- Diff commits - START -->` and `<!-- Diff commits - END -->` - show graph of commits in the pull request, with authors' info and time
* `<!-- Diff files - START -->` and `<!-- Diff files - END -->` - show list of modified files

If your template uses old comment strings it will try to adjust them in the pull request body to a new standard when pull request is created. It will not modify the template.

**CAUTION**: Remember to not use default `fetch-depth` for [actions/checkout](https://github.com/actions/checkout) action. Rather set it to `0` - see example below.


## 💻 Usage Examples

Red areas show fields that can be dynamically expanded based on commits to the current branch.
Blue areas show fields that can be set in action configuration.

![Example screenshot](https://github.com/devops-infra/action-pull-request/raw/master/action-pull-request.png)


### 📝 Basic Example

Create pull request for non-master branches:

```yaml
name: Run the Action on each commit
on:
  push:
    branches-ignore: master
jobs:
  action-pull-request:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      - name: Create pull request
        uses: devops-infra/action-pull-request@v0.6
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          title: Automatic pull request
```


### 🔀 Advanced Example

Use first commit as a title and part of body, add a label based on a branch name, add git differences in the template:

```yaml
name: Run the Action on each commit
on:
  push:
    branches-ignore: master
jobs:
  action-pull-request:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run the Action
        if: startsWith(github.ref, 'refs/heads/feature')
        uses: devops-infra/action-pull-request@v0.6
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          title: ${{ github.event.commits[0].message }}
          assignee: ${{ github.actor }}
          label: automatic,feature
          template: .github/PULL_REQUEST_TEMPLATE/FEATURE.md
          old_string: "**Write your description here**"
          new_string: ${{ github.event.commits[0].message }}
          get_diff: true
```


## 🏷️ Version Tags: vX, vX.Y, vX.Y.Z

This action supports three tag levels for flexible versioning:

- **`vX`**: Always points to the latest patch of a major version (e.g., `v1` → `v1.2.3`).  
  _Benefit: Get all latest fixes for a major version automatically._

- **`vX.Y`**: Always points to the latest patch of a minor version (e.g., `v1.2` → `v1.2.3`).  
  _Benefit: Stay on a minor version, always up-to-date with bugfixes._

- **`vX.Y.Z`**: Fixed to a specific release (e.g., `v1.2.3`).  
  _Benefit: Full reproducibility—never changes._

**Use the tag depth that matches your stability needs.**


## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. Refer to the [CONTRIBUTING](https://github.com/devops-infra/.github/blob/master/CONTRIBUTING.md) for guidelines.


## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


## 💬 Support

If you have any questions or need help, please:
- 📝 Create an [issue](https://github.com/devops-infra/template-action/issues)
- 🌟 Star this repository if you find it useful!
