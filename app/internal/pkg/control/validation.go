package control

type ValidationResultCounts struct {
	Total   int `json:"total"`
	Success int `json:"success"`
	Warning int `json:"warning"`
	Error   int `json:"error"`
}

type ValidationResultResource struct {
	// Type of the result (warning or error)
	Type string `json:"type"`

	// Output from the validator, if present
	Message string `json:"message"`
}

type ValidationResult struct {
	Counts    ValidationResultCounts              `json:"counts"`
	Resources map[string]ValidationResultResource `json:"resources"`
}
