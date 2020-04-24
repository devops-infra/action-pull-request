# GitHub Action for creating Pull Requests

GitHub Action that will create a pull request from the current branch.

Useful in combination with my other action [ChristophShyper/action-commit-push](https://github.com/ChristophShyper/action-commit-push).

Dockerized as [christophshyper/action-pull-request](https://hub.docker.com/repository/docker/christophshyper/action-pull-request).


## Badge swag
[
![GitHub](https://img.shields.io/badge/github-ChristophShyper%2Faction--pull--request-brightgreen.svg?style=flat-square&logo=github)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/christophshyper/action-pull-request?color=brightgreen&label=Code%20size&style=flat-square&logo=github)
![GitHub last commit](https://img.shields.io/github/last-commit/christophshyper/action-pull-request?color=brightgreen&label=Last%20commit&style=flat-square&logo=github)
](https://github.com/christophshyper/action-pull-request "shields.io")
[![Push to master](https://img.shields.io/github/workflow/status/christophshyper/action-pull-request/Push%20to%20master?color=brightgreen&label=Master%20branch&logo=github&style=flat-square)
](https://github.com/ChristophShyper/action-pull-request/actions?query=workflow%3A%22Push+to+master%22)
[![Push to other](https://img.shields.io/github/workflow/status/christophshyper/action-pull-request/Push%20to%20other?color=brightgreen&label=Pull%20requests&logo=github&style=flat-square)
](https://github.com/ChristophShyper/action-pull-request/actions?query=workflow%3A%22Push+to+other%22)
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
      uses: ChristophShyper/action-pull-request@master
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
draft | No | `""` | Whether to mark it as a draft.
old_string | No | `""` | Old string for the replacement in the template.
new_string | No | `""` | New string for the replacement in the template.

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
        uses: actions/checkout@v2
      - name: Create pull request
        uses: ChristophShyper/action-pull-request@master
        with:
          github_token: "${{ secrets.GITHUB_TOKEN }}"
          title: Automatic pull request
```

Use first commit as a title and add a label based on a branch name
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
      - name: Run the Action
        if: startsWith(github.ref, 'refs/heads/enhancement')
        uses: ChristophShyper/action-pull-request@master
        with:
          title: ${{ github.event.commits[0].message }}
          label: enhancement
```
