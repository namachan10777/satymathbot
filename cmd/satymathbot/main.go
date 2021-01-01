package main

import (
	"encoding/base64"
	"errors"
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

func png_name(base64Math string) string {
	return dir_prefix + base64Math + ".png"
}

func compile_to_png(base64Math string) error {
	saty_name := dir_prefix + base64Math + ".saty"
	pdf_name := dir_prefix + base64Math + ".pdf"
	err := createSatysfiSource(base64Math)
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
	return nil
}

func Max(a int, b int) int {
	if a > b {
		return a
	}
	return b
}

func Min(a int, b int) int {
	if a < b {
		return a
	}
	return b
}

// 存在し読み込めるpngを必ず渡すことj
func crop_png(fileName string, writeFileName string) error {
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
	min_x := 300
	min_y := 300
	max_x := 0
	max_y := 0
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r, g, b, _ := m.At(x, y).RGBA()
			if r != 65535 || g != 65535 || b != 65535 {
				min_x = Min(min_x, x)
				min_y = Min(min_y, y)
				max_x = Max(max_x, x)
				max_y = Max(max_y, y)
			}
		}
	}
	x_size := max_x - min_x
	y_size := max_y - min_y
	if x_size < 0 || y_size < 0 {
		return errors.New(fmt.Sprintf("empty png %s", fileName))
	}
	cropped := image.NewRGBA(
		image.Rectangle{image.Point{0, 0}, image.Point{x_size, y_size}},
	)
	for x := 0; x < x_size; x++ {
		for y := 0; y < y_size; y++ {
			cropped.Set(x, y, m.At(x+min_x, y+min_y))
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
	if _, err := os.Stat(png_name(base64Math)); err != nil {
		log.Printf("cache miss %s", base64Math)
		err = compile_to_png(base64Math)
		if err == nil {
			err = crop_png("/tmp/satymathbot/" + base64Math + "-1.png", png_name(base64Math))
			if err != nil {
				log.Printf("cannt crop png file (%q)", err)
				return
			}
		} else {
			log.Printf("cannot compile math %s", base64Math)
			return
		}
	}
	img, err := os.Open(png_name(base64Math))
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
