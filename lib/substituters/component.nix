{
    type, namespace ? null, name, path
}:
{ lib, config, ... }: let
    inherit (builtins) pathExists;
    inherit (lib) kube hasAttr mkIf mkMerge
        attrByPath getAttrFromPath setAttrByPath;
    cfg = if namespace != null
        then getAttrFromPath [type namespace name] config
        else getAttrFromPath [type name];

    _file = (path + "/default.nix");
    component = import _file { inherit lib; };
    metadata = attrByPath ["metadata"] {} component;
    title = attrByPath ["title"] "Component" metadata;
in let
    m = if hasAttr "module" component
        then component.module {
            inherit lib config;
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
            in if !pathExists f then [] else
                kube.crdImport f;

            # try jsonnet, then kustomize, then fallback
            imported = let
                f = path + "/main.jsonnet";
            in if pathExists f then
                kube.compileJsonnet f {
                    inherit (config) cluster;
                    component = cfg;
                }
            else let
                f = path + "/kustomization.yaml";
            in if pathExists f then
                kube.compileKustomization path
            else [];
        in crds ++ (kube.defaultNamespaces config.cluster.namespaces.${type}.name imported);
    } (attrByPath ["config"] {} m)]);
}
