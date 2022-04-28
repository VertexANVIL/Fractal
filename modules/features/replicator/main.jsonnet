local c = import "lib/common.libsonnet";
local i = std.extVar("inputs");

{
    local helmRelease = c.flux.helm.v2beta1.helmRelease,

    release: helmRelease.new(i.component.name)
        + helmRelease.spec.withInterval("1h0m0s")
        + helmRelease.spec.chart.spec.withChart("kubernetes-replicator")
        + helmRelease.spec.chart.spec.withVersion(i.component.version)
        + helmRelease.spec.chart.spec.sourceRef.withKind("HelmRepository")
        + helmRelease.spec.chart.spec.sourceRef.withName("mittwald")
        + helmRelease.spec.chart.spec.sourceRef.withNamespace("flux-system")
        + helmRelease.spec.install.remediation.withRemediateLastFailure(true)
        + helmRelease.spec.upgrade.remediation.withRemediateLastFailure(true)
}
