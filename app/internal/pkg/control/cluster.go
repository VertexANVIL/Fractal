package control

type Cluster struct {
	// Identifier of the cluster
	Name string `json:"name"`

	// DNS address of the cluster
	Dns string `json:"dns"`

	// Kubernetes version of the cluster
	Version string `json:"version"`
}
