package pgGenerate

import (
	"fmt"
	"github.com/pelletier/go-toml"
	"github.com/pkg/errors"
	"strings"
)

type TmplMain struct {
	DocType       string
	Tree          *toml.Tree
	Enums         map[string][]string
	TableName     string
	TableExt      string
	TableComment  string
	Fields        []TableField
	FkConstraints []FkConstraints
	Indexes       []TableIndex
	Triggers      []Trigger
	AlterScripts  []AlterScript
	Methods       []string
	Rights        []DocRight
}

type TableField struct {
	Name    string
	Type    string
	Size    int64
	Ext     string
	Enum    FieldEnum
	Comment string
}

type FieldEnum struct {
	Name    string
	Default string
}

type FkConstraints struct {
	Fld  string
	Ref  string
	Fk   string
	Name string
	Ext  string
}

type TableIndex struct {
	Name   string
	Fld    []string
	Unique bool
	Using  string
	Where  string
}

type Trigger struct {
	Name      string
	FuncName  string
	When      string
	Ref       string
	TableName string //поле заполняется перед генерацией шаблона
}

type AlterScript struct {
	Name string
}

type DocRight struct {
	Method string
	Allow  []string
}

//прасинг файла с main.toml
func processFileMain(path string) (err error) {

	tree, err := toml.LoadFile(path)
	if err != nil {
		if err != nil {
			fmt.Printf("Error: toml.LoadFile path:'%s': %s \n", path, err)
		}
		return
	}
	t := TmplMain{Tree: tree}

	if !t.Tree.Has("docType") {
		return errors.New(fmt.Sprintf("Uknown docType in file %s. Write docType name in file.", path))
	}
	t.writeDocType()

	//добавляем название документа в массив, для того чтобы сохранить последовательность загрузки моделей.
	docTypeSortArr = append(docTypeSortArr, t.DocType)

	t.createDocIfNotExist()
	t.fillTableName()
	t.fillTableExt()
	t.fillTableComment()
	t.fillEnums()
	t.fillFields()
	t.fillFkConstraints()
	t.fillIndex()
	t.fillTriggers()
	t.fillAlterScripts()
	t.fillMethods()
	t.fillRights()

	return
}

func (t *TmplMain) writeDocType() {
	t.DocType = t.Tree.Get("docType").(string)
}

func (t *TmplMain) createDocIfNotExist() {
	if len(t.DocType) > 0 {
		_, ok := docModels.Docs[t.DocType]
		if !ok {
			docModels.Docs[t.DocType] = &Doc{
				DocType:  t.DocType,
				TmplMain: t,
			}
		} else {
			docModels.Docs[t.DocType].TmplMain = t
		}
	}
}

func (t *TmplMain) fillEnums() {
	if t.Tree.Has("enums") {
		data := t.Tree.Get("enums").([]*toml.Tree)
		m := make(map[string][]string)
		for _, res := range data {
			r := res.ToMap()
			m[r["name"].(string)] = castArrInterfaceToArrString(r["value"].([]interface{}))
		}
		t.Enums = m
	}
}

func (t *TmplMain) fillTableName() {
	if t.Tree.Has("tableName") {
		t.TableName = t.Tree.Get("tableName").(string)
	} else {
		checkErr(errors.New(fmt.Sprintf("In doc:'%s' missed field 'tableName'", t.DocType)), "")
	}
}

func (t *TmplMain) fillTableExt() {
	if t.Tree.Has("tableExtension") {
		t.TableExt = t.Tree.Get("tableExtension").(string)
	}
}

func (t *TmplMain) fillTableComment() {
	if t.Tree.Has("tableComment") {
		t.TableComment = t.Tree.Get("tableComment").(string)
	}
}

