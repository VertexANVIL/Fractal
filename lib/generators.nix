{ lib, ... }: let
    inherit (lib) flatten kube pathExists
        recImportDirs recursiveModuleTraverse;
in rec {
    # Builds a Fractal flake with the standard directory structure
    makeStdFlake = { self, flakes ? {}, ... }: let
        root = self.outPath;
    in {
        kube = {
            # output of all the clusters we can build
            clusters = let
                dir = root + "/clusters";
            in if !(pathExists dir) then {} else recImportDirs {
                inherit dir;
                _import = n: kube.clusterConfiguration {
                    configuration = import (dir + "/${n}");
                    extraModules = flatten (map (f: f.kube.modules) (flakes ++ [self]));
                };
            };

            # output of all modules used to make clusters
            modules = let
                path = root + "/modules";
                ip = f: path: if pathExists path then f path else [];
            in flatten [
                (ip recursiveModuleTraverse (path + "/base"))
                (ip recursiveModuleTraverse (path + "/crds"))
                (ip (p: kube.componentModules p "features") (path + "/features"))
                (ip (p: kube.componentModules p "operators") (path + "/operators"))
                (ip (p: kube.componentModules p "services") (path + "/services"))
            ];
        };
    };
}
