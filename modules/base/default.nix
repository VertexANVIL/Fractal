{ config, lib, ... }: let
    configTopLevel = config;
    inherit (lib) flatten kube mapAttrsToList evalModules;
in {
    options = with lib; let
        packagesModule = types.submodule ({ config, ... }: {
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
                    description = "Namespace the package should be deployed into";
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

            version = mkOption {
                type = types.str;
                default = "master";
                description = "Kubernetes API version of the cluster";
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
                type = types.listOf types.attrs;
                default = {};
                description = "Cluster custom resource definitions (CRDs)";
            };

            features = mkOption {
                type = types.listOf types.attrs;
                default = {};
                description = "Cluster infrastructure components";
            };

            operators = mkOption {
                type = types.listOf types.attrs;
                default = {};
                description = "Cluster operator components";
            };

            services = mkOption {
                type = types.listOf types.attrs;
                default = {};
                description = "Cluster applications";
            };
        };

        packages = mkOption {
            type = types.listOf packagesModule;
            default = [];
            description = "Cluster packages to deploy";
        };
    };

    config = {
        # execute the service packages
        resources.services = flatten (map (m: let
            package = m.package { inherit config lib; };  
            resources = package.resources (m.config // { inherit (m) namespace; });
        in kube.defaultNamespaces m.namespace resources) config.packages);
    };
}
