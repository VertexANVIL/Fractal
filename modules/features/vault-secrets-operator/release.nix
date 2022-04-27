{ config, lib, ... }: let
    cfg = config.features.vault-secrets-operator;
in {
    apiVersion = "helm.toolkit.fluxcd.io/v2beta1";
    kind = "HelmRelease";

    metadata = {
        name = cfg.name;
    };

    spec = {
        interval = "1h0m0s";
        releaseName = cfg.name;

        install.remediation.remediateLastFailure = true;
        upgrade.remediation.remediateLastFailure = true;

        chart.spec = {
            version = cfg.version;
            chart = "vault-secrets-operator";

            sourceRef = {
                kind = "HelmRepository";
                name = "ricoberger";
                namespace = "flux-system";
            };
        };

        values = {
            crd.create = false;

            environmentVars = [{
                name = "VAULT_CACERT";
                value = "/etc/vault-secrets-operator/ca.pem";
            }];

            image.volumeMounts = [{
                name = "ca";
                mountPath = "/etc/vault-secrets-operator";
            }];

            serviceMonitor.enabled = true;

            vault = {
                address = "https://vault.arctarus.net";
                authMethod = "kubernetes";
                kubernetesPath = "auth/k8s-${config.cluster.name}";
                kubernetesRole = "k8s-${config.cluster.name}-secrets-operator";
            };

            volumes = [{
                name = "ca";
                configMap = {
                    name = "vault-metadata";
                    items = [{
                        key = "vault.ca";
                        path = "ca.pem";
                    }];
                };
            }];
        };
    };
}
