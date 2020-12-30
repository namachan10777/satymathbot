package main

import (
	"fmt"
	"log"
	"os/exec"
)

func main() {
	fmt.Println("Hello World!")
	satysfi_out, satysfi_err := exec.Command("/usr/local/bin/satysfi", "--help").Output()
	if satysfi_err != nil {
		log.Fatal(satysfi_err)
	}
	fmt.Printf("satysfi: %s\n", satysfi_out)
	pdftoppm_out, pdftoppm_err := exec.Command("/usr/bin/pdftoppm", "--help").Output()
	if pdftoppm_err != nil {
		log.Fatal(pdftoppm_err)
	}
	fmt.Printf("pdftoppm: %s\n", pdftoppm_out)
}
