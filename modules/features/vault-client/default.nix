{ config, lib, ... }@inputs: let
    inherit (lib) kube mkIf importMultiple;
    cfg = config.features.vault-client;
in {
    options.features.vault-client = with lib; {
        enable = mkEnableOption "Vault Client";

        name = mkOption {
            type = types.str;
            default = "vault-client";
            description = "The name of the component";
        };

        version = mkOption {
            type = types.str;
            default = "v0.17.1";
            description = "Version of the Helm chart to use";
        };
    };

    config = mkIf cfg.enable {
        # enable creation of the HelmRepository source
        features.flux-cd.sources.helm.hashicorp.enable = true;
    
        # import the resources
        resources = uniqueResourcesFromFiles inputs [
            ./issuer.nix ./metadata.nix ./release.nix
        ];
    };
}
