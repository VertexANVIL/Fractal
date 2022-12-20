{
  inputs,
  cell,
}: rec {
  default = fractal;
  fractal = let
    inherit
      (inputs.nixpkgs)
      lib
      buildGoModule
      makeWrapper
      kubernetes-helm
      kustomize
      ;
  in
    buildGoModule rec {
      pname = "fractal";
      version = "1.0.0";
      src = ./fractal;

      buildInputs = [makeWrapper];
      vendorSha256 = "sha256-BIqJ1PRJjIy/Z7ILr4mA6dE9IqBQabQt/YHgSgajRhw=";

      postInstall = ''
        mv "$out/bin/app" "$out/bin/fractal"
      '';

      postFixup = let
        runtimeDeps = [kubernetes-helm kustomize];
      in ''
        wrapProgram "$out/bin/fractal" \
            --prefix PATH ":" ${lib.makeBinPath runtimeDeps}
      '';

      meta = with lib; {
        description = "Nix-based framework for building Kubernetes resources";
        homepage = "https://github.com/ArctarusLimited/Fractal";
        license = licenses.mit;
        maintainers = [maintainers.citadelcore];
      };
    };
}
