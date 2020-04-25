# GitHub Action for creating Pull Requests

GitHub Action that will create a pull request from the current branch.

Useful in combination with my other action [ChristophShyper/action-commit-push](https://github.com/ChristophShyper/action-commit-push).

Dockerized as [christophshyper/action-pull-request](https://hub.docker.com/repository/docker/christophshyper/action-pull-request).

Features:
* Creates pull request if triggered from a current branch or any specified by `source_branch` to a `target_branch`.
* Title and body of a pull request can be specified with `title` and `body`.
* Can assign `assignee`, `reviewer`, one or more `label`, a `milestone` or mark it as a `draft`
* Can replace any `old_string` inside a pull request template with a `new_string`.
* When `get_diff` is `true` will add list of commits in place of `<!-- Diff commits -->` and list of modified files in place of `<!-- Diff files -->` in a pull request template.


## Badge swag
[
![GitHub](https://img.shields.io/badge/github-devops--infra%2Faction--pull--request-brightgreen.svg?style=flat-square&logo=github)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/devops-infra/action-pull-request?color=brightgreen&label=Code%20size&style=flat-square&logo=github)
![GitHub last commit](https://img.shields.io/github/last-commit/devops-infra/action-pull-request?color=brightgreen&label=Last%20commit&style=flat-square&logo=github)
](https://github.com/devops-infra/action-pull-request "shields.io")
[![Push to master](https://github.com/devops-infra/action-pull-request/workflows/Push%20to%20master/badge.svg)](https://github.com/devops-infra/action-pull-request/actions?query=workflow%3A%22Push+to+master%22)
[![Push to other](https://github.com/devops-infra/action-pull-request/workflows/Push%20to%20other/badge.svg)](https://github.com/devops-infra/action-pull-request/actions?query=workflow%3A%22Push+to+other%22)
<br>
[
![DockerHub](https://img.shields.io/badge/docker-christophshyper%2Faction--pull--request-blue.svg?style=flat-square&logo=docker)
![Dockerfile size](https://img.shields.io/github/size/christophshyper/action-pull-request/Dockerfile?label=Dockerfile%20size&style=flat-square&logo=docker)
![Image size](https://img.shields.io/docker/image-size/christophshyper/action-pull-request/latest?label=Image%20size&style=flat-square&logo=docker)
![Docker Pulls](https://img.shields.io/docker/pulls/christophshyper/action-pull-request?color=blue&label=Pulls&logo=docker&style=flat-square)
![Docker version](https://img.shields.io/docker/v/christophshyper/action-pull-request?color=blue&label=Version&logo=docker&style=flat-square)
](https://hub.docker.com/r/christophshyper/action-pull-request "shields.io")


## Reference

```yaml
    - name: Run the Action
      uses: devops-infra/action-pull-request@master
      with:
        github_token: "${{ secrets.GITHUB_TOKEN }}"
        source_branch: development
        target_branch: master
        title: My pull request
        template: ".github/PULL_REQUEST_TEMPLATE.md"
        body: "**Automated pull request**"
        reviewer: octocat
        assignee: octocat
        label: enhancement
        milestone: My milestone
        draft: true
        old_string: "<!-- Add your description here -->"
        new_string: "** Automatic pull request**"
        get_diff: true
```


Input Variable | Required | Default |Description
:--- | :---: | :---: | :---
github_token | Yes | `""` | GitHub token `${{ secrets.GITHUB_TOKEN }}`
source_branch | No | *current branch* | Name of the source branch.
target_branch | No | `master` | Name of the target branch.
title | No | `""` | Pull request title.
template | No | `""` | Template file location.
body | No | `""` | Pull request body.
reviewer | No | `""` | Reviewer's username.
assignee | No | `""` | Assignee's usernames.
label | No | `""` | Labels to apply, coma separated.
milestone | No | `""` | Milestone.
draft | No | `false` | Whether to mark it as a draft.
old_string | No | `""` | Old string for the replacement in the template.
new_string | No | `""` | New string for the replacement in the template.
get_diff | No | `false` | Whether to replace `<!-- Diff commits -->` and `<!-- Diff files -->` with differences between branches.


Outputs | Description
:--- | :---
url | Pull request URL


## Examples

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
        uses: actions/checkout@master
      - name: Create pull request
        uses: devops-infra/action-pull-request@master
        with:
          github_token: "${{ secrets.GITHUB_TOKEN }}"
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
        uses: actions/checkout@master
      - name: Run the Action
        if: startsWith(github.ref, 'refs/heads/feature')
        uses: devops-infra/action-pull-request@master
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          title: "${{ github.event.commits[0].message }}"
          assignee: "${{ github.actor }}"
          label: automatic,feature
          template: .github/PULL_REQUEST_TEMPLATE/FEATURE.md
          old_string: "**Write you description here**"
          new_string: "${{ github.event.commits[0].message }}"
          get_diff: true
```
