package main

import (
	"encoding/base64"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
)

func generateSatysfiSource(decodedMath string) (string, error) {
    // TODO check paren balance
	var b strings.Builder
	fmt.Fprint(&b, "@require: stdja\n")
	fmt.Fprintf(&b, "StdJa.document(|title={};author={};show-toc=false;show-title=false|)'<+p{${%s}}>", decodedMath)
	return b.String(), nil
}

func compile_to_png(base64Math string) (string, error) {
	decoded, err := base64.RawStdEncoding.DecodeString(base64Math)
	if err != nil {
		log.Printf("Cannot decode %s", base64Math)
		return "", err
	}
	saty_name := "/tmp/satymathbot/" + base64Math + ".saty"
	pdf_name := "/tmp/satymathbot/" + base64Math + ".pdf"
	png_name := "/tmp/satymathbot/" + base64Math + "-1.png"
	if _, err := os.Stat(png_name); err != nil {
		f, _ := os.Create(saty_name)
		satysfi_source, err := generateSatysfiSource(string(decoded))
		if err != nil {
			return "", err
		}
		f.WriteString(satysfi_source)
		exec.Command("satysfi", saty_name, "-o", pdf_name).Run()
		exec.Command("pdftoppm", pdf_name, "-png", "/tmp/satymathbot/"+base64Math).Run()
	}
	return "ok", nil
}

func handleRequest(w http.ResponseWriter, r *http.Request) {
	if msg, err := compile_to_png(r.URL.Path[1:]); err == nil {
		fmt.Fprint(w, msg)
	}
}

func main() {
	http.HandleFunc("/", handleRequest)
	log.Fatal(http.ListenAndServe(":8080", nil))
}
