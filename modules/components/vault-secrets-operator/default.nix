{ config, lib, ... }: let
    inherit (lib) kube mkIf;
    cfg = config.components.vault-secrets-operator;
in {
    options.components.vault-secrets-operator = with lib; {
        enable = mkEnableOption "Vault Secrets Operator";

        name = mkOption {
            type = types.str;
            default = "vault-secrets-operator";
            description = "The name of the component";
        };

        version = mkOption {
            type = types.str;
            default = "1.15.2";
            description = "Version of the Helm chart to use";
        };
    };

    config = mkIf cfg.enable {
        # enable creation of the HelmRepository source
        #components.flux.helm.ricoberger.enable = true;

        resources = let
            f = n: import n { inherit config lib; }; 
        in kube.uniqueResources {
            release = f ./release.nix;
        };
    };
}
