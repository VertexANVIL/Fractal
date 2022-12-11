package control

type ClusterRenderProperties struct {
	// Enables path seperation for FluxCD
	Flux bool `json:"flux"`
}

type ClusterProperties struct {
	// Identifier of the cluster
	Name string `json:"name"`

	// DNS address of the cluster
	Dns string `json:"dns"`

	// Kubernetes version of the cluster
	Version string `json:"version"`

	// Controls how the cluster is rendered
	Render ClusterRenderProperties `json:"render"`
}
