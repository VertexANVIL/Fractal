{ config, lib, ... }: {
    options = with lib; {
        cluster = {
            name = mkOption {
                type = types.str;
                description = "Unique cluster identifier";
            };

            dns = mkOption {
                type = types.str;
                description = "External DNS domain of the cluster";
            };
        };

        resources = mkOption {
            type = types.attrs;
            default = {};
            description = "Unique Kubernetes resources to apply to the cluster";
        };
    };
}
