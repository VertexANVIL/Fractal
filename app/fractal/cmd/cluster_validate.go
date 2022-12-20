package cmd

import (
	"encoding/json"
	"fmt"
	"log"
	"os"

	"github.com/arctaruslimited/fractal/app/internal/pkg/control"
	"github.com/arctaruslimited/fractal/app/internal/pkg/models"
	"github.com/arctaruslimited/fractal/app/internal/pkg/utils"
	"github.com/jedib0t/go-pretty/v6/table"
	"github.com/jedib0t/go-pretty/v6/text"
	"github.com/schollz/progressbar/v3"
	"github.com/spf13/cobra"
)

var clusterValidateCmd = &cobra.Command{
	Use:        "validate <cluster>",
	Short:      "Validates the resources of a cluster",
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
		}

		if pbar != nil {
			pbar.Describe("validating cluster resources")
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

		results := tmpResult.([]models.Resource)

		successCount := 0
		warningCount := 0
		errorCount := 0

		for _, result := range results {
			value := result.Validation()
			_type := value.Type
			if _type == "success" {
				successCount++
			} else if _type == "warning" {
				warningCount++
			} else if _type == "error" {
				errorCount++
			}
		}

		var writer table.Writer
		if config.JsonOutput {
			attrs := map[string]models.ResourceValidation{}
			for _, result := range results {
				attrs[result.Identifier()] = result.Validation()
			}

			bytes, err := json.MarshalIndent(attrs, "", "  ")
			if err != nil {
				log.Fatal(err)
			}
			fmt.Println(string(bytes))
		} else {
			writer = table.NewWriter()
			writer.SetOutputMirror(os.Stdout)
			writer.AppendHeader(table.Row{"Type", "Resource", "Message"})
			writer.SetColumnConfigs([]table.ColumnConfig{
				{Name: "Type", WidthMax: 10},
				{Name: "Resource", WidthMax: 80},
				{Name: "Message", WidthMax: 40},
			})

			for _, result := range results {
				value := result.Validation()

				_type := value.Type
				if _type == "success" {
					// don't print success resources for now
					continue
				} else if _type == "warning" {
					_type = text.FgYellow.Sprint(_type)
				} else if _type == "error" {
					_type = text.FgRed.Sprint(_type)
				}

				writer.AppendRow(table.Row{_type, result.Identifier(), value.Message})
			}

			// format the "summary" text
			var summary string
			if errorCount > 0 {
				summary = text.FgRed.Sprint("error")
			} else if warningCount > 0 {
				summary = text.FgYellow.Sprint("warning")
			} else {
				summary = text.FgGreen.Sprint("success")
			}

			writer.AppendSeparator()
			writer.AppendRow(table.Row{
				text.FgGreen.Sprint(summary),
				fmt.Sprintf(
					"%d resources validated successfully, %d warnings, %d errors",
					successCount, warningCount, errorCount,
				), "N/A",
			})

			writer.Render()
		}

		if errorCount > 0 {
			os.Exit(1)
		}
	},
}

func init() {
	clusterCmd.AddCommand(clusterValidateCmd)
}
