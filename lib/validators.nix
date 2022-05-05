{ lib, pkgs, ... }: let
    inherit (builtins) validateAsJSON toJSON fromJSON readFile;
    inherit (lib) filter kube listToAttrs filterAttrs hasAttr recursiveMerge recursiveUpdate attrByPath isAttrs isString removePrefix splitString
        flatten toLower nameValuePair mapAttrs mapAttrsToList concatStringsSep mapAttrsRecursive length elemAt attrValues;
in rec {
    versionHashes = {
        "1.23.5" = "sha256-6ecgOnNwSzacOcyASzpGoVIV9UI0AEg29b00vS//u7g=";
    };

    crdsToJsonSchema = crds: listToAttrs (flatten ((map (v: map (version: let
            name = toLower "${v.spec.names.kind}-${v.spec.group}-${version.name}";
        in nameValuePair name {
            schema = version.schema.openAPIV3Schema;
            path = "#"; # always the root path for CRDs
        }) v.spec.versions)) crds));

    schemaNameFromGvk = gvk: toLower (concatStringsSep "-" (
        filter (k: k != null && k != "") [gvk.kind gvk.group gvk.version]
    ));

    # Fetches and converts a Kubernetes API schema
    # Outputs one attribute per CRD
    fetchAPISchema = version: let
        fetched = if !hasAttr version versionHashes then
            throw "No hash defined for version ${version}!"
        else fromJSON (readFile (pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/kubernetes/kubernetes/v${version}/api/openapi-spec/swagger.json";
            sha256 = versionHashes.${version};
        }));

        # run any requisite fixups on the fetched output
        attrs = recursiveUpdate fetched {
            "definitions" = {
                # not sure what the Kubernetes devs were smoking when they defined this one, but we fix it here
                "io.k8s.apimachinery.pkg.util.intstr.IntOrString" = {
                    "type" = ["integer" "string"];
                };
            };
        };

        filtered = filterAttrs (n: v: n == "definitions") attrs;
    in recursiveMerge (mapAttrsToList (n: v: let
        gvks = attrByPath ["x-kubernetes-group-version-kind"] null v;
    in if gvks == null then {} else
        listToAttrs (map (gvk: nameValuePair (schemaNameFromGvk gvk) {
            schema = filtered;
            path = "#/definitions/${n}";
        }) gvks)
    ) attrs.definitions);

    # Runs Kubeval to validate resources against Kubernetes API and CRD schemas
    validateManifests = attrs: version: crds: let
        metadata = (fetchAPISchema version)
            // (crdsToJsonSchema crds);
        resources = filterAttrs (k: v: v != null) (listToAttrs (map (r: let
            rid = kube.resourceId r;
            name = let
                av = attrByPath ["apiVersion"] null r;
                avs = splitString "/" av;
                gvk = {
                    group = if av == null then "" else elemAt avs 0;
                    version = if av == null then "" else
                        if length avs > 1 then elemAt avs 1 else "";
                    kind = r.kind;
                };
            in schemaNameFromGvk gvk;

            res = let
                p = attrByPath [name] null metadata;
            in if p == null then null else p;

            output = (if res == null then {
                type = "warning";
                message = "No schema found";
            } else let
                validated = validateAsJSON res.schema res.path r;
            in if validated.success then null else {
                type = "error";
                message = validated.value;
            });
        in nameValuePair rid (
            if output == null then null else output
        )) attrs));
    in rec {
        inherit resources;
        counts = rec {
            total = length attrs;
            success = total - warning - error;
            warning = length (filter (r: r.type == "warning") (attrValues resources));
            error = length (filter (r: r.type == "error") (attrValues resources));
        };
    };
}
