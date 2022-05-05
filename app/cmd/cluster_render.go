package cmd

import (
	"fmt"
	"log"
	"os"

	"github.com/arctaruslimited/fractal/app/internal/pkg/control"
	"github.com/jedib0t/go-pretty/v6/text"
	"github.com/spf13/cobra"
)

var renderSkipValidation bool

var clusterRenderCmd = &cobra.Command{
	Use:        "render <cluster>",
	Short:      "Renders a cluster into its resources",
	Args:       cobra.MinimumNArgs(1),
	ArgAliases: []string{"cluster"},
	Run: func(cmd *cobra.Command, args []string) {
		cluster := args[0]
		repo := control.NewRepository(config.Flake)

		if !renderSkipValidation {
			result, err := repo.ValidateCluster(cluster)
			if err != nil {
				log.Fatal(err)
			}

			if result.Counts.Error > 0 {
				fmt.Println(text.FgRed.Sprint("One or more resources failed validation. Run `fractal cluster validate` to see what failed."))
				fmt.Println(text.FgRed.Sprint("If you know what you're doing, you can override the check with the --skip-validation flag."))
				os.Exit(1)
			}
		}

		// TODO: implement render logic
	},
}

func init() {
	clusterRenderCmd.Flags().BoolVar(&renderSkipValidation, "skip-validation", false, "skip validation before render")
	clusterCmd.AddCommand(clusterRenderCmd)
}
