{
  description = "Fractal Kubernetes Framework";
  inputs.std.url = "github:divnix/std";
  inputs.std.inputs.nixpkgs.follows = "nixpkgs";
  inputs.std.inputs.mdbook-kroki-preprocessor.follows = "std/blank";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs = {
    xnlib.url = "github:ArctarusLimited/xnlib";
    xnlib.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    std,
    ...
  } @ inputs:
    std.growOn {
      inherit inputs;
      cellsFrom = std.incl ./. [
        ./lib # library
        ./ext # extensions library
        ./app # fractal cli
        ./cfg # fractal cfg interfaces
      ];
      cellBlocks = with std.blockTypes; [
        # library
        (functions "utils")
        (functions "builders")
        (functions "generators")
        (functions "validators")
        # ext library
        (functions "hooks")
        (functions "flux")
        # fractal cfg interfaces
        (functions "options")
        (functions "modules")
        # fractal cli
        (installables "packages")
      ];
    }
    {
      packages = std.harvest self ["app" "packages"];
      lib' = std.harvest self [
        ["lib"]
        ["ext"]
        ["lib" "utils"]
        ["lib" "builders"]
        ["lib" "generators"]
        ["lib" "validators"]
        ["ext" "hooks"]
        ["ext" "flux"]
      ];
      # compatibility with former x86_64-linux - only lib
      lib = inputs.xnlib.lib.extend (_: _: { kube = self.lib'.x86_64-linux; });
    };
}
