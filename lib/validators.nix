{ lib, pkgs, ... }: let
    inherit (builtins) validateAsJSON toJSON fromJSON readFile;
    inherit (lib) filter kube listToAttrs filterAttrs hasAttr recursiveMerge recursiveUpdate attrByPath isAttrs isString removePrefix splitString
        flatten toLower nameValuePair mapAttrs mapAttrsToList concatStringsSep mapAttrsRecursive length elemAt;
in rec {
    versionHashes = {
        "1.23.5" = "sha256-6ecgOnNwSzacOcyASzpGoVIV9UI0AEg29b00vS//u7g=";
    };

    crdsToJsonSchema = crds: listToAttrs (flatten ((map (v: map (version: let
            name = toLower "${v.spec.names.kind}-${v.spec.group}-${version.name}";
        in nameValuePair name version.schema.openAPIV3Schema) v.spec.versions)) crds));

    schemaNameFromGvk = gvk: concatStringsSep "-" (
        filter (k: k != null && k != "") [gvk.kind gvk.group gvk.version]
    );

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
    in {
        schemas.kubernetes = filterAttrs (n: v: n == "definitions") attrs;
        types = recursiveMerge (mapAttrsToList (n: v: let
            gvks = attrByPath ["x-kubernetes-group-version-kind"] null v;
        in if gvks == null then {} else
            listToAttrs (map (gvk: nameValuePair (schemaNameFromGvk gvk) {
                schema = "kubernetes";
                path = "#/definitions/${n}";
            }) gvks)
        ) attrs.definitions);
    };

    # Runs Kubeval to validate resources against Kubernetes API and CRD schemas
    validateManifests = attrs: version: crds: let
        metadata = fetchAPISchema version;
    in filterAttrs (_: v: v != null) (listToAttrs (map (r: let
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
            p = attrByPath [name] null metadata.types;
        #in if p == null then throw "No matching schema for resource ${name}" else p;
        in if p == null then null else p;
        schema = metadata.schemas.${res.schema};
    in
        nameValuePair rid (if res == null then "Error locating schema" else let
            validated = validateAsJSON schema res.path r;
        in if validated.success then "Success" else validated.value)
    ) attrs));
}
