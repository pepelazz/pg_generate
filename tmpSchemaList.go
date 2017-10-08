package pgGenerate

import (
	"github.com/pelletier/go-toml"
	"fmt"
	"github.com/pkg/errors"
	"text/template"
	"bytes"
	"log"
)


//прасинг файла с schemaList.toml
func processFileSchemaList(path string) (err error) {

	t, err := toml.LoadFile(path)
	if err != nil {
		if err != nil {
			fmt.Printf("Error:  toml.LoadFile path:'%s': %s \n", path, err)
		}
		return
	}

	if !t.Has("schemaList") {
		log.Fatalf("In file %s missed field: 'schemaList'", path)
	}
	data := t.Get("schemaList").([]interface{})
	arr := make([]string, len(data))
	for i, res := range data {
		arr[i] = res.(string)
	}
	docModels.Schemas = &arr

	return
}

func generateSchemaFile() (result []byte, err error) {

	tmpl := template.New("template").Delims("[[", "]]")
	// берем шаблон из последней указанной директории, на случай переопределения в конечном проекте
	lastPath := config.TemplateDir[len(config.TemplateDir)-1]
	path := fmt.Sprintf("%s/docs/default/schema.sql",lastPath)

	// функция сборки html темплейтов для данного типа документа (читаем все файлы из указанной директории)
	_, err = tmpl.ParseFiles(path)
	if err != nil {
		err = errors.New(fmt.Sprintf("Read template file '%s: %s'.", path, err))
		return
	}

	if err != nil {
		err = errors.New(fmt.Sprintf("readSchemaTmpl error: %s", err))
		return
	}

	if docModels.Schemas == nil {
		err = errors.New(fmt.Sprintf("Not load schema model from schemaList.toml. May be you forget make file model/schemaList.toml"))
		return
	}

	for _, schema := range *docModels.Schemas {
		var tmplBytes bytes.Buffer
		if err := tmpl.ExecuteTemplate(&tmplBytes, "createSchemaTmpl", schema); err != nil {
			return nil, errors.New(fmt.Sprintf("ExecuteTemplate file 'createSchemaTmpl'. Error: %s", err))
		}
		result = append(result, tmplBytes.Bytes()...)
	}

	return
}


