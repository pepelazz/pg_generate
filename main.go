package pgGenerate

import (
	"github.com/pelletier/go-toml"
	"path/filepath"
	"text/template"
	"io/ioutil"
	"fmt"
	"database/sql"
	"github.com/lib/pq"
	"os"
	"log"
	"strconv"
)

var (
	config = Config{}
	docModels = DocModels{Docs: make(map[string]*Doc)}
	docTypeSortArr = []string{}
	sqlFuncTml template.Template // темплейты sql функций
)

type Config struct {
	User            string
	Password        string
	DbName          string
	Host            string
	Port            int64
	ModelDir        []string
	ViewDir         []string
	TemplateDir     []string
	RbqExchangeName string
}

type DocModels struct {
	Docs    map[string]*Doc
	Schemas *[]string
	Funcs   *[]string
	Config  struct {
			RbqExchangeName string
		}
}

type Doc struct {
	DocType  string
	TmplMain *TmplMain
}

func main(isPrintFiles bool) {
	// Шаг1: читаем toml файлы с конфигом
	readConfigFile()
	checkSourceDirExist()

	// Шаг2: читаем toml файлы с моделями
	for _, v := range config.ModelDir {
		err := filepath.Walk(v, readTomlModelDir())
		checkErr(err, "filepath.Walk")
	}

	// Шаг3.1: создаем sql скрипт для создания схем
	resultSchema, err := generateSchemaFile()
	checkErr(err, "generateSchemaFiles")
	if isPrintFiles {
		ioutil.WriteFile("generate_schema.sql", resultSchema, 0644)
	}

	// Шаг3.2: создаем sql скрипт для создания таблиц
	resultModel, err := generateModelFiles()
	checkErr(err, "generateModelFiles")
	if isPrintFiles {
		ioutil.WriteFile("generate_query.sql", resultModel, 0644)
	}

	// Шаг3.3: создаем sql скрипт для создания view
	resultView, err := generateViewFiles()
	checkErr(err, "generateViewFiles")
	if isPrintFiles {
		ioutil.WriteFile("generate_view.sql", resultView, 0644)
	}

	// Шаг3.4: создаем sql скрипт для функций (stored procedure)
	err = buildSqlFuncTmpl()
	checkErr(err, "buildSqlFuncTmpl")

	resultFunc, err := generateSqlFuncs()
	checkErr(err, "generateSqlFuncs")
	if isPrintFiles {
		ioutil.WriteFile("generate_func.sql", resultFunc, 0644)
	}

	// Шаг3.5: создаем sql скрипт для триггеров (он должен идти последним, потому что ссылается и на таблицы и на функции)
	resultTriggers, err := generateSqlTriggers()
	checkErr(err, "generateSqlTriggers")

	// Шаг3.6: импорт начальных данных
	resultMutations, err := generateSqlMutations()
	checkErr(err, "generateSqlMutations")

	// Шаг3.7: импорт начальных данных
	resultInitData, err := generateSqlInitData()
	checkErr(err, "generateSqlInitData")

	// Шаг4: Соединяем все части в единый sql скрипт
	result := append(resultSchema, resultModel...)
	result = append(result, resultView...)
	result = append(result, resultFunc...)
	result = append(result, resultTriggers...)
	result = append(result, resultMutations...)
	result = append(result, resultInitData...)
	if isPrintFiles {
		ioutil.WriteFile("generate_full.sql", result, 0644)
	}

	// Шаг5: Создаем базу если не существует
	createDb()

	// Шаг6: Выполняем скрипт
	executeQuery(result)

}

func Start(isPrintFiles bool) {
	main(isPrintFiles)
}

