package harbor

import (
	"github.com/spf13/cobra"
)

var HarborCmd = &cobra.Command{
	Use:   "harbor",
	Short: "harbor test",
	Long:  "harbor test",
}

func init() {
	HarborCmd.AddCommand(pullimageCmd)
}
