local c = import "lib/common.libsonnet";
local i = std.extVar("inputs");

{
    local helmRelease = c.flux.helm.v2beta1.helmRelease,

    _values:: {
        controller: {
            config: {
                # fixes "upstream sent too big header while reading response header from upstream"
                "proxy-buffer-size": "16k"
            }
        },

        ingressClassResource: {
            default: true
        },

        metrics: {
            enabled: true,
            serviceMonitor: {
                enabled: true
            }
            // prometheusRule: {
            //     enabled: true
            // }
        },  
    },

    release: helmRelease.new(i.component.name)
        + helmRelease.spec.withValues($._values)
        + helmRelease.spec.chart.spec.withChart("ingress-nginx")
        + helmRelease.spec.chart.spec.withVersion(i.component.version)
        + helmRelease.spec.chart.spec.sourceRef.withKind("HelmRepository")
        + helmRelease.spec.chart.spec.sourceRef.withName("ingress-nginx")
        + helmRelease.spec.chart.spec.sourceRef.withNamespace("flux-system")
        + helmRelease.spec.install.remediation.withRemediateLastFailure(true)
        + helmRelease.spec.upgrade.remediation.withRemediateLastFailure(true)
}
