{ lib, pkgs, ... }: let
    inherit (builtins) toJSON;
    inherit (lib) kube listToAttrs hasAttr
        flatten toLower nameValuePair;
in rec {
    versionHashes = {
        "1.23.5" = "sha256-6ecgOnNwSzacOcyASzpGoVIV9UI0AEg29b00vS//u7g=";
    };

    crdsToJsonSchema = crds: listToAttrs (flatten ((map (v: map (version: let
            name = toLower "${v.spec.names.kind}-${v.spec.group}-${version.name}";
        in nameValuePair name version.schema.openAPIV3Schema) v.spec.versions)) crds));
    
    # Fetches and converts a Kubernetes API schema
    fetchAPISchema = version: let
        fetched = if !hasAttr version versionHashes then
            throw "No hash defined for version ${version}!"
        else pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/kubernetes/kubernetes/v${version}/api/openapi-spec/swagger.json";
            sha256 = versionHashes.${version};
        };

    in pkgs.runCommandLocal "kube-schema-compile" {} ''
        output="$out/v${version}-standalone-strict"
        mkdir -p $output && ${pkgs.python39Packages.openapi2jsonschema}/bin/openapi2jsonschema --output $output --kubernetes --strict ${fetched}
    '';

    # Runs Kubeval to validate resources against Kubernetes API and CRD schemas
    validateManifests = attrs: version: crds: let
        compiled = kube.compileManifests attrs;
        schema = fetchAPISchema version;

        crdSchemas = let
            schemaFile = pkgs.writeText "crds.json" (toJSON (crdsToJsonSchema crds));
        in pkgs.runCommandLocal "kube-schema-compile-crds" {} ''
            output="$out/v${version}-standalone-strict"
            mkdir -p $output && ${pkgs.jq}/bin/jq -cr 'keys[] as $k | "\($k)\n\(.[$k])"' ${schemaFile} | while read -r key; do
                read -r item
                printf '%s\n' "$item" > "$output/$key.json"
            done
        '';
    in pkgs.runCommandLocal "kube-check" {} ''
        ln -s ${compiled} resources.yaml
        ln -s ${schema} schema
        ln -s ${crdSchemas} crds

        ${pkgs.kubeval}/bin/kubeval --strict \
            --ignore-missing-schemas \
            --schema-location file://$(pwd)/schema \
            --additional-schema-locations file://${crdSchemas} \
            --kubernetes-version ${version} resources.yaml && touch $out
    '';
}
