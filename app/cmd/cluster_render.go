package cmd

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/arctaruslimited/fractal/app/internal/pkg/control"
	"github.com/arctaruslimited/fractal/app/internal/pkg/utils"
	"github.com/jedib0t/go-pretty/v6/text"
	"github.com/schollz/progressbar/v3"
	"github.com/spf13/cobra"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
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

		if !clusterRenderOptions.skipValidation {
			if pbar != nil {
				pbar.Describe("validating cluster resources")
			}

			tmpResult, err := utils.AsyncProgressWait(func() (interface{}, error) {
				return repo.ValidateCluster(cluster)
			}, pbar)

			if err != nil {
				log.Fatal(err)
			}

			result := *tmpResult.(*control.ValidationResult)
			if result.Counts.Error > 0 {
				if pbar != nil {
					pbar.Clear()
				}

				fmt.Println(text.FgRed.Sprint(fmt.Sprintf("%d resource(s) failed validation. Run `fractal cluster validate` to see what failed.", result.Counts.Error)))
				fmt.Println(text.FgRed.Sprint("If you know what you're doing, you can override the check with the --skip-validation flag."))
				os.Exit(1)
			}
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

		// clear progress bar before rendering
		if pbar != nil {
			pbar.Clear()
		}

		results := tmpResult.([]unstructured.Unstructured)
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