func (t *TmplMain) fillFields() {
	if t.Tree.Has("fields") {
		data := t.Tree.Get("fields").([]*toml.Tree)
		arr := make([]TableField, len(data))
		for i, res := range data {
			r := res.ToMap()
			tf := TableField{
				Name: r["name"].(string),
				Type: r["type"].(string),
			}
			if res.Has("size") {
				tf.Size = r["size"].(int64)
			}
			if res.Has("ext") {
				tf.Ext = r["ext"].(string)
			}
			if res.Has("enumName") {
				tf.Enum = FieldEnum{Name: r["enumName"].(string)}
				if res.Has("default") {
					tf.Enum.Default = r["default"].(string)
				}
			}
			if res.Has("comment") {
				tf.Comment = r["comment"].(string)
			}
			arr[i] = tf
		}
		t.Fields = arr
	} else {
		checkErr(errors.New(fmt.Sprintf("In doc:'%s' missed field 'fields'", t.DocType)), "")
	}
}

func (t *TmplMain) fillFkConstraints() {
	if t.Tree.Has("fkConstraints") {
		data := t.Tree.Get("fkConstraints").([]*toml.Tree)
		arr := make([]FkConstraints, len(data))
		for i, res := range data {
			r := res.ToMap()
			tf := FkConstraints{}
			if res.Has("fld") {
				tf.Fld = r["fld"].(string)
			}
			if res.Has("ref") {
				tf.Ref = r["ref"].(string)
			}
			if res.Has("fk") {
				tf.Fk = r["fk"].(string)
			}
			if res.Has("name") {
				tf.Name = r["name"].(string)
			} else {
				tf.Name = fmt.Sprintf("%s_fk", strings.TrimSuffix(tf.Fld, "_id"))
			}
			if res.Has("ext") {
				tf.Ext = r["ext"].(string)
			}

			arr[i] = tf
		}
		t.FkConstraints = arr
	}
}

func (t *TmplMain) fillIndex() {
	if t.Tree.Has("indexes") {
		data := t.Tree.Get("indexes").([]*toml.Tree)
		arr := make([]TableIndex, len(data))
		for i, res := range data {
			r := res.ToMap()
			tf := TableIndex{
				Name: r["name"].(string),
				Fld:  castArrInterfaceToArrString(r["fld"].([]interface{})),
			}
			if res.Has("unique") {
				tf.Unique = r["unique"].(bool)
			}
			if res.Has("using") {
				tf.Using = r["using"].(string)
			}
			if res.Has("where") {
				tf.Where = r["where"].(string)
			}
			arr[i] = tf
		}
		t.Indexes = arr
	}
}

func (t *TmplMain) fillTriggers() {
	if t.Tree.Has("triggers") {
		data := t.Tree.Get("triggers").([]*toml.Tree)
		arr := make([]Trigger, len(data))
		for i, res := range data {
			r := res.ToMap()
			tf := Trigger{
				Name:     r["name"].(string),
				FuncName: r["funcName"].(string),
				When:     r["when"].(string),
				Ref:      r["ref"].(string),
			}
			arr[i] = tf
		}
		t.Triggers = arr
	}
}

func (t *TmplMain) fillMethods() {
	if t.Tree.Has("methods") {
		data := t.Tree.Get("methods").([]interface{})
		arr := make([]string, len(data))
		for i, res := range data {
			arr[i] = res.(string)
		}
		t.Methods = arr
	}
}

func (t *TmplMain) fillAlterScripts() {
	if t.Tree.Has("alterScripts") {
		data := t.Tree.Get("alterScripts").([]interface{})
		arr := make([]AlterScript, len(data))
		for i, res := range data {
			arr[i] = AlterScript{res.(string)}
		}
		t.AlterScripts = arr
	}
}

func (t *TmplMain) fillRights() {
	if t.Tree.Has("rights") {
		data := t.Tree.Get("rights").([]*toml.Tree)
		arr := make([]DocRight, len(data))
		for i, res := range data {
			r := res.ToMap()
			tf := DocRight{Method: r["method"].(string)}
			if res.Has("allow") {
				tf.Allow = castArrInterfaceToArrString(r["allow"].([]interface{}))
			}
			arr[i] = tf
		}
		t.Rights = arr
	}
}
