{ type, namespace ? null, }:
{ name, file, path }:
{ lib, config, ... }: let
    inherit (lib) kube mkIf
        getAttrFromPath setAttrByPath;
    cfg = if namespace != null
        then getAttrFromPath [type namespace name] config
        else getAttrFromPath [type name];
in {
    # This is a special Nix file that gets customised by Fractal's library
    # It's used to provide a default.nix for modules that don't have one

    options = let
        value = with lib; mkOption {
            type = types.attrs;
            default.enable = false;
            description = "Configuration for the component";
        };
    in if namespace != null
        then setAttrByPath [type namespace name] value
        else setAttrByPath [type name] value;

    config = mkIf cfg.enable {
        resources.${type} = let
            f = path + "/${file}";
        in if file == "main.jsonnet" then
            kube.compileJsonnet f {
                inherit (config) cluster;
                component = cfg;
            }
        else if file == "kustomization.yaml" then
            kube.compileKustomization path
        else throw "Unsupported component file ${file}!";
    };
}
