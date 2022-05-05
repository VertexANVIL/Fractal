package cmd

import (
	"encoding/json"
	"fmt"
	"log"
	"os"

	"github.com/arctaruslimited/fractal/app/internal/pkg/control"
	"github.com/spf13/cobra"

	"github.com/jedib0t/go-pretty/v6/table"
)

var clusterListCmd = &cobra.Command{
	Use:   "list",
	Short: "Lists clusters defined by the flake",
	Run: func(cmd *cobra.Command, args []string) {
		repo := control.NewRepository(config.Flake)
		result, err := repo.GetClusters()
		if err != nil {
			log.Fatal(err)
		}

		if config.JsonOutput {
			bytes, err := json.MarshalIndent(result, "", "  ")
			if err != nil {
				log.Fatal(err)
			}
			fmt.Println(string(bytes))
		} else {
			writer := table.NewWriter()
			writer.SetOutputMirror(os.Stdout)
			writer.AppendHeader(table.Row{"Name", "DNS Domain", "Kubernetes Version"})
			for _, value := range result {
				writer.AppendRow(table.Row{value.Name, value.Dns, value.Version})
			}
			writer.Render()
		}
	},
}

func init() {
	clusterCmd.AddCommand(clusterListCmd)
}
