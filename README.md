# Fractal

![Fractal Logo](logo.png)

Fractal is an experimental Nix-based framework for declarative configuration of Kubernetes clusters, used at Arctarus for configuration of infrastructure clusters and customer virtual clusters. Fractal makes use of [XNLib](https://github.com/ArctarusLimited/xnlib) as an extended version of the Nix standard library.

## Motivation

Originally, we used pure Kustomize and FluxCD to configure our Kubernetes clusters. As they got more complicated, however, the limitations of this became more clear, and we knew we had to move to a more dynamic framework.

We looked at several configuration frameworks:
- Kapitan worked well, but required more boilerplate than necessary, and was quite slow at generating configuration, increasing time required to do iterative development
- Tanka was also very nice, but the Jsonnet language and its associated dependency management tool `jsonnet-bundler` left much to be desired

Nix brings the best of both worlds of simplicity and customisation; we do lose the Kubernetes "objects" in something like Jsonnet but the benefits outweigh this (and we never had issues with working with pure Yaml config before anyway).

Nix allows code-driven configuration, but most importaresourcesntly (and this was one of the most enticing features) it has the ability to perform builds built right in, as its original purpose was package management! This means we can easily have functions to do things like build Kustomizations or Helm charts and cache the results of those builds, significantly improving compile times over the previously mentioned tools.

There is an existing Nix-based tool `kubenix`, but we opted to build something completely new as the former to us was very overengineered. Our goal is to keep the code of Fractal simple and maintainable. We also delegate schema validation to external tools during the build phase to avoid implementing any complex logic.

## Architecture

Like NixOS, Fractal uses *modules* to define configuration. A Fractal module represents a set of resources in the cluster, such as cert-manager or metrics-server.

Modules are divided into different categories, which is used to enforce an order of operations for deployment purposes.
- `crds`, the cluster Custom Resource Definitions, are deployed first.
- `operators`, Cluster Operators are deployed before `features` in case their usage is required.
- `features`, the cluster's infrastructure layer.
- `services`, finally, the services that run on top of the cluster.
