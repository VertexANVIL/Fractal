{ config, lib, ... }: let
    inherit (lib) kube mapAttrsToList evalModules recursiveMerge;
in {
    options = with lib; let
        servicesModule = types.submodule ({ ... }: {
            options = {
                config = mkOption {
                    type = types.attrs;
                    default = {};
                    description = "Options to be passed to the configuration module within the package";
                };

                namespace = mkOption {
                    type = types.str;
                    default = config.cluster.namespaces.services;
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
            type = types.attrsOf servicesModule;
            default = {};
            description = "Cluster applications";
        };
    };

    config = {
        # execute the service packages
        resources.services = recursiveMerge (mapAttrsToList (n: m: let
            package = m.package { inherit config lib; };
            module = evalModules {
                modules = [({ ... }: {
                    inherit (m) config;
                    inherit (package) options;
                })];
            };
            
            resources = package.resources module.config;
        in kube.defaultNamespaces m.namespace resources) config.services);
    };
}
