package cmd

import "github.com/spf13/cobra"

var jsonnetCmd = &cobra.Command{
	Use:   "jsonnet",
	Short: "Operations related to manipulating Jsonnet",
}

func init() {
	rootCmd.AddCommand(jsonnetCmd)
}
