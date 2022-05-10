package cmd

import "github.com/spf13/cobra"

var helmCmd = &cobra.Command{
	Use:   "helm",
	Short: "Operations related to managing Helm charts",
}

func init() {
	rootCmd.AddCommand(helmCmd)
}
