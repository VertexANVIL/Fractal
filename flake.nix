{
    description = "Fractal Kubernetes Framework";
    inputs.xnlib.url = "github:ArctarusLimited/xnlib";

    outputs = inputs: {
        lib = import ./lib { inherit inputs; };
    };
}
