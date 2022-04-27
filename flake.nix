{
    description = "Kubernetes Shared Test";
    inputs.xnlib.url = "github:ArctarusLimited/xnlib";

    outputs = inputs@{ self, ... }: let
        lib = import ./lib { inherit inputs; };
        inherit (lib) attrValues flatten kube mapAttrs recursiveModuleTraverse;
    in {
        lib = {
            # only need to export the kube part of the library
            inherit (lib) kube;
        };

        kube = rec {
            # output of all the clusters we can build
            #clusters = {};

            test_clusters.test = kube.clusterConfiguration {
                configuration = { ... }: {
                    cluster = {
                        name = "cic-stir1";
                        dns = "cic.stir1.arctarus.net";
                    };

                    features.dashboard.enable = true;
                    features.cert-manager.enable = true;
                    features.vault-secrets-operator.enable = true;
                };
            };

            # output of all modules used to make clusters
            modules = flatten [
                (recursiveModuleTraverse ./modules/base)
                (recursiveModuleTraverse ./modules/crds)
                (kube.componentModules ./modules/features "features")
                (kube.componentModules ./modules/services "services")
            ];

            test = builtins.readFile (lib.elemAt modules 2);

            # utility output to output compiled components
            #__zz.components = mapAttrs (name: res: kube.compileManifests (attrValues (res {}))) components;
            #__zz.services = mapAttrs (name: res: kube.compileManifests (attrValues (res {}))) services;

            # test only
            # test_clusters = let
            #     # create the cluster builder
            #     builder = kube.clusterBuilder {
            #         inherit components;
            #     };
            # in {
            #     cic-stir1 = builder.buildCluster {
            #         # metadata
            #         type = "cic";
            #         region = "stir1";
            #     };
            # };
        };
    };
}
