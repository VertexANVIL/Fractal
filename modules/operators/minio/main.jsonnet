local c = import "lib/common.libsonnet";
local i = std.extVar("inputs");

{
    local helmRelease = c.flux.helm.v2beta1.helmRelease,

    release: helmRelease.new(i.component.name)
        + helmRelease.spec.withInterval("5m")
        + helmRelease.spec.withValues({
            # Do not autocreate
            tenants: {}
        })
        + helmRelease.spec.chart.spec.withChart("minio-operator")
        + helmRelease.spec.chart.spec.withVersion(i.component.version)
        + helmRelease.spec.chart.spec.sourceRef.withKind("HelmRepository")
        + helmRelease.spec.chart.spec.sourceRef.withName("minio")
        + helmRelease.spec.chart.spec.sourceRef.withNamespace("flux-system")
        + helmRelease.spec.install.withCrds("Skip")
        + helmRelease.spec.install.remediation.withRemediateLastFailure(true)
        + helmRelease.spec.upgrade.withCrds("Skip")
        + helmRelease.spec.upgrade.remediation.withRemediateLastFailure(true)
}
