# GitHub Action for creating Pull Requests

GitHub Action that will create a pull request from the current directory.

Useful in combination with my other action [ChristophShyper/action-commit-push](https://github.com/ChristophShyper/action-commit-push).

Dockerized as [christophshyper/action-pull-request](https://hub.docker.com/repository/docker/christophshyper/action-pull-request).

**Work in Progress.**


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
      env:
        bar: barfoo
      with:
        baz: bazbar
```

Environment Variable | Required |Description
:--- | :---: | :---
bar | No | Environment variable for `env: ...`.

Input Variable | Required | Default |Description
:--- | :---: | :---: | :---
baz | No | `bazbar` | Some input variable for `with: ...`.

Outputs | Description
:--- | :---
foobar | Output from action.


## Examples

Run the Action via GitHub.
```yaml
name: Run the Action on each commit
on:
  push
jobs:
  action-pull-request:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v2
      - name: Run the Action
        uses: ChristophShyper/action-pull-request@master
```

Run the Action via DockerHub.
```yaml
name: Run the Action on each commit
on:
  push
jobs:
  action-pull-request:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repoistory
        uses: actions/checkout@v2
      - name: Run the Action
        uses: docker://christophshyper/action-pull-request:latest
        env:
          bar: foo
        with:
          bar: baz
```
