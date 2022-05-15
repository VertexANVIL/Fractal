{ lib, pkgs, ... }: let
    inherit (builtins) replaceStrings hasAttr isAttrs isList foldl';
    inherit (lib) kube attrByPath setAttrByPath flatten elem filterAttrs unique
        mapAttrs mapAttrsToList listToAttrs nameValuePair fold filter recursiveUpdate;
in rec {
    # Sets default namespaces on a list of resources
    defaultNamespaces = namespace: list: map (v: if
        ((attrByPath ["metadata" "namespace"] null v) != null)
    then v else v // { metadata = v.metadata // { inherit namespace; }; }) list;

    # Returns whether the annotation is set on the resource
    hasAnnotation = resource: annotation: let
        path = ["metadata" "annotations" annotation];
    in (attrByPath path null resource) != null;

    # Sets the value of an annotation on a resource if it is not already defined
    defaultAnnotation = resource: annotation: value: let
        path = ["metadata" "annotations" annotation];
    in if ((attrByPath path null resource) != null) then resource else recursiveUpdate resource (setAttrByPath path value);

    # performs general fixups to resources
    fixupManifests = list: foldl' (
        res: overlay: map overlay res
    ) list [
        # appends our identifier label
        (m: recursiveUpdate m {
            metadata.labels = {
                "fractal.k8s.arctarus.net/defined" = "true";
            };
        })

        # disables pruning on CRDs and PVCs (CRITICAL to not break stuff when Kustomizations are deleted)
        (m: if m.kind == "CustomResourceDefinition" || m.kind == "PersistentVolumeClaim" then recursiveUpdate m {
            metadata.annotations."kustomize.toolkit.fluxcd.io/prune" = "disabled";
        } else m)

        # removes null creationTimestamp (works around problem with some specific crds)
        (m: m // {
            metadata = filterAttrs (n: v: !(n == "creationTimestamp" && v == null)) m.metadata;
        })
        # removes null `data` on config maps (Helm will sometimes break this)
        (m: if m.kind == "ConfigMap" then
            filterAttrs (n: v: !(n == "data" && v == null)) m
        else m)

        # removes namespaces from resources that are not namespaced
        (m: let
            blacklist = [
                # kubernetes API
                "ComponentStatus" "Namespace" "Node" "PersistentVolume"
                "MutatingWebhookConfiguration" "ValidatingWebhookConfiguration" "CustomResourceDefinition"
                "APIService" "TokenReview" "SelfSubjectAccessReview" "SelfSubjectRulesReview" "SubjectAccessReview"
                "CertificateSigningRequest" "FlowSchema" "PriorityLevelConfiguration" "NodeMetrics"
                "IngressClass" "RuntimeClass" "PodSecurityPolicy" "ClusterRoleBinding" "ClusterRole" "PriorityClass"
                "VolumeSnapshotClass" "VolumeSnapshotContent" "CSIDriver" "CSINode" "StorageClass" "VolumeAttachment"

                # from CRDs (these should ideally be moved)
                "CDIConfig" "CDI" "ObjectTransfer" "StorageProfile" "ClusterIssuer"
                "CiliumClusterwideNetworkPolicy" "CiliumEgressNATPolicy" "CiliumExternalWorkload" "CiliumIdentity" "CiliumNode"
                "ServerBinding" "ClusterPolicy" "ClusterReportChangeRequest" "Environment" "ServerClass" "Server"
                "NetworkAddonsConfig" "ClusterPolicyReport"
            ];
        in if (elem m.kind blacklist) then m // {
            metadata = filterAttrs (n: v: n != "namespace") m.metadata;
        } else m)
    ];

    resourceId = resource: let
        # replace slashes with underscores
        rep = replaceStrings ["/"] ["_"];
        seek = p: rep (attrByPath p "_" resource);

        group = seek ["apiVersion"];
        kind = resource.kind;
        namespace = seek ["metadata" "namespace"];
        name = resource.metadata.name;
    in "${group}/${kind}/${namespace}/${name}";

    # creates unique IDs for Kubernetes resources
    uniqueResources = list: listToAttrs (map (v: nameValuePair (resourceId v) v) list);

    recursiveTraverseResources = object: let
        isResource = r: (hasAttr "kind" r && hasAttr "metadata" r && hasAttr "name" r.metadata);
    in flatten (if isList object then map recursiveTraverseResources object else
        if isAttrs object then if isResource object then [object] else mapAttrsToList (_: v: recursiveTraverseResources v) object
        else throw "Key does not contain a Kubernetes resource!");
}
