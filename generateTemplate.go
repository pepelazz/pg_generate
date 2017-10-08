package pgGenerate

import (
	"fmt"
	"path/filepath"
	"os"
	"strings"
	"text/template"
	"github.com/pkg/errors"
	"bytes"
	"github.com/serenize/snaker"
)

var (
	tmplFiles = []string{"main.sql"}
)

func generateModelFiles() ([]byte, error) {
	result := []byte("")
	// итерируем по документам
	for _, docType := range docTypeSortArr {
		doc := docModels.Docs[docType]
		// итерируем по указанному списку файлов
		for _, tmplFileName := range tmplFiles {
			docRes, err := writeTemplateToFile(doc, tmplFileName)
			if err != nil {
				return nil, err
			}
			result = append(result, docRes...)

		}
	}
	return result, nil
}

// функция выбора шаблона и генерация sql скрипта
func writeTemplateToFile(doc *Doc, tmplFileName string) ([]byte, error) {

	// делаем в два шага: сперва загрузка дефолтных шаблонов, затем шаблонов для данного типа документа (если такие найдутся)
	funcs := template.FuncMap{"joinWithQuotes": joinWithQuotes}
	funcs["camelToSnake"] = snaker.CamelToSnake
	funcs["uppercase"] = strings.ToUpper
	funcs["dict"] = dict
	tmpl := template.New("template").Funcs(funcs).Delims("[[", "]]")
	// Шаг 1: загружаем дефолтные шаблоны
	for _, tmplPath := range config.TemplateDir {
		err := buildTmpl(tmpl, fmt.Sprintf("%s/docs/default", tmplPath))
		if err != nil {
			return nil, errors.New(fmt.Sprintf("buildTmpl error: %s", err))
		}
	}
	// Шаг 2: загружаем шаблоны для данного типа документа (если для данного типа документа создана директория),
	// которые перезаписывают дефолтные
	for _, tmplPath := range config.TemplateDir {
		docTmplDir := fmt.Sprintf("%s/docs/%s", tmplPath, doc.DocType)
		if _, err := os.Stat(docTmplDir); err == nil {
			err = buildTmpl(tmpl, docTmplDir)
			if err != nil {
				return nil, errors.New(fmt.Sprintf("buildTmpl error: %s", err))
			}
		}
	}
	var tmplBytes bytes.Buffer
	if err := tmpl.ExecuteTemplate(&tmplBytes, tmplFileName, doc); err != nil {
		return nil, errors.New(fmt.Sprintf("ExecuteTemplate file %s. Error: %s", tmplFileName, err))
	}

	return tmplBytes.Bytes(), nil
}

// функция сборки html темплейтов для данного типа документа (читаем все файлы из указанной директории)
func buildTmpl(tmpl *template.Template, path string) (err error) {
	err = filepath.Walk(path, func(path string, info os.FileInfo, err error) error {
		if strings.HasSuffix(path, ".sql") {
			_, err = tmpl.ParseFiles(path)
			if err != nil {
				return errors.New(fmt.Sprintf("Read template files from directory '%s: %s'.", path, err))
			}
			return err
		}
		return err
	})
	return err
}


