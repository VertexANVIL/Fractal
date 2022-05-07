{ config, lib, ... }: let
    configTopLevel = config;
    inherit (lib) attrValues flatten filter kube mapAttrsToList evalModules;
in {
    options = with lib; let
        namespaceModule = name: types.submodule ({ config, ... }: {
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
        });

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
                    default = configTopLevel.cluster.namespaces.services.name;
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

        resources = {
            generic = mkOption {
                type = types.listOf types.attrs;
                default = [];
                description = "Resources not automatically assigned a group";
            };

            prelude = mkOption {
                type = types.listOf types.attrs;
                default = [];
                description = "Cluster base resources including CRDs and namespaces";
            };

            features = mkOption {
                type = types.listOf types.attrs;
                default = [];
                description = "Cluster infrastructure components";
            };

            operators = mkOption {
                type = types.listOf types.attrs;
                default = [];
                description = "Cluster operator components";
            };

            services = mkOption {
                type = types.listOf types.attrs;
                default = [];
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
        # create namespaces
        resources.prelude = filter (n: n != null) (map (
            v: if !v.create then null else {
                apiVersion = "v1";
                kind = "Namespace";
                metadata = {
                    inherit (v) name;
                } // (if v.labels != {} then {
                    inherit (v) labels;
                } else {});
            }
        ) (attrValues config.cluster.namespaces));

        # execute the service packages
        resources.services = flatten (map (m: let
            package = m.package { inherit config lib; };  
            resources = package.resources (m.config // { inherit (m) namespace; });
        in kube.defaultNamespaces m.namespace resources) config.packages);
    };
}
