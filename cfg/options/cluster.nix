{lib}: with lib; {
    cluster = {
        name = mkOption {
            type = types.str;
            description = "Unique cluster identifier";
        };

        dns = mkOption {
            type = types.str;
            description = "External DNS domain of the cluster";
        };

        version = mkOption {
            type = types.str;
            default = "master";
            description = "Kubernetes API version of the cluster";
        };

        metal = {
            nodes = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Number of nodes in the cluster";
            };
        };

        renderer = {
            mode = mkOption {
                type = types.enum ["flat" "flat-dir" "flux"];
                default = "flat";
                description = "The mode of the renderer";
            };

            flux = {
                source = {
                    kind = mkOption {
                        type = types.str;
                        default = "GitRepository";
                    };

                    name = mkOption {
                        type = types.str;
                        default = "cluster";
                    };

                    namespace = mkOption {
                        type = types.str;
                        default = "flux-system";
                    };
                };
            };
        };

        namespaces = let
            namespaceModule = name: types.submodule {
                options = {
                    create = mkOption {
                        type = types.bool;
                        default = true;
                        description = "Whether to manage creation of this namespace";
                    };

                    labels = mkOption {
                        type = types.attrsOf types.str;
                        default = {};
                        description = "Optional labels to assign to the namespace";
                    };

                    name = mkOption {
                        type = types.str;
                        default = name;
                        description = "The name of the namespace";
                    };
                };
            };
        in {
            features = mkOption {
                type = namespaceModule "infra-system";
                default = {};
                description = "Namespace that contains unassigned cluster infrastructure";
            };

            operators = mkOption {
                type = namespaceModule "operator-system";
                default = {};
                description = "Namespace that contains unassigned cluster operators";
            };

            services = mkOption {
                type = namespaceModule "services";
                default = {};
                description = "Namespace that contains unassigned cluster services";
            };
        };
    };

    resources = mkOption {
        type = types.listOf types.attrs;
        default = [];
        description = "Kubernetes resources to deploy into the cluster";
    };

    packages = defaultNamespace: mkOption {
        type = types.listOf (types.submodule ({ config, ... }: {
            options = {
                config = mkOption {
                    type = types.submodule { inherit (config.package { inherit config lib; }) options; };
                    default = {};
                    description = "Options to be passed to the configuration module within the package";
                };

                namespace = mkOption {
                    type = types.str;
                    default = defaultNamespace;
                    description = "Namespace the package should be deployed into";
                };

                package = mkOption {
                    type = types.functionTo types.attrs;
                    description = "Kubernetes resource package to use";
                };
            };
        }));
        default = [];
        description = "Cluster packages to deploy";
    };

    helm = {
        charts = mkOption {
            type = types.listOf (types.submodule {
                options = {
                    name = mkOption {
                        type = types.str;
                        description = "The name of the chart";
                    };

                    version = mkOption {
                        type = types.str;
                        description = "The version of the chart";
                    };

                    source = mkOption {
                        type = types.str;
                        description = "The repository of the chart";
                    };
                };
            });
            default = {};
            description = "Helm charts";
        };
    };
}
