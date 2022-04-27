local c = import "lib/common.libsonnet";
local i = std.extVar("inputs");

// define configuration inputs
local cluster = i.cluster;
local component = i.component;

local resources = {
    _config:: {
        dns: "ui.%s" % cluster.dns
    },

    cert: c.certs.nogroup.v1.certificate.new("kubernetes-dashboard") {
        spec: {
            secretName: "kubernetes-dashboard-tls",
            issuerRef: {
                name: "vault",
                kind: "ClusterIssuer"
            },
            commonName: $._config.dns,
            dnsNames: [$._config.dns]
        }
    },

    release: c.flux.helm.v2beta1.helmRelease.new("kubernetes-dashboard") {
        spec: {
            chart: {
                spec: {
                    chart: "kubernetes-dashboard",
                    version: "5.0.4",
                    sourceRef: {
                        kind: "HelmRepository",
                        name: "kubernetes-dashboard",
                        namespace: "flux-system"
                    },
                },
            },
            interval: "1h0m0s",
            releaseName: "kubernetes-dashboard",
            install: {
                remediation: {
                    remediateLastFailure: true
                },
            },
            upgrade: {
                remediation: {
                    remediateLastFailure: true
                },
            },
            values: {
                ingress: {
                    enabled: true,
                    hosts: [$._config.dns],
                    tls: [{
                        secretName: "kubernetes-dashboard-tls",
                        hosts: [$._config.dns],
                    }],
                },
            },
        }
    },

    serviceAccount: c.kube.core.v1.serviceAccount.new("kubernetes-dashboard-admin"),
};

c.kk.replaceNamespaces(resources, "infra-system")
