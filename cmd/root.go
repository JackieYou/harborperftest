package cmd

import (
	"perftest/cmd/harbor"

	"github.com/spf13/cobra"
)

var RootCmd = &cobra.Command{
	Use:   "perftest",
	Short: "perftest",
	Long:  "perftest",
}

func init() {
	RootCmd.AddCommand(harbor.HarborCmd)
}
