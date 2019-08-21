-- общий рейтинг пользователей
-- параметры:
-- surveyId     type: int - id задания
-- orderBy      type: string - поле для сортировки и направление сортировки.
-- pageNum      type: int - номер страницы. Дефолт: 1
-- perPage      type: int - количество записей на странице. Дефолт: 10


DROP FUNCTION IF EXISTS rating_total(params JSONB );
CREATE OR REPLACE FUNCTION rating_total(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  result             JSON;
  metaInfo           JSON;
  condQueryStr       TEXT;
  whereStr           TEXT := '';
  amount             INT;
  surveyId           INT;
  surveyTitle        TEXT;

  userRatingPosition INT;
  maxPosition INT;
  minPosition INT;

BEGIN

  -- сборка условия WHERE
  IF (params ->> 'surveyId') IS NOT NULL
  THEN
    whereStr = concat(whereStr, ' WHERE sq.survey_id=', params ->> 'surveyId');
  END IF;

  -----------------------------------------------
  -- Для админа: полный рейтинг всех участников
  -----------------------------------------------
  IF (params ->> 'currentUserRole') = ANY ('{"admin"}' :: TEXT [])
  THEN

    EXECUTE (
      'SELECT array_to_json(array_agg(t)) FROM ' ||
      ' (SELECT ' ||
      '   ROW_NUMBER() OVER(ORDER BY score DESC) num, ' ||
      '   u.name_first || '' '' || u.name_last AS username, u.avatar, t1.*  FROM ' ||
      '   (SELECT a.user_id as id, SUM(a.score) AS score, COUNT(a.*) AS total_answer, ' ||
      '     COUNT(nullif(a.is_right, false)) AS cnt_right, ' ||
      '     COUNT(nullif(a.is_right, true)) AS cnt_wrong ' ||
      '     FROM user_answer AS a ' ||
      '     RIGHT OUTER JOIN survey_qstn AS sq ON sq.id = a.survey_qstn_id ' ||
      whereStr ||
      '     GROUP BY a.user_id' || build_query_part_for_list(params) ||
      ' ) as t1 ' ||
      ' INNER JOIN "user" AS u ON t1.id = u.id' ||
      ') AS t'
    )
    INTO result;

    -- считаем количество записей для pagination
    EXECUTE (
      'SELECT count(*) FROM ' ||
      ' (SELECT a.user_id FROM user_answer AS a ' ||
      '   RIGHT OUTER JOIN survey_qstn AS sq ON sq.id = a.survey_qstn_id ' ||
      whereStr ||
      '   GROUP BY a.user_id' ||
      ' ) as t'
    )
    INTO amount;
  END IF;

  ----------------------------------------------------------
  -- Для student: рейтинг участника и +- 5 других участника
  ----------------------------------------------------------
  IF (params ->> 'currentUserRole') = ANY ('{"student"}' :: TEXT [])
  THEN
    -- шаг1: находим позицию пользователя в рейтинге
    EXECUTE (
      'SELECT num FROM ' ||
      ' (SELECT ROW_NUMBER() OVER(ORDER BY score DESC) num, id FROM' ||
      '   (SELECT a.user_id as id, SUM(a.score) AS score FROM user_answer AS a ' ||
      '     RIGHT OUTER JOIN survey_qstn AS sq ON sq.id = a.survey_qstn_id ' ||
      whereStr ||
      '  GROUP BY a.user_id' ||
      ' ) as t1 ' ||
      ') AS t where id=$1'
    )
    INTO userRatingPosition
    USING (params ->> 'currentUserId') :: INT;

    --     шаг2: находим +/- 5 участников с рейтингом рядом с позицией текущего пользователя
    minPosition = userRatingPosition - 5;
    maxPosition = userRatingPosition + 4;
    EXECUTE (
      'SELECT array_to_json(array_agg(t)) FROM ' ||
      ' (SELECT ' ||
      '   ROW_NUMBER() OVER(ORDER BY score DESC) num, ' ||
      '   u.name_first || '' '' || u.name_last AS username, u.avatar, t1.*  FROM ' ||
      '   (SELECT a.user_id as id, SUM(a.score) AS score, COUNT(a.*) AS total_answer, ' ||
      '     COUNT(nullif(a.is_right, false)) AS cnt_right, ' ||
      '     COUNT(nullif(a.is_right, true)) AS cnt_wrong ' ||
      '     FROM user_answer AS a ' ||
      '     RIGHT OUTER JOIN survey_qstn AS sq ON sq.id = a.survey_qstn_id ' ||
      whereStr ||
      '     GROUP BY a.user_id' || build_query_part_for_list(params) ||
      ' ) as t1 ' ||
      ' INNER JOIN "user" AS u ON t1.id = u.id' ||
      ') AS t where num BETWEEN $1 AND $2'
    )
    INTO result
    USING minPosition, maxPosition;

  END IF;

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

  metaInfo = json_build_object('amount', amount, 'survey', json_build_object('id', surveyId, 'title', surveyTitle));

  RETURN json_build_object('code', 'success', 'result', result, 'metaInfo', metaInfo);

END

$function$;
