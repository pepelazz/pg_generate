-- создание вопроса задания
-- параметры:
-- text         type: string    - текст вопроса
-- survey_id    type: int       - id задания, к которому прикреплен вопрос
-- state        type: string    - Дефолт close
-- type         type: string    - тип вопроса. Дефолт one_choice
-- true_answer  type: []string  - массив правильных ответов
-- regex        type: []string  - массив regex строк
-- answer       type: []string  - варианты ответа в случае если тип вопроса предполагает выбор из вариантов
-- image        type: string    - url картинки
-- score        type: double    - баллы за вопрос. Дефолт 0
-- options      type: jsonb     - различные опции

DROP FUNCTION IF EXISTS survey_qstn_create(params JSONB );
CREATE OR REPLACE FUNCTION survey_qstn_create(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  temp_var    survey_qstn%ROWTYPE;
  result      JSONB;
  surveyTitle TEXT; -- названия задания, к которому прикреплен вопрос

BEGIN

  EXECUTE ('INSERT INTO survey_qstn (survey_id, text, true_answer, state, type, answer, regex, image, score, options) '
           ||
           'VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING *;')
  INTO temp_var
  USING
    (params ->> 'surveyId') :: INT,
    (params ->> 'text'),
    string_to_array((params ->> 'trueAnswer')::TEXT, '|'),
    COALESCE((params ->> 'state') :: survey_qstn_state, 'opened' :: survey_qstn_state),
    COALESCE((params ->> 'type') :: survey_qstn_type, 'one_choice' :: survey_qstn_type),
    string_to_array((params ->> 'answer')::TEXT, '|'),
    string_to_array((params ->> 'regex')::TEXT, '|'),
    COALESCE(params ->> 'image', NULL),
    COALESCE((params ->> 'score') :: DOUBLE PRECISION, 0.0),
    COALESCE(params ->> 'options', NULL) :: JSONB;

  result = row_to_json(temp_var) :: JSONB;

  -- находим название задания, к которому прикреплен вопрос и заполняем свойство 'survey_title'
  EXECUTE ('SELECT title FROM survey WHERE id=$1')
  INTO surveyTitle
  USING (result ->> 'survey_id') :: INT;

  result = result || jsonb_build_object('survey_title', surveyTitle);

  RETURN json_build_object('code', 'success', 'result', result);

END

$function$;
