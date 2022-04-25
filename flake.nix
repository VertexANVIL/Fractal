{
    description = "Kubernetes Shared Test";
    inputs.xnlib.url = "github:ArctarusLimited/xnlib";

    outputs = inputs@{ self, ... }: let
        lib = import ./lib { inherit inputs; };
        inherit (lib) attrValues kube mapAttrs recImportDirs;
    in {
        lib = {
            # only need to export the kube part of the library
            inherit (lib) kube;
        };

        kube = rec {
            # output of all the clusters we can build
            #clusters = {};

            # test_clusters.test = lib.kube.clusterConfiguration {
            #     configuration = { ... }: {
            #         cluster.name = "cic-stir1";
            #         components.vault-secrets-operator.enable = true;
            #     };
            # };

            # output of all modules used to make clusters
            modules = lib.recursiveModuleTraverse ./modules;

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
