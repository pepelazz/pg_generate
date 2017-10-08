-- получение списка вопросов для заданий
-- параметры:
-- state          type: survey_qstn_state - статус вопроса
-- type           type: survey_qstn_type - тип вопроса
-- orderBy        type: string - поле для сортировки и направление сортировки. Например, orderBy: "id desc"
-- pageNum        type: int - номер страницы. Дефолт: 1
-- perPage        type: int - количество записей на странице. Дефолт: 10
-- deleted        type: bool - удаленные / существующие. Дефолт: false
-- fullTextSearch type: string - полнотекстовый поиск по полю fts
-- surveyId       type: int - поиск по полю survey_id

DROP FUNCTION IF EXISTS survey_qstn_list(params JSONB );
CREATE OR REPLACE FUNCTION survey_qstn_list(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  result       JSON;
  metaInfo     JSON;
  condQueryStr TEXT;
  whereStr     TEXT;
  -- поля для metainfo
  amount       INT;
  surveyTitle  TEXT;
  surveyId     INT;

BEGIN

  -- сборка условия WHERE (where_str_build - функция из папки base)
  whereStr = where_str_build(params, 'q', ARRAY [
  ['enum', 'state', 'q.state'],
  ['enum', 'type', 'q.type'],
  ['notQuoted', 'surveyId', 'q.survey_id'],
  ['fts', 'fullTextSearch', 'fts']
  ]);

  -- финальная сборка строки с условиями выборки (build_query_part_for_list - функция из папки base)
  condQueryStr = '' || whereStr || build_query_part_for_list(params);

  EXECUTE (
    ' SELECT array_to_json(array_agg(t)) FROM (SELECT q.*, s.title as survey_title FROM survey_qstn as q ' ||
    ' inner join survey as s on s.id = q.survey_id ' || condQueryStr || ') AS t')
  INTO result;

  -- считаем количество записей для pagination
  EXECUTE (
    ' SELECT COUNT(*) FROM survey_qstn as q ' || COALESCE(whereStr, ''))
  INTO amount;

  -- заполняем поле surveyTitle для metainfo
  -- case 1: если указан фильтр surveyId, то находим название для данного survey (чтобы вывести информацию для фильтра на экране)
  IF (params ->> 'surveyId') IS NOT NULL
  THEN
    EXECUTE (
      ' SELECT title FROM survey WHERE id=$1')
    INTO surveyTitle
    USING (params ->> 'surveyId') :: INT;
    surveyId = (params ->> 'surveyId') :: INT;
  END IF;
  -- case 2: если surveyId не указан, то пишем что это выборка вопросов для всех заданий
  IF surveyTitle ISNULL
  THEN
    surveyTitle = 'Все';
    surveyId = 0;
  END IF;

  metaInfo = json_build_object('amount', amount, 'survey',
                               json_build_object('id', surveyId, 'title', surveyTitle),
                               'type', COALESCE((params ->> 'type'), 'all'));

  RETURN json_build_object('code', 'success', 'result', result, 'metaInfo', metaInfo);

END

$function$;
