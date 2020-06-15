package main

import (
	"log"
	"perftest/cmd"
)

func main() {
	err := cmd.RootCmd.Execute()
	if err != nil {
		log.Fatal(err)
	}
}
