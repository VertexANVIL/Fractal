package cmd

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/arctaruslimited/fractal/app/internal/pkg/control"
	"github.com/arctaruslimited/fractal/app/internal/pkg/models"
	"github.com/arctaruslimited/fractal/app/internal/pkg/utils"
	"github.com/jedib0t/go-pretty/v6/text"
	"github.com/schollz/progressbar/v3"
	"github.com/spf13/cobra"
)

var clusterRenderOptions struct {
	mode           string
	outDir         string
	skipValidation bool
}

var clusterRenderCmd = &cobra.Command{
	Use:        "render <cluster>",
	Short:      "Renders a cluster into its resources",
	Args:       cobra.MinimumNArgs(1),
	ArgAliases: []string{"cluster"},
	Run: func(cmd *cobra.Command, args []string) {
		cluster := args[0]
		repo := control.NewRepository(config.Flake)

		var pbar *progressbar.ProgressBar
		if config.PrettyOutput {
			pbar = progressbar.NewOptions(-1,
				progressbar.OptionSpinnerType(14),
				progressbar.OptionEnableColorCodes(true),
			)

			defer pbar.Clear()
		}

		if pbar != nil {
			pbar.Describe("evaluating cluster resources")
		}

		tmpResult, err := utils.AsyncProgressWait(func() (interface{}, error) {
			return repo.GetClusterManifests(cluster)
		}, pbar)

		if err != nil {
			log.Fatal(err)
		}

		results := tmpResult.([]models.Resource)
		if !clusterRenderOptions.skipValidation {
			errorCount := 0
			for _, result := range results {
				value := result.Validation()
				_type := value.Type
				if _type == "error" {
					errorCount++
				}
			}

			if errorCount > 0 {
				if pbar != nil {
					pbar.Clear()
				}

				fmt.Println(text.FgRed.Sprint(fmt.Sprintf("%d resource(s) failed validation. Run `fractal cluster validate` to see what failed.", errorCount)))
				fmt.Println(text.FgRed.Sprint("If you know what you're doing, you can override the check with the --skip-validation flag."))
				os.Exit(1)
			}
		}

		// clear progress bar before rendering
		if pbar != nil {
			pbar.Clear()
		}

		path := filepath.Join(clusterRenderOptions.outDir, cluster)
		control.RenderResources(results, path, clusterRenderOptions.mode)
	},
}

func init() {
	clusterRenderCmd.Flags().StringVarP(&clusterRenderOptions.outDir, "out-dir", "o", "build", "directory to write the output to")
	clusterRenderCmd.Flags().StringVarP(&clusterRenderOptions.mode, "mode", "m", "flux", "mode to use for writing manifests")
	clusterRenderCmd.Flags().BoolVar(&clusterRenderOptions.skipValidation, "skip-validation", false, "skip validation before render")

	clusterCmd.AddCommand(clusterRenderCmd)
}
