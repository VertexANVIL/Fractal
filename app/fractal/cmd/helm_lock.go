package cmd

import (
	"fmt"
	"log"
	"os"

	"github.com/arctaruslimited/fractal/app/internal/pkg/control"
	"github.com/spf13/cobra"
)

var helmLockOptions struct {
	force bool
}

var helmLockCmd = &cobra.Command{
	Use:   "lock",
	Short: "Updates the Helm lockfile",
	Run: func(cmd *cobra.Command, args []string) {
		if config.Path == "" {
			fmt.Fprintln(os.Stderr, "Updating may not be performed on a non-local flake")
			os.Exit(1)
		}

		repo := control.NewRepository(config.Flake)
		err := repo.LockHelmSources(helmLockOptions.force)
		if err != nil {
			log.Fatal(err)
		}

		fmt.Fprintln(os.Stderr, "Lockfile successfully updated. Don't forget to `git add` helm.lock.json.")
	},
}

func init() {
	helmLockCmd.Flags().BoolVar(&helmLockOptions.force, "force", false, "force overwrite digests of existing versions")

	helmCmd.AddCommand(helmLockCmd)
}
