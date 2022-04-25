{ config, lib, ... }: {
    options = with lib; {
        cluster = {
            name = mkOption {
                type = types.str;
                description = "Unique cluster identifier";
            };
        };

        resources = mkOption {
            type = types.attrs;
            default = {};
            description = "Unique Kubernetes resources to apply to the cluster";
        };
    };
}
