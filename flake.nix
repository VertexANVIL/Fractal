{
  description = "Fractal Kubernetes Framework";
  inputs.std.url = "github:divnix/std";
  inputs.std.inputs.nixpkgs.follows = "nixpkgs";
  inputs.std.inputs.mdbook-kroki-preprocessor.follows = "std/blank";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs = {
    xnlib.url = "github:ArctarusLimited/xnlib";
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
        ./app # fractal cli
      ];
      cellBlocks = with std.blockTypes; [
        # library
        (functions "builders")
        (functions "generators")
        (functions "validators")
        # fractal cli
        (installables "packages")
      ];
    }
    {
      packages = std.harvest self ["app" "packages"];
      lib = import ./lib {inherit inputs;};
    };
}
