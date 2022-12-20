{inputs, cell}: let
    inherit (inputs.cells.app) fractal;
    inherit (cell) utils;
    inherit (inputs) nixpkgs;

    l = nixpkgs.lib // builtins;
in rec {
    # Imports a directory of custom resource definition YAML files
    compileCrds = dir: let
        name = "yaml-build-crds";
        path = utils.reduceStoreDir name dir;
    in l.fromJSON (l.readFile (nixpkgs.runCommandLocal name {} ''
        cd ${path} && sed -s '1i---' *.yaml | ${nixpkgs.yq-go}/bin/yq ea '[.]' -o=json - > $out
    ''));

    # Compiles Helm chart sources to provide to Jsonnet
    compileHelmCharts = { config, inputs }: let
        root = inputs.self.outPath;

        attrs = let
            p = root + "/helm.lock.json";
        in if l.pathExists p then l.fromJSON (l.readFile p)
            else throw "helm.lock.json does not exist; did you run `fractal helm lock` and `git add` the result?";

        build = meta: lock: let
            inherit (nixpkgs) fetchurl stdenv;
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
    in nixpkgs.symlinkJoin {
        name = "helm-charts";
        paths = versions;
    };

    # Compiles Jsonnet code located at the specified path
    compileJsonnet = {
        config, inputs
    }@all: values: dir: let
        f = let
            full = values // { inherit (config) classes cluster; };
        in nixpkgs.writeText "values.json" (l.toJSON full);

        name = "jsonnet-build";
        path = utils.reduceStoreDir name dir;

        # -J ${dirOf path} is required here because ${path} only brings that specific file into the closure
        result = nixpkgs.runCommandLocal name {} ''
            cp -rL ${path} env && chmod -R 775 env && cd env
            if [ ! -d "charts" ]; then
                ln -s ${compileHelmCharts all} charts
            fi

            ${fractal}/bin/fractal jsonnet render $(pwd)/main.jsonnet -J ${inputs.self + /support/jsonnet} --ext-code-file inputs=${f} -o $out
        '';
    in utils.recursiveTraverseResources (l.fromJSON (l.readFile result));

    # Builds a Kustomization and returns Kubernetes objects
    compileKustomization = dir: let
        name = "kustomize-build";
        path = utils.reduceStoreDir name dir;
        result = nixpkgs.runCommandLocal name {}
            "${nixpkgs.kustomize}/bin/kustomize build ${path} | ${nixpkgs.yq-go}/bin/yq ea -o=json '[.]' - > $out";
    in l.fromJSON (l.readFile result);
}