func readConfigFile() {
	tree, err := toml.LoadFile("config.toml")
	getFld := getTomlString(tree)
	getArrayFld := getTomlArray(tree)
	checkErr(err, "Read config.tmpl")
	config.User = getFld("postgres.user")
	config.Password = getFld("postgres.password")
	config.DbName = getFld("postgres.dbName")
	config.Host = getFld("postgres.host")
	if len(os.Getenv("PG_HOST")) > 0 {
		// перезаписываем имя хоста, если есть глобальная переменная (для docker-compose)
		config.Host = os.Getenv("PG_HOST")
	}
	config.Port = tree.Get("postgres.port").(int64)
	if len(os.Getenv("PG_PORT")) > 0 {
		// перезаписываем порт, если есть глобальная переменная (для docker-compose)
		port, err := strconv.ParseInt(os.Getenv("PG_PORT"), 10, 64)
		if err != nil {
			return
		}
		config.Port = port
	}

	config.ModelDir = getArrayFld("postgres.modelDir")
	config.ViewDir = getArrayFld("postgres.viewDir")
	config.TemplateDir = getArrayFld("postgres.templateDir")
	if tree.Has("postgres.rbqExchangeName") {
		config.RbqExchangeName = getFld("postgres.rbqExchangeName")
	}

	docModels.Config.RbqExchangeName = config.RbqExchangeName
}

// функция создания базы данных (если не существует)
func createDb() {
	dbinfo := fmt.Sprintf("postgres://%s:%s@%s:%v/%s?sslmode=disable", config.User, config.Password, config.Host, config.Port, "template1")
	println("pg_generate dbinfo:", dbinfo)
	db, err := sql.Open("postgres", dbinfo)
	err = db.Ping()
	checkErr(err, "Can't connect to postgres. Maybe wrong port.")
	defer db.Close()

	fmt.Printf("\nSTEP1: creating database... ")
	createDbQuery := fmt.Sprintf("CREATE DATABASE %s", config.DbName)
	_, err = db.Exec(createDbQuery)
	if err, ok := err.(*pq.Error); ok {
		if err.Code.Name() == "duplicate_database" {
			fmt.Printf("%s already exist\n", config.DbName)
			return
		} else {
			panic(err)
		}
	}

	fmt.Printf("%s created\n", config.DbName)

}

// функция выполнения собранных скриптов
func executeQuery(b []byte) {
	dbinfo := fmt.Sprintf("postgres://%s:%s@%s:%v/%s?sslmode=disable", config.User, config.Password, config.Host, config.Port, config.DbName)
	//dbinfo := fmt.Sprintf("user=%s password=%s dbname=%s sslmode=disable", config.User, config.Password, config.DbName)
	db, err := sql.Open("postgres", dbinfo)
	checkErr(err, "executeQuery")
	defer db.Close()

	fmt.Printf("STEP2: executing sql... ")
	_, err = db.Exec(string(b))
	if err, ok := err.(*pq.Error); ok {
		fmt.Printf("\nMessage: 	%s\n", err.Message)
		fmt.Printf("Query: 	%s\n", err.InternalQuery)
		fmt.Printf("Where: 	%s\n", err.Where)
		if len(err.Detail) > 0 {
			fmt.Printf("Detail: 	%s\n", err.Detail)
		}
		if len(err.Hint) > 0 {
			fmt.Printf("Hint: 	%s\n", err.Hint)
		}
		if len(err.InternalQuery) > 0 {
			fmt.Printf("Table: 	%s\n", err.Table)
		}
		if len(err.Column) > 0 {
			fmt.Printf("Column: 	%s\n", err.Column)
		}
		if len(err.DataTypeName) > 0 {
			fmt.Printf("Data: 	%s\n", err.DataTypeName)
		}
		os.Exit(1)
	}
	fmt.Printf("successfully completed \n")
}

func getTomlString(tree *toml.Tree) func(string) string {
	return func(fld string) string {
		switch v := tree.Get(fld).(type) {
		case string:
			return v
		case nil:
			log.Fatalf("In config missed field: %s", fld)
		default:
			log.Fatalf("In config wrong type field: %s", fld)

		}

		return ""
	}
}

func getTomlArray(tree *toml.Tree) func(string) []string {
	return func(fld string) []string {
		switch v := tree.Get(fld).(type) {
		case []interface{}:
			arr := []string{}
			for _, s := range v {
				res, ok := s.(string)
				if !ok {
					log.Fatalf("In config wrong type field: %s. Must be array of string", fld)
				}
				arr = append(arr, res)
			}
			return arr
		case nil:
			log.Fatalf("In config missed field: %s", fld)
		default:
			log.Fatalf("In config wrong type field: %s", fld)

		}

		return []string{}
	}
}

