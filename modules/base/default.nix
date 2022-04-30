{ config, lib, ... }: let
    configTopLevel = config;
    inherit (lib) kube mapAttrsToList evalModules recursiveMerge;
in {
    options = with lib; let
        servicesModule = types.submodule ({ config, ... }: {
            options = let
                calledPackage = config.package { inherit config lib; };
            in {
                config = mkOption {
                    type = types.submodule {
                        options = calledPackage.options;
                    };
                    default = {};
                    description = "Options to be passed to the configuration module within the package";
                };

                namespace = mkOption {
                    type = types.str;
                    default = configTopLevel.cluster.namespaces.services;
                    description = "Namespace the service should be deployed into";
                };

                package = mkOption {
                    type = types.functionTo types.attrs;
                    description = "Kubernetes resource package to use";
                };
            };
        });
    in {
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

        services = mkOption {
            type = types.listOf servicesModule;
            default = [];
            description = "Cluster applications";
        };
    };

    config = {
        # execute the service packages
        resources.services = recursiveMerge (map (m: let
            package = m.package { inherit config lib; };  
            resources = package.resources m.config;
        in kube.defaultNamespaces m.namespace resources) config.services);
    };
}
