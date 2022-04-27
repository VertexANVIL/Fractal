{ config, lib, ... }: let
    cfg = config.components.flux-cd;
    inherit (lib) mapAttrs;

    sources = {
        bitnami = "https://charts.bitnami.com/bitnami";
        bootc = "https://charts.boo.tc";
        gitlab = "https://charts.gitlab.io";
        grafana = "https://grafana.github.io/helm-charts";
        hashicorp = "https://helm.releases.hashicorp.com";
        ingress-nginx = "https://kubernetes.github.io/ingress-nginx";
        jetstack = "https://charts.jetstack.io";
        k8s-at-home = "https://k8s-at-home.com/charts";
        kubernetes-dashboard = "https://kubernetes.github.io/dashboard";
        loft = "https://charts.loft.sh";
        minio = "https://operator.min.io";
        mittwald = "https://helm.mittwald.de";
        openebs = "https://openebs.github.io/charts";
        openebs-lvm-localpv = "https://openebs.github.io/lvm-localpv";
        pomerium = "https://helm.pomerium.io";
        prometheus-community = "https://prometheus-community.github.io/helm-charts";
        requarks = "https://charts.js.wiki";
        ricoberger = "https://ricoberger.github.io/helm-charts";
        sealed-secrets = "https://bitnami-labs.github.io/sealed-secrets";
        t3n = "https://storage.googleapis.com/t3n-helm-charts";
    };
in {
    config = {
        components.flux-cd.sources.helm = mapAttrs (n: v: {
            spec = {
                url = v;
                interval = "30m";
            }; 
        }) sources;
    };
}
