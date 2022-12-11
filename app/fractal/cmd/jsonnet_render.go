package cmd

import (
	"bytes"
	"fmt"
	"os"
	"text/template"

	jsonnet "github.com/google/go-jsonnet"
	"github.com/google/go-jsonnet/ast"
	"github.com/spf13/cobra"

	tankaNative "github.com/grafana/tanka/pkg/jsonnet/native"
)

var options struct {
	outputFile   string
	jPathDirs    []string
	extCodeFiles map[string]string
}

func applyTemplate() *jsonnet.NativeFunction {
	return &jsonnet.NativeFunction{
		Name:   "applyTemplate",
		Params: ast.Identifiers{"str", "values"},
		Func: func(data []interface{}) (res interface{}, err error) {
			tpl := data[0].(string)
			tmpl, err := template.New("tpl").Parse(tpl)
			if err != nil {
				return nil, err
			}

			var buf bytes.Buffer
			err = tmpl.Execute(&buf, data[1])
			if err != nil {
				return nil, err
			}

			return buf.String(), nil
		},
	}
}

// rootCmd represents the base command when called without any subcommands
var jsonnetRenderCmd = &cobra.Command{
	Use:        "render",
	Short:      "Extended Jsonnet renderer",
	Args:       cobra.MinimumNArgs(1),
	ArgAliases: []string{"file"},
	Run: func(cmd *cobra.Command, args []string) {
		file := args[0]

		vm := jsonnet.MakeVM()
		for _, nf := range tankaNative.Funcs() {
			vm.NativeFunction(nf)
		}

		vm.NativeFunction(applyTemplate())
		vm.Importer(&jsonnet.FileImporter{
			JPaths: options.jPathDirs,
		})

		for k, v := range options.extCodeFiles {
			contents, _, err := vm.ImportAST(v, v)
			if err != nil {
				fmt.Fprintln(os.Stderr, err.Error())
				os.Exit(1)
			}

			vm.ExtNode(k, contents)
		}

		result, err := vm.EvaluateFile(file)
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}

		err = WriteOutputFile(result, options.outputFile)
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}
	},
}

func init() {
	jsonnetRenderCmd.PersistentFlags().StringVarP(&options.outputFile, "output-file", "o", "", "File to be written to")
	jsonnetRenderCmd.PersistentFlags().StringArrayVarP(&options.jPathDirs, "jpath", "J", []string{}, "Specify an additional library search dir (right-most wins)")
	jsonnetRenderCmd.PersistentFlags().StringToStringVar(&options.extCodeFiles, "ext-code-file", map[string]string{}, "Read the code from the file")
	jsonnetRenderCmd.MarkPersistentFlagRequired("output-file")

	jsonnetCmd.AddCommand(jsonnetRenderCmd)
}

func WriteOutputFile(output string, outputFile string) (err error) {
	if outputFile == "" {
		fmt.Print(output)
		return nil
	}

	f, createErr := os.Create(outputFile)
	if createErr != nil {
		return createErr
	}
	defer func() {
		if ferr := f.Close(); ferr != nil {
			err = ferr
		}
	}()

	_, err = f.WriteString(output)
	return err
}
