package cmd

import (
	"github.com/arctaruslimited/fractal/app/internal/pkg/models"
	"github.com/arctaruslimited/fractal/app/internal/pkg/nix"
	"github.com/spf13/cobra"
)

var config = models.GlobalConfig{
	Debug:        false,
	DryRun:       false,
	PrettyOutput: true,
}

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:              "fractal",
	Short:            "Kubernetes cluster resource manager",
	Long:             `Kubernetes cluster resource management with Nix.`,
	PersistentPreRun: preRun,
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	cobra.CheckErr(rootCmd.Execute())
}

func init() {
	rootCmd.PersistentFlags().BoolVarP(&config.Debug, "debug", "d", false, "enable debugging")
	rootCmd.PersistentFlags().BoolVarP(&config.JsonOutput, "json", "j", false, "output values as JSON")
	rootCmd.PersistentFlags().StringVarP(&config.Path, "path", "p", ".", "the repository path to reference (overrides the flake reference)")
	rootCmd.PersistentFlags().StringVarP(&config.Flake, "flake", "f", "", "the repository flake to reference")

	// nix specific arguments
	rootCmd.PersistentFlags().StringVar(&nix.Config.Binary, "nix-binary", "nix", "path to the nix binary")
	rootCmd.PersistentFlags().StringToStringVar(&nix.Config.FlakeOverrides, "nix-flake-override", map[string]string{}, "optional flake overrides")
}

func preRun(cmd *cobra.Command, args []string) {
	// force PrettyOutput to false when debugging or JSON
	if config.Debug || config.JsonOutput {
		config.PrettyOutput = false
	}

	// default the flake path to the repository path, if present
	if config.Flake == "" {
		config.Flake = config.Path
	}
}
