package pgGenerate

import (
	"os"
	"fmt"
	"log"
	"strings"
	"github.com/pkg/errors"
)

func checkErr(err error, msg string) {
	if err != nil {
		log.Fatalf("%s: %s", msg, err)
	}
}

func checkSourceDirExist() {
	checkDirExist(config.ModelDir, "Create directory for 'model' files.")
	checkDirExist(config.TemplateDir, "Create directory for 'template' files.")
}

func checkDirExist(path string, msg string) {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		log.Fatal(fmt.Sprintf("Directory %s not exist. %s\n", path, msg))
	}
}

func castArrInterfaceToArrString(arr []interface{}) []string {
	newArr := make([]string, len(arr))
	for i, v := range arr {
		newArr[i] = v.(string)
	}
	return newArr
}

func joinWithQuotes(arr []string, sep string, quote string) (s string) {
	for _, item := range arr {
		s += fmt.Sprintf("%s%s%s, ", quote, item, quote)
	}
	s = strings.TrimSuffix(s, ", ")
	return
}

func dict(values ...interface{}) (map[string]interface{}, error) {
	if len(values) % 2 != 0 {
		return nil, errors.New("invalid dict call")
	}
	dict := make(map[string]interface{}, len(values) / 2)
	for i := 0; i < len(values); i += 2 {
		key, ok := values[i].(string)
		if !ok {
			return nil, errors.New("dict keys must be strings")
		}
		dict[key] = values[i + 1]
	}
	return dict, nil
}

// функция используется в шаблоне для вставки блоков для проверки прав
func rightsTmpl(docType string, method string) (tmpl string, err error) {
	if _, ok := docModels.Docs[docType]; !ok {
		return "", errors.New(fmt.Sprintf("rightsTmpl: not found doc for docType: '%s'.", docType))
	}
	doc := docModels.Docs[docType]
	for _, r := range doc.TmplMain.Rights {
		if r.Method == method {
			str := fmt.Sprintf(`
			IF (params ->> 'userRole') != ALL('{%s}'::text[])
			THEN
		 	  RETURN json_build_object('code', 'error', 'message', 'insufficient rights');
		 	END IF;
			`, joinWithQuotes(r.Allow, ",", "\""))
			return str, nil
		}
	}
	return "", nil
}