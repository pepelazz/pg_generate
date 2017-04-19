-- получение списка опросов
-- параметры:
-- includeQstns   type: bool - включать список вопросов для каждого опроса
-- includeQstnCnt type: bool - включить количество вопросов в каждом задании
-- Правило: если выбран параметр includeQstns, то параметр includeQstnCnt игнорируется
-- state        type: survey_state - статус опроса
-- orderBy      type: string - поле для сортировки и направление сортировки. Например, surveyOrderBy: "id desc"
-- pageNum      type: int - номер страницы. Дефолт: 1
-- perPage      type: int - количество записей на странице. Дефолт: 10
-- deleted      type: bool - удаленные / существующие. Дефолт: false
-- searchTitle  type: string - текстовый поиск по полю title

DROP FUNCTION IF EXISTS survey_get_all(params JSONB );
CREATE OR REPLACE FUNCTION survey_get_all(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  result         JSON;
  metaInfo       JSON;
  includeQstns   BOOL;
  includeQstnCnt BOOL;
  whereStr       TEXT;
  surveyOrderBy  TEXT;
  surveyLimit    TEXT;
  queryStr       TEXT;
  condQueryStr   TEXT;
  surveyQnt      INT;

BEGIN

  includeQstns = params ->> 'includeQstns';
  includeQstnCnt = params ->> 'includeQstnCnt';

  -- сборка условия WHERE (where_str_build - функция из папки base)
  whereStr = where_str_build(params, 's', ARRAY [
  ['enum', 'state', 's.state'],
  ['ilike', 'searchTitle', 'title']
  ]);

  -- финальная сборка строки с условиями выборки
  condQueryStr = '' || whereStr || build_query_part_for_list(params);

  IF includeQstns
  THEN

    queryStr = 'SELECT array_to_json(array_agg(s)) FROM (
      SELECT id, title, sort_index, state, info_msg, deleted, (
        SELECT array_to_json(array_agg(row_to_json(qstn)))
          FROM ( SELECT * FROM survey_qstn WHERE s.id = survey_id) qstn
        ) AS qstns
      FROM survey s ' || condQueryStr || '
    ) AS s';

    EXECUTE (queryStr)
    INTO result;

  ELSE
    IF includeQstnCnt
    THEN
      -- case когда формируем список заданий со счетчиком прикрепленных вопросов
      queryStr = 'SELECT array_to_json(array_agg(s)) FROM (
      SELECT id, title, sort_index, state, info_msg, deleted, (
        SELECT row_to_json(q)
          FROM ( SELECT count(*) as num FROM survey_qstn WHERE s.id = survey_id) q
        ) AS qstn_cnt
      FROM survey s ' || condQueryStr || '
    ) AS s';
      EXECUTE (queryStr)
      INTO result;
    ELSE
      EXECUTE (
        ' SELECT array_to_json(array_agg(s)) FROM (SELECT id, title, sort_index, state, info_msg, deleted FROM survey s '
        ||
        condQueryStr || '
    ) AS s')
      INTO result;
    END IF;

  END IF;

  -- считаем количество записей для pagination
  EXECUTE (
    ' SELECT COUNT(*) FROM survey s ' || COALESCE(whereStr, ''))
  INTO surveyQnt;

  metaInfo = json_build_object('amount', surveyQnt);

  RETURN json_build_object('code', 'success', 'result', result, 'includeQstns', includeQstns, 'metaInfo', metaInfo);

END

$function$;
