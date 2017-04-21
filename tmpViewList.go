package pgGenerate

import (
	"fmt"
	"github.com/pkg/errors"
	"path/filepath"
	"os"
	"strings"
	"io/ioutil"
)

// сборка view из sql файлов
func generateViewFiles() (result []byte, err error) {

	path := config.ViewDir

	err = filepath.Walk(path, func(path string, info os.FileInfo, err error) error {
		if strings.HasSuffix(path, ".sql") {
			data, err := ioutil.ReadFile(path)
			if err != nil {
				return errors.New(fmt.Sprintf("Read view files from directory '%s: %s'.", path, err))
			}
			result = append(result, data...)
			return err
		}
		return err
	})

	return
}


