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

                    operators = {
                        cluster-network-addons.enable = true;
                        kubevirt.enable = true;
                        minio.enable = true;
                        #olm.enable = true;
                    };

                    features = {
                        cert-manager.enable = true;
                        dashboard.enable = true;
                        hnc-manager.enable = true;
                        ingress-nginx.enable = true;
                        kyverno.enable = true;
                        metrics-server.enable = true;
                        replicator.enable = true;
                        secret-generator.enable = true;
                        vault-client.enable = true;
                        vault-secrets-operator.enable = true;
                    };
                };
            };

            # output of all modules used to make clusters
            modules = flatten [
                (recursiveModuleTraverse ./modules/base)
                (recursiveModuleTraverse ./modules/crds)
                (kube.componentModules ./modules/features "features")
                (kube.componentModules ./modules/operators "operators")
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
