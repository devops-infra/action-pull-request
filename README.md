# GitHub Action for creating Pull Requests

**GitHub Action that will create a pull request from the current branch.**

Useful in combination with my other action [devops-infra/action-commit-push](https://github.com/devops-infra/action-commit-push).

Dockerized as [devopsinfra/action-pull-request](https://hub.docker.com/repository/docker/christophshyper/action-pull-request).

Features:
* Creates pull request if triggered from a current branch or any specified by `source_branch` to a `target_branch`.
* Title and body of a pull request can be specified with `title` and `body`.
* Can assign `assignee`, `reviewer`, one or more `label`, a `milestone` or mark it as a `draft`
* Can replace any `old_string` inside a pull request template with a `new_string`. Or put commits' subjects in place of `old_string`.
* When `get_diff` is `true` will add list of commits in place of `<!-- Diff commits -->` and list of modified files in place of `<!-- Diff files -->` in a pull request template.


## Badge swag
[![Master branch](https://github.com/devops-infra/action-pull-request/workflows/Master%20branch/badge.svg)](https://github.com/devops-infra/action-pull-request/actions?query=workflow%3A%22Master+branch%22)
[![Other branches](https://github.com/devops-infra/action-pull-request/workflows/Other%20branches/badge.svg)](https://github.com/devops-infra/action-pull-request/actions?query=workflow%3A%22Other+branches%22)
<br>
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


## Reference

```yaml
    - name: Run the Action
      uses: devops-infra/action-pull-request@master
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
```


| Input Variable | Required | Default                       | Description                                                                                                              |
| -------------- | -------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| github_token   | Yes      | `""`                          | GitHub token `${{ secrets.GITHUB_TOKEN }}`                                                                               |
| assignee       | No       | `""`                          | Assignee's usernames.                                                                                                    |
| body           | No       | *list of commits*             | Pull request body.                                                                                                       |
| draft          | No       | `false`                       | Whether to mark it as a draft.                                                                                           |
| get_diff       | No       | `false`                       | Whether to replace predefined comments with differences between branches - see details below.                            |
| ignore_users   | No       | `"dependabot"`                | List of users to ignore, coma separated.                                                                                 |
| label          | No       | `""`                          | Labels to apply, coma separated.                                                                                         |
| milestone      | No       | `""`                          | Milestone.                                                                                                               |
| new_string     | No       | `""`                          | New string for the replacement in the template. If not specified, but `old_string` was, it will gather commits subjects. |
| old_string     | No       | `""`                          | Old string for the replacement in the template.                                                                          |
| reviewer       | No       | `""`                          | Reviewer's username.                                                                                                     |
| source_branch  | No       | *current branch*              | Name of the source branch.                                                                                               |
| target_branch  | No       | `master`                      | Name of the target branch. Change it if you use `main`.                                                                  |
| template       | No       | `""`                          | Template file location.                                                                                                  |
| title          | No       | *subject of the first commit* | Pull request title.                                                                                                      |


| Outputs | Description      |
| ------- | ---------------- |
| url     | Pull request URL |


### How get_diff works
In previous versions occurrences of following strings in a template result with replacing them with list of commits and list of modified files (`<!-- Diff commits -->` and `<!-- Diff files -->`).

Now this action will expect to have three types of comment blocks. Meaning anything between `START` and `END` comment will get replaced. This is especially important when updating pull request with new commits.

* `<!-- Diff summary - START -->` and `<!-- Diff summary - END -->` - show first lines of each commit the pull requests
* `<!-- Diff commits - START -->` and `<!-- Diff commits - END -->` - show graph of commits in the pull requests, with authors' info and time
* `<!-- Diff files - START -->` and `<!-- Diff files - END -->` - show list of modified files

If your template uses old comment strings it will try to adjust them in the pull request body to a new standard when pull request is created. It will not modify the template.

**CAUTION**
Remember to not use default `fetch-depth` for [actions/checkout](https://github.com/actions/checkout) action. Rather set it to `0` - see example below.


## Examples

Red ares show fields that can be dynamically expanded based on commits to the current branch.
Blue areas show fields that can be set in action configuration.
![Example screenshot](https://github.com/devops-infra/action-pull-request/raw/master/action-pull-request.png)


Create pull request for non-master branches
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
        uses: actions/checkout@v2
      - name: Create pull request
        uses: devops-infra/action-pull-request@master
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          title: Automatic pull request
```

Use first commit as a title and part of body, add a label based on a branch name, add git differences in the template
```yaml
name: Run the Action on each commit
on:
  push:
    branches-ignore: master
jobs:
  action-pull-request:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repoistory
        uses: actions/checkout@v2
        with:
          fetch-depth: 0
      - name: Run the Action
        if: startsWith(github.ref, 'refs/heads/feature')
        uses: devops-infra/action-pull-request@master
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          title: ${{ github.event.commits[0].message }}
          assignee: ${{ github.actor }}
          label: automatic,feature
          template: .github/PULL_REQUEST_TEMPLATE/FEATURE.md
          old_string: "**Write you description here**"
          new_string: ${{ github.event.commits[0].message }}
          get_diff: true
```
