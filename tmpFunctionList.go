package pgGenerate

import (
	"fmt"
	"github.com/pepelazz/go-toml"
)

//прасинг файла с functionList.toml
func processFileFunctionList(path string) (err error) {

	t, err := toml.LoadFile(path)
	if err != nil {
		if err != nil {
			fmt.Printf("Error:  toml.LoadFile path:'%s': %s \n", path, err)
		}
		return
	}

	if t.Has("funcList") {
		data := t.Get("funcList").([]interface{})
		arr := make([]string, len(data))
		for i, res := range data {
			arr[i] = res.(string)
		}
		if docModels.Funcs == nil {
			docModels.Funcs = &[]string{}
		}
		*docModels.Funcs = append(*docModels.Funcs, arr...)
	}

	return
}
