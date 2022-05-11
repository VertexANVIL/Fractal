local utils = import "lib/utils.libsonnet";
local inputs = std.extVar("inputs");

{
    _local:: {
        # imports go here, modify if version gets bumped
        # TODO: this would ideally be dependent on cluster version and such
        kube: import "vendor/github.com/jsonnet-libs/k8s-libsonnet/1.23/main.libsonnet",
        flux: import "vendor/github.com/jsonnet-libs/fluxcd-libsonnet/0.30.2/main.libsonnet",
        certs: import "vendor/github.com/jsonnet-libs/cert-manager-libsonnet/1.7/main.libsonnet",
        prom: import "vendor/github.com/jsonnet-libs/kube-prometheus-libsonnet/0.10/main.libsonnet",
        tanka: import "vendor/github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet"
    },

    kube: $._local.kube + {
        networking+: {
            v1+: {
                networkPolicyIngressRule+: {
                    withFromCidrs(cidrs):: super.withFrom([
                        $.kk.networkPolicyPeer.ipBlock.withCidr(cidr)
                        for cidr in cidrs
                    ])
                }
            }
        }
    },

    flux: $._local.flux,
    certs: $._local.certs,
    prom: $._local.prom,
    kapitan: $._local.kapitan,
    tanka: $._local.tanka,

    kk: {
        # common aliases for k8s resources
        configMap: $.kube.core.v1.configMap,
        container: $.kube.core.v1.container,
        containerPort: $.kube.core.v1.containerPort,
        deployment: $.kube.apps.v1.deployment,
        ingress: $.kube.networking.v1.ingress,
        localObjectReference: $.kube.core.v1.localObjectReference,
        namespace: $.kube.core.v1.namespace,
        networkPolicy: $.kube.networking.v1.networkPolicy,
        networkPolicyIngressRule: $.kube.networking.v1.networkPolicyIngressRule,
        networkPolicyPeer: $.kube.networking.v1.networkPolicyPeer,
        networkPolicyPort: $.kube.networking.v1.networkPolicyPort,
        objectMeta: $.kube.meta.v1.objectMeta,
        persistentVolumeClaim: $.kube.core.v1.persistentVolumeClaim,
        resourceRequirements: $.kube.core.v1.resourceRequirements,
        secret: $.kube.core.v1.secret,
        service: $.kube.core.v1.service,
        serviceAccount: $.kube.core.v1.serviceAccount,
        servicePort: $.kube.core.v1.servicePort,
        storageClass: $.kube.storage.v1.storageClass,
        volume: $.kube.core.v1.volume,
        volumeMount: $.kube.core.v1.volumeMount,

        # cert-manager stuff
        certificate: $.certs.nogroup.v1.certificate,
        certificateRequest: $.certs.nogroup.v1.certificateRequest,
        clusterIssuer: $.certs.nogroup.v1.clusterIssuer,
        issuer: $.certs.nogroup.v1.issuer,

        # prometheus stuff
        podMonitor: $.prom.monitoring.v1.podMonitor,
        serviceMonitor: $.prom.monitoring.v1.serviceMonitor,

        # returns whether the specified object is a Kubernetes resource
        isResource(data)::
            std.objectHas(data, "kind")
            && std.objectHas(data, "metadata")
            && std.objectHas(data.metadata, "name"),

        # applies a function recursively to Kubernetes resources
        applyRecursive(data, fn)::
            local recurse = function(data, fn, i) if std.isObject(data) then
                if $.kk.isResource(data) then fn(data) else if i <= 10 then
                    std.mapWithKey(function(_, v) recurse(v, fn, i+1), data)
                else data
            else data;
        recurse(data, fn, 0),

        # extracts Kubernetes resources recursively
        #extractResources(data)::
        #    local recurse = function(data, i) std.flattenArrays(
        #        if std.isArray(data) then std.map(function(v) recurse(v, i+1), data)
        #        else if std.isObject(data) then if $.kk.isResource(data) then [data]
        #        else std.map(function(v) recurse(v, i+1), std.objectValues(data))
        #        else []
        #    );
        #recurse(data, 0),

        # removes CRDs from an attribute set of resources
        removeCrds(data):: $.kk.filterObject(data,
            function(v) v.kind != "CustomResourceDefinition"),

        # filter an attribute set
        filterObject(data, f):: {
            [x]: data[x] for x in std.objectFields(data) if f(data[x])
        },

        withNamespace(namespace):: {
            metadata+: { namespace: namespace }
        },

        withAnnotations(annotations):: {
            metadata+: $.kk.objectMeta.withAnnotations(annotations)
        },

        withAnnotationsMixin(annotations):: {
            metadata+: $.kk.objectMeta.withAnnotationsMixin(annotations)
        },

        withFluxLayer(layer):: $.kk.withAnnotationsMixin({
            "fractal.k8s.arctarus.net/flux-layer": layer
        }),

        withFluxPath(path):: $.kk.withAnnotationsMixin({
            "fractal.k8s.arctarus.net/flux-path": path
        })
    }
}
+ utils
