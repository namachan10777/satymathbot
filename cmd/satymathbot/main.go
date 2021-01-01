package main

import (
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
)

const dir_prefix = "/tmp/satymathbot/"

func generateSatysfiSource(decodedMath string) (string, error) {
    // TODO check paren balance
	var b strings.Builder
	fmt.Fprint(&b, "@require: empty\n")
	fmt.Fprintf(&b, "document ${%s}", decodedMath)
	return b.String(), nil
}

func createSatysfiSource(base64Math string) error {
	decoded, err := base64.RawStdEncoding.DecodeString(base64Math)
    if err != nil {
        log.Printf("cannot decode mathematics %s (%q)", base64Math, err)
        return err
    }
	f, err := os.Create(dir_prefix + base64Math + ".saty")
    defer f.Close()
    if err != nil {
        log.Printf("cannot create satyfi source file (%q)", err)
        return err
    }
	satysfi_source, err := generateSatysfiSource(string(decoded))
    if err != nil {
        log.Printf("something went wrong when generating satysfi source from %s (%q)", base64Math, err)
        return err
    }
	f.WriteString(satysfi_source)
    return nil
}

func compile_to_png(base64Math string) error {
	saty_name := dir_prefix + base64Math + ".saty"
	pdf_name  := dir_prefix + base64Math + ".pdf"
	png_name  := dir_prefix + base64Math + "-1.png"
	if _, err := os.Stat(png_name); err != nil {
        err = createSatysfiSource(base64Math)
		if err != nil {
			return err
		}
        _, err = exec.Command("satysfi", saty_name, "-o", pdf_name).Output()
        if err != nil {
            log.Fatal(err)
        }
        _, err = exec.Command("pdftoppm", pdf_name, "-png", "/tmp/satymathbot/"+base64Math).Output()
        if err != nil {
            log.Fatal(err)
        }
	}
	return nil
}

func handleRequest(w http.ResponseWriter, r *http.Request) {
    base64Math := r.URL.Path[1:]
	if err := compile_to_png(base64Math); err == nil {
        img, err := os.Open("/tmp/satymathbot/" + base64Math + "-1.png")
        if err != nil {
            log.Fatal(err)
        }
        defer img.Close()
        w.Header().Set("Content-Type", "image/png")
        io.Copy(w, img)
	}
}

func initialize() {
    if _, err := os.Stat("/tmp"); err != nil && os.IsNotExist(err){
        os.Mkdir("/tmp", os.ModeDir)
    }
    if _, err := os.Stat("/tmp/satymathbot"); err != nil && os.IsNotExist(err){
        os.Mkdir("/tmp/satymathbot", os.ModeDir)
    }
}


func main() {
    initialize()
	http.HandleFunc("/", handleRequest)
	log.Fatal(http.ListenAndServe(":8080", nil))
}
