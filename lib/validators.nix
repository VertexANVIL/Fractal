{inputs, cell}: let
    inherit (inputs) nixpkgs xnlib;

    l = nixpkgs.lib // builtins;
in rec {
    versionHashes = {
        "1.22.3" = "sha256-1nGGcOBiaB5NyeK52t8rMRwUfP2rysYouQGAERZdh3M=";
        "1.23.5" = "sha256-6ecgOnNwSzacOcyASzpGoVIV9UI0AEg29b00vS//u7g=";
    };

    crdsToJsonSchema = crds: l.listToAttrs (l.flatten ((map (v: map (version: let
            name = l.toLower "${v.spec.names.kind}-${v.spec.group}-${version.name}";
        in l.nameValuePair name {
            schema = version.schema.openAPIV3Schema;
            path = "#"; # always the root path for CRDs
        }) v.spec.versions)) crds));

    schemaNameFromGvk = gvk: l.toLower (l.concatStringsSep "-" (
        l.filter (k: k != null && k != "") [gvk.kind gvk.group gvk.version]
    ));

    # Fetches and converts a Kubernetes API schema
    # Outputs one attribute per CRD
    fetchAPISchema = version: let
        fetched = if !l.hasAttr version versionHashes then
            throw "No hash defined for version ${version}!"
        else l.fromJSON (l.readFile (nixpkgs.fetchurl {
            url = "https://raw.githubusercontent.com/kubernetes/kubernetes/v${version}/api/openapi-spec/swagger.json";
            sha256 = versionHashes.${version};
        }));

        # run any requisite fixups on the fetched output
        attrs = l.recursiveUpdate fetched {
            definitions = {
                # allow null for EnvVars - edge case workaround for some helm charts
                # (we need a better solution to allow null properties in general)
                "io.k8s.api.core.v1.EnvVar" = {
                    properties.value.type = ["null" "string"];
                };

                # although the kubernetes api does not allow `number`  as valid
                # Quantity type - almost all kubenetes tooling
                # recognizes it is valid. For this reason, we extend the API definition to
                # allow `number` values.
                "io.k8s.apimachinery.pkg.api.resource.Quantity" = {
                    type = ["number" "string"];
                };

                # same as above with io.k8s.api.core.v1.EnvVar
                "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta" = {
                    properties = {
                        annotations.type = ["null" "object"];
                        labels.type = ["null" "object"];
                    };
                };

                # not sure what the Kubernetes devs were smoking when they defined this one, but we fix it here
                "io.k8s.apimachinery.pkg.util.intstr.IntOrString" = {
                    type = ["integer" "string"];
                };
            };
        };

        filtered = l.filterAttrs (n: v: n == "definitions") attrs;
    in xnlib.lib.recursiveMerge (l.mapAttrsToList (n: v: let
        gvks = l.attrByPath ["x-kubernetes-group-version-kind"] null v;
    in if gvks == null then {} else
        l.listToAttrs (map (gvk: l.nameValuePair (schemaNameFromGvk gvk) {
            schema = filtered;
            path = "#/definitions/${n}";
        }) gvks)
    ) attrs.definitions);

    # Runs Kubeval to validate resources against Kubernetes API and CRD schemas
    transformValidateManifests = attrs: version: crds: let
        metadata = (fetchAPISchema version)
            // (crdsToJsonSchema crds);
        resources = l.filter (v: v != null) (map (r: let
            name = let
                av = l.attrByPath ["apiVersion"] null r;
                avs = l.splitString "/" av;
                gvk = {
                    group = if av == null then "" else l.elemAt avs 0;
                    version = if av == null then "" else
                        if l.length avs > 1 then l.elemAt avs 1 else "";
                    kind = r.kind;
                };
            in schemaNameFromGvk gvk;

            res = let
                p = l.attrByPath [name] null metadata;
            in if p == null then null else p;

            output = (if res == null then r // {
                _validation = {
                    type = "warning";
                    message = "No schema found";
                };
            } else let
                validated = l.validateAsJSON res.schema res.path r;
            in if validated.success then r // {
                _validation = {
                    type = "success";
                };
            } else r // {
                _validation = {
                    type = "error";
                    message = validated.value;
                };
            });
        in output) attrs);
    in resources;
}
