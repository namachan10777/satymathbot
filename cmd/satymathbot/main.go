package main

import (
	"encoding/base64"
	"fmt"
	"image"
	"image/png"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
)

const dirPrefix = "/tmp/satymathbot/"

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
	f, err := os.Create(dirPrefix + base64Math + ".saty")
	defer f.Close()
	if err != nil {
		log.Printf("cannot create satyfi source file (%q)", err)
		return err
	}
	satysfiSource, err := generateSatysfiSource(string(decoded))
	if err != nil {
		log.Printf("something went wrong when generating satysfi source from %s (%q)", base64Math, err)
		return err
	}
	f.WriteString(satysfiSource)
	return nil
}

func pngName(base64Math string) string {
	return dirPrefix + base64Math + ".png"
}

func compileToPng(base64Math string) error {
	satyName := dirPrefix + base64Math + ".saty"
	pdfName := dirPrefix + base64Math + ".pdf"
	err := createSatysfiSource(base64Math)
	if err != nil {
		return err
	}
	_, err = exec.Command("satysfi", satyName, "-o", pdfName).Output()
	if err != nil {
		log.Fatal(err)
	}
	_, err = exec.Command("pdftoppm", pdfName, "-png", "/tmp/satymathbot/"+base64Math).Output()
	if err != nil {
		log.Fatal(err)
	}
	return nil
}

func max(a int, b int) int {
	if a > b {
		return a
	}
	return b
}

func min(a int, b int) int {
	if a < b {
		return a
	}
	return b
}

// 存在し読み込めるpngを必ず渡すことj
func cropPng(fileName string, writeFileName string) error {
	reader, err := os.Open(fileName)
	defer reader.Close()
	if err != nil {
		log.Fatalf("cannot read png file \"%s\"", fileName)
	}
	m, _, err := image.Decode(reader)
	if err != nil {
		log.Fatalf("cannot decode png file \"%s\"", fileName)
	}
	bounds := m.Bounds()
	minX := 300
	minY := 300
	maxX := 0
	maxY := 0
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r, g, b, _ := m.At(x, y).RGBA()
			if r != 65535 || g != 65535 || b != 65535 {
				minX = min(minX, x)
				minY = min(minY, y)
				maxX = max(maxX, x)
				maxY = max(maxY, y)
			}
		}
	}
	xSize := maxX - minX
	ySize := maxY - minY
	if xSize < 0 || ySize < 0 {
		return fmt.Errorf("empty png %s", fileName)
	}
	cropped := image.NewRGBA(
		image.Rectangle{image.Point{0, 0}, image.Point{xSize, ySize}},
	)
	for x := 0; x < xSize; x++ {
		for y := 0; y < ySize; y++ {
			cropped.Set(x, y, m.At(x+minX, y+minY))
		}
	}
	w, err := os.Create(writeFileName)
	defer w.Close()
	if err != nil {
		log.Fatalf("cannot write png file \"%s\"", writeFileName)
	}
	if err = png.Encode(w, cropped); err != nil {
		log.Fatalf("cannot encode png file %s (%q)", writeFileName, err)
	}
	return nil
}

func handleRequest(w http.ResponseWriter, r *http.Request) {
	base64Math := r.URL.Path[1:]
	// cache miss
	if _, err := os.Stat(pngName(base64Math)); err != nil {
		log.Printf("cache miss %s", base64Math)
		err = compileToPng(base64Math)
		if err == nil {
			err = cropPng("/tmp/satymathbot/"+base64Math+"-1.png", pngName(base64Math))
			if err != nil {
				log.Printf("cannt crop png file (%q)", err)
				return
			}
		} else {
			log.Printf("cannot compile math %s", base64Math)
			return
		}
	}
	img, err := os.Open(pngName(base64Math))
	if err != nil {
		log.Fatalf("cannot read compiled png file (%q)", err)
	}
	defer img.Close()
	w.Header().Set("Content-Type", "image/png")
	io.Copy(w, img)
}

func initialize() {
	if _, err := os.Stat("/tmp"); err != nil && os.IsNotExist(err) {
		os.Mkdir("/tmp", os.ModeDir)
	}
	if _, err := os.Stat("/tmp/satymathbot"); err != nil && os.IsNotExist(err) {
		os.Mkdir("/tmp/satymathbot", os.ModeDir)
	}
}

func main() {
	initialize()
	http.HandleFunc("/", handleRequest)
	log.Fatal(http.ListenAndServe(":8080", nil))
}
