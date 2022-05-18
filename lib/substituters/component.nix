{
    # Type of the component (operators, features, services)
    type,
    # Name of the component
    name,
    # Path to the component's root directory
    path,

    # Namespace of the repository
    namespace ? null
}:
{ lib, config, inputs, ... }: let
    inherit (builtins) pathExists;
    inherit (lib) optional evalModules kube hasAttr mkIf mkMerge foldl' flatten filter
        attrByPath getAttrFromPath setAttrByPath length recursiveUpdate;
    cfg = if namespace != null
        then getAttrFromPath [type namespace name] config
        else getAttrFromPath [type name];

    _file = (path + "/default.nix");
    component = import _file { inherit lib; };
    title = attrByPath ["title"] "Component" metadata;

    # Defines the options for the component's `metadata` section
    options = with lib; {
        # TODO: Add options here
    };

    metadata = let
        module = {
            inherit options;
            config = (attrByPath ["metadata"] {} component);
        };
    in (evalModules {
        modules = [ module ];
    }).config;

    transformer = kube.transformer { inherit config; };
    moduleTransformers = [
        (c: r: let
            layer = kube.flux.typeToLayer c.type;
            path = with c; filter (n: n != null) ["components" type namespace name];
            pre = recursiveUpdate r {
                metadata.labels = {
                    "fractal.k8s.arctarus.net/component" = "${type}.${namespace}.${name}";
                };
            };
        in transformer pre (t: [
            (t.flux layer path)
        ]))
    ];
in let
    m = if hasAttr "module" component
        then component.module {
            inherit lib config inputs;
            self = cfg;
        } else {};
in m // {
    inherit _file;

    options = with lib; let
        value = {
            enable = mkEnableOption title;
        } // (attrByPath ["options"] {} m);
    in if namespace != null
        then setAttrByPath [type namespace name] value
        else setAttrByPath [type name] value;

    config = mkIf cfg.enable (mkMerge [{
        resources = let
            crds = let
                f = path + "/crds";
                imported = let
                    i = kube.compileCrds f;
                in map (r: transformer r (t: [
                    (t.flux null ["layers" "10-prelude"])
                ])) i;
            in if pathExists f then imported else [];

            # try jsonnet, then kustomize, then fallback
            imported = let
                f = path + "/main.jsonnet";
            in if pathExists f then
                kube.compileJsonnet
                    { inherit config inputs; } { component = cfg; } path
            else let
                f = path + "/kustomization.yaml";
            in if pathExists f then
                kube.compileKustomization path
            else [];

            defaulted = kube.defaultNamespaces config.cluster.namespaces.${type}.name imported;
            final = crds ++ (foldl' (r: t: map (t {
                inherit type name path namespace metadata;
            }) r) defaulted moduleTransformers);

            cond = flatten [
                # create a kustomization entry for this component if we're rendering in Flux mode
                (optional (config.cluster.renderer.mode == "flux" && (length final) > 0)
                    [(kube.flux.buildComponentKustomization {
                        inherit config type name namespace metadata;
                    })])
            ];
        in final ++ cond;
    } (attrByPath ["config"] {} m)]);
}
