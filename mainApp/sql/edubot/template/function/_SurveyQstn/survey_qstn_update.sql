-- обновление вопроса задания
-- параметры:
-- text         type: string    - текст вопроса
-- surveyId     type: int       - id задания, к которому прикреплен вопрос
-- state        type: string    - Дефолт close
-- type         type: string    - тип вопроса. Дефолт one_choice
-- trueAnswer   type: []string  - массив правильных ответов
-- regex        type: []string  - массив regex строк
-- answer       type: []string  - варианты ответа в случае если тип вопроса предполагает выбор из вариантов
-- image        type: string    - url картинки
-- score        type: double    - баллы за вопрос. Дефолт 0
-- options      type: jsonb     - различные опции
-- deleted      type: bool

DROP FUNCTION IF EXISTS survey_qstn_update(params JSONB );
CREATE OR REPLACE FUNCTION survey_qstn_update(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  temp_var    survey_qstn%ROWTYPE;
  result      JSONB;
  updateValue TEXT;
  surveyTitle TEXT; -- названия задания, к которому прикреплен вопрос
  queryStr    TEXT;


BEGIN

  -- проверика наличия id
  IF params ->> 'id' ISNULL
  THEN
    RETURN json_build_object('code', 'error', 'message', 'missing prop: id ');
  END IF;

  updateValue = '' || update_str_from_json(params, ARRAY [
  ['text', 'text', 'text'],
  ['surveyId', 'survey_id', 'number'],
  ['state', 'state', 'enum'],
  ['type', 'type', 'text'],
  ['trueAnswer', 'true_answer', 'arrayText'],
  ['regex', 'regex', 'arrayText'],
  ['answer', 'answer', 'arrayText'],
  ['image', 'image', 'text'],
  ['score', 'score', 'number'],
  ['options', 'options', 'jsob'],
  ['deleted', 'deleted', 'bool']
  ]);

  queryStr = concat('UPDATE survey_qstn SET ', updateValue, ' WHERE id=', params ->> 'id', ' RETURNING *;');

  EXECUTE (queryStr)
  INTO temp_var;

  -- случай когда записи с таким id не найдено
  IF row_to_json(temp_var) ->> 'id' ISNULL
  THEN
    RAISE NOTICE 'id: "%"', row_to_json(temp_var) ->> 'id';
    RETURN json_build_object('code', 'error', 'message', 'wrong id');
  END IF;

  result = row_to_json(temp_var) :: JSONB;

  -- находим название задания, к которому прикреплен вопрос и заполняем свойство 'survey_title'
  EXECUTE ('SELECT title FROM survey WHERE id=$1')
  INTO surveyTitle
  USING (result ->> 'survey_id') :: INT;

  result = result || jsonb_build_object('survey_title', surveyTitle);

  RETURN json_build_object('code', 'success', 'result', result);

END

$function$;
