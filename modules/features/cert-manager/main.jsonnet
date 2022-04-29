local c = import "lib/common.libsonnet";
local i = std.extVar("inputs");

{
    local helmRelease = c.flux.helm.v2beta1.helmRelease,

    _values:: {
        prometheus: {
            servicemonitor: {
                enabled: true
            }
        },

        volumes: [{
            name: "ca-certificates",
            configMap: {
                name: "trusted-ca-certificates"
            }
        }],

        volumeMounts: [{
            name: "ca-certificates",
            mountPath: "/etc/ssl/certs/ca-certificates.crt",
            subPath: "ca-certificates.crt",
            readOnly: true
        }]
    },

    issuer: c.kk.clusterIssuer.new("selfsigned") {
        spec: { selfSigned: {} }
    },

    release: helmRelease.new(i.component.name)
        + helmRelease.spec.withValues($._values)
        + helmRelease.spec.chart.spec.withChart("cert-manager")
        + helmRelease.spec.chart.spec.withVersion(i.component.version)
        + helmRelease.spec.chart.spec.sourceRef.withKind("HelmRepository")
        + helmRelease.spec.chart.spec.sourceRef.withName("jetstack")
        + helmRelease.spec.chart.spec.sourceRef.withNamespace("flux-system")
        + helmRelease.spec.install.remediation.withRemediateLastFailure(true)
        + helmRelease.spec.upgrade.remediation.withRemediateLastFailure(true),
    
    serviceAccount: c.kk.serviceAccount.new("cert-manager-issuer")
}
