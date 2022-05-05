package cmd

import "github.com/spf13/cobra"

// clusterCmd represents the cluster command
var clusterCmd = &cobra.Command{
	Use:   "cluster",
	Short: "Operations related to clusters",
}

func init() {
	rootCmd.AddCommand(clusterCmd)
}
