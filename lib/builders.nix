{ inputs, lib, pkgs, system, ... }: let
    inherit (inputs) jrender;

    inherit (builtins) toJSON fromJSON readFile readDir pathExists;
    inherit (lib) attrByPath kube mapAttrsToList last splitString removeSuffix filterAttrs hasSuffix;
in rec {
    friendlyPathName = path: last (splitString "/" path);

    # Imports a directory of custom resource definition YAML files
    compileCrds = dir: mapAttrsToList (n: _: let
        friendly = removeSuffix ".yaml" n;
    in
        fromJSON (readFile (pkgs.runCommandLocal "yaml-build-crd-${friendly}" {}
            "cat ${dir + "/${n}"} | ${pkgs.yaml2json}/bin/yaml2json > $out"))
    ) ((filterAttrs (n: _: hasSuffix ".yaml" n) (readDir dir)));

    # Compiles Helm chart sources to provide to Jsonnet
    compileHelmCharts = { config, inputs }: let
        root = inputs.self.outPath;

        attrs = let
            p = root + "/helm.lock.json";
        in if pathExists p then fromJSON (readFile p)
            else throw "helm.lock.json does not exist; did you run `fractal helm lock` and `git add` the result?";

        build = meta: lock: let
            inherit (pkgs) fetchurl stdenv;
        in stdenv.mkDerivation rec {
            inherit (meta) version;
            pname = "helm-chart-${meta.source}-${meta.name}";

            src = fetchurl {
                inherit (lock) urls;
                sha256 = lock.digest;
            };

            dontBuild = true;
            dontConfigure = true;

            installPhase = ''
                dest="$out/${meta.source}/${meta.name}/${meta.version}"
                mkdir -p "$dest"
                tar xf $src --directory "$dest" --strip-components 1
            '';

            preferLocalBuild = true;
            allowSubstitutes = false;
        };

        versions = map (c: build c (attrByPath [c.source c.name c.version]
            (throw "No chart (${c.source}/${c.name}, ${c.version}) present in helm.lock.json; did you forget to run `fractal helm lock`?") attrs))
        config.helm.charts;
    in pkgs.symlinkJoin {
        name = "helm-charts";
        paths = versions;
    };

    # Compiles Jsonnet code located at the specified path
    compileJsonnet = {
        config, inputs
    }@all: values: path: let
        f = let
            full = values // { inherit (config) classes cluster; };
        in pkgs.writeText "values.json" (toJSON full);

        name = "jsonnet-build";

        # -J ${dirOf path} is required here because ${path} only brings that specific file into the closure
        result = pkgs.runCommandLocal name {} ''
            cp -rL ${dirOf path} env && chmod -R 775 env && cd env
            if [ ! -d "charts" ]; then
                ln -s ${compileHelmCharts all} charts
            fi

            ${jrender.defaultPackage.${system}}/bin/jrender $(pwd)/${baseNameOf path} -J ${./../support/jsonnet} --ext-code-file inputs=${f} -o $out
        '';
    in kube.recursiveTraverseResources (fromJSON (readFile result));

    # Builds a Kustomization and returns Kubernetes objects
    compileKustomization = path: let
        result = pkgs.runCommandLocal "kustomize-build-${friendlyPathName path}" {}
            "${pkgs.kustomize}/bin/kustomize build ${path} | ${pkgs.yq-go}/bin/yq ea -o=json '[.]' - > $out";
    in fromJSON (readFile result);
}
