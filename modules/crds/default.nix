{ lib, ... }: let
    inherit (lib) kube;
in {
    config.resources.crds = kube.compileKustomization ./.;
}
