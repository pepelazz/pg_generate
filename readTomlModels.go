package main

import (
	"path/filepath"
	"os"
	"github.com/labstack/gommon/log"
	"strings"
	"fmt"
	"github.com/pkg/errors"
)

//функция чтения файлов из директории с моделями
func readTomlModelDir() filepath.WalkFunc {
	return func(path string, info os.FileInfo, err error) error {
		if err != nil {
			log.Print(err)
			return nil
		}
		if !info.IsDir() && string([]rune(info.Name())[0]) != "." {
			// подбираем структуру, в которую будем парсить данные из toml файла
			err = selectTomlReaderForFile(path)

			if err != nil {
				log.Print(err)
				return err
			}
		}
		return nil
	}
}

//функция выбора функций парсинга toml файла
func selectTomlReaderForFile(path string) (err error) {
	// разбираем строку path для извлечения имени файла
	pathSlice := strings.Split(path, "/")
	fullFileName := pathSlice[len(pathSlice) - 1:][0]
	fileName := strings.Split(fullFileName, ".")[0]
	// выбор функции парсинга в зависимости от имени файла
	switch fileName {
	case "main":
		err = processFileMain(path)
		if err != nil {
			fmt.Printf("Error: processFileMain path:'%s': %s \n", path, err)
		}
	case "schemaList":
		err = processFileSchemaList(path)
		if err != nil {
			fmt.Printf("Error: processFileMain path:'%s': %s \n", path, err)
		}
	case "functionList":
		err = processFileFunctionList(path)
		if err != nil {
			fmt.Printf("Error: processFileFunctionList path:'%s': %s \n", path, err)
		}
	default:
		return errors.New(fmt.Sprintf("Toml parser not found for file:%s \n", path))
	}
	return
}



