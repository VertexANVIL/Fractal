package models

type GlobalConfig struct {
	Debug  bool
	DryRun bool

	Path         string
	Flake        string
	JsonOutput   bool
	PrettyOutput bool
}

type NixConfig struct {
	Binary string

	// Override paths for flakes
	FlakeOverrides map[string]string
}
