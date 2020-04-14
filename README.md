# GitHub Action template

Template repository for GitHub Actions. 

Dockerized as [christophshyper/template-action](https://hub.docker.com/repository/docker/christophshyper/template-action).

**This is just a template repository.**


## Badge swag
[
![GitHub](https://img.shields.io/badge/github-ChristophShyper%2Ftemplate--action-brightgreen.svg?style=flat-square&logo=github)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/christophshyper/template-action?color=brightgreen&label=Code%20size&style=flat-square&logo=github)
![GitHub last commit](https://img.shields.io/github/last-commit/christophshyper/template-action?color=brightgreen&label=Last%20commit&style=flat-square&logo=github)
](https://github.com/christophshyper/template-action "shields.io")
[![Push to master](https://img.shields.io/github/workflow/status/christophshyper/template-action/Push%20to%20master?color=brightgreen&label=Master%20branch&logo=github&style=flat-square)
](https://github.com/ChristophShyper/template-action/actions?query=workflow%3A%22Push+to+master%22)
[![Push to other](https://img.shields.io/github/workflow/status/christophshyper/template-action/Push%20to%20other?color=brightgreen&label=Pull%20requests&logo=github&style=flat-square)
](https://github.com/ChristophShyper/template-action/actions?query=workflow%3A%22Push+to+other%22)
<br>
[
![DockerHub](https://img.shields.io/badge/docker-christophshyper%2Ftemplate--action-blue.svg?style=flat-square&logo=docker)
![Dockerfile size](https://img.shields.io/github/size/christophshyper/template-action/Dockerfile?label=Dockerfile%20size&style=flat-square&logo=docker)
![Image size](https://img.shields.io/docker/image-size/christophshyper/template-action/latest?label=Image%20size&style=flat-square&logo=docker)
![Docker Pulls](https://img.shields.io/docker/pulls/christophshyper/template-action?color=blue&label=Pulls&logo=docker&style=flat-square)
![Docker version](https://img.shields.io/docker/v/christophshyper/template-action?color=blue&label=Version&logo=docker&style=flat-square)
](https://hub.docker.com/r/christophshyper/template-action "shields.io")


## Reference

```yaml
    - name: Run the Action
      uses: ChristophShyper/template-action@master
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
  template-action:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v2
      - name: Run the Action
        uses: ChristophShyper/template-action@master
```

Run the Action via DockerHub.
```yaml
name: Run the Action on each commit
on:
  push
jobs:
  template-action:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repoistory
        uses: actions/checkout@v2
      - name: Run the Action
        uses: docker://christophshyper/template-action:latest
        env:
          bar: foo
        with:
          bar: baz
```
