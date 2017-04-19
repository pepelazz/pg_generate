package main

import (
	"fmt"
	"path/filepath"
	"os"
	"strings"
	"github.com/pkg/errors"
	"bytes"
	"github.com/serenize/snaker"
	"text/template"
)

func generateSqlFuncs() ([]byte, error) {
	result := []byte("")
	// добавляем в список sql функций методы для каждого документа, описанные в main.toml
	addToFuncListDocMethods()
	// итерируем по списку функций из файла functionList.toml
	for _, f := range *docModels.Funcs {
		var tmplBytes bytes.Buffer
		if err := sqlFuncTml.ExecuteTemplate(&tmplBytes, fmt.Sprintf("%s.sql", f), docModels); err != nil {
			return nil, errors.New(fmt.Sprintf("ExecuteTemplate file %s.sql. Error: %s", f, err))
		}
		result = append(result, tmplBytes.Bytes()...)
	}
	return result, nil
}

func generateSqlTriggers() ([]byte, error) {
	result := []byte("")
	// итерируем по документам
	for _, docType := range docTypeSortArr {
		doc := docModels.Docs[docType]
		var tmplBytes bytes.Buffer
		if err := sqlFuncTml.ExecuteTemplate(&tmplBytes, "_triggerTmpl.sql", doc); err != nil {
			return nil, errors.New(fmt.Sprintf("ExecuteTemplate file trigger.sql. Error: %s", err))
		}
		result = append(result, tmplBytes.Bytes()...)
	}
	return result, nil
}

func generateSqlInitData() ([]byte, error) {
	var tmplBytes bytes.Buffer
	if err := sqlFuncTml.ExecuteTemplate(&tmplBytes, "initialData.sql", nil); err != nil {
		return nil, errors.New(fmt.Sprintf("ExecuteTemplate file initialData.sql. Error: %s", err))
	}
	return tmplBytes.Bytes(), nil
}

// функция сборки sql шаблонов для postgres функций
func buildSqlFuncTmpl() (err error) {
	funcs := template.FuncMap{"joinWithQuotes": joinWithQuotes}
	funcs["camelToSnake"] = snaker.CamelToSnake
	funcs["uppercase"] = strings.ToUpper
	funcs["dict"] = dict
	funcs["rightsTmpl"] = rightsTmpl
	sqlFuncTml = *template.New("template").Funcs(funcs).Delims("[[", "]]")
	path := fmt.Sprintf("%s/function", config.TemplateDir)
	err = filepath.Walk(path, func(path string, info os.FileInfo, err error) error {
		if strings.HasSuffix(path, ".sql") {
			_, err = sqlFuncTml.ParseFiles(path)
			if err != nil {
				return errors.New(fmt.Sprintf("Read template files from directory '%s: %s'.", path, err))
			}
			return err
		}
		return err
	})
	return err
}

func addToFuncListDocMethods()  {
	for _, doc := range docModels.Docs {
		for _, m := range doc.TmplMain.Methods {
			*docModels.Funcs = append(*docModels.Funcs, m)
		}
	}
}

