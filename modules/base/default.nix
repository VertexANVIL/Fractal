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

            namespaces = {
                features = mkOption {
                    type = types.str;
                    default = "infra-system";
                    description = "Namespace that contains unassigned cluster infrastructure";
                };

                operators = mkOption {
                    type = types.str;
                    default = "operator-system";
                    description = "Namespace that contains unassigned cluster operators";
                };

                services = mkOption {
                    type = types.str;
                    default = "services";
                    description = "Namespace that contains unassigned cluster services";
                };
            };
        };

        resources = {
            crds = mkOption {
                type = types.attrs;
                default = {};
                description = "Cluster custom resource definitions (CRDs)";
            };

            features = mkOption {
                type = types.attrs;
                default = {};
                description = "Cluster infrastructure components";
            };

            operators = mkOption {
                type = types.attrs;
                default = {};
                description = "Cluster operator components";
            };

            services = mkOption {
                type = types.attrs;
                default = {};
                description = "Cluster applications";
            };
        };
    };
}
