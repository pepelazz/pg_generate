-- получение списка ответов пользователей
-- параметры:
-- userId       type: int - id пользователя, который который отвечал
-- surveyQstnId type: int - id вопроса, к которому относится ответа
-- surveyId     type: int - id задания, к которому относится вопрос
-- orderBy      type: string - поле для сортировки и направление сортировки. Например, orderBy: "created_at desc"
-- pageNum      type: int - номер страницы. Дефолт: 1
-- perPage      type: int - количество записей на странице. Дефолт: 10


DROP FUNCTION IF EXISTS user_answer_list(params JSONB );
CREATE OR REPLACE FUNCTION user_answer_list(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  result       JSON;
  metaInfo     JSON;
  condQueryStr TEXT;
  queryStr     TEXT;
  whereStr     TEXT;
  amount       INT;

BEGIN

  -- сборка условия WHERE (where_str_build - функция из папки base)
  whereStr = where_str_build(params, 'a', ARRAY [
  ['notQuoted', 'userId', 'doc.user_id'],
  ['notQuoted', 'surveyQstnId', 'doc.survey_qstn_id'],
  ['notQuoted', 'surveyId', 'doc.survey_id']
  ]);

  -- финальная сборка строки с условиями выборки (build_query_part_for_list - функция из папки base)
  condQueryStr = '' || whereStr || build_query_part_for_list(params);


  queryStr =  'from user_answer as a ' ||
              'inner join "user" as u on a.user_id = u.id ' ||
              'inner join survey_qstn as q on a.survey_qstn_id = q.id ' ||
              'inner join survey as s on q.survey_id = s.id ';

  EXECUTE (
    'SELECT array_to_json(array_agg(t)) FROM (select a.*, ' ||
    'u.name_first || '' '' || u.name_last as username, u.avatar as avatar, ' ||
    'q.text as qstn_text, q.type as qstn_type, q.true_answer as right_answer, q.score as qstn_score, q.survey_id as survey_id, ' ||
    's.title as survey_title ' || queryStr || condQueryStr || ') AS t')
  INTO result;

  -- считаем количество записей для pagination
  EXECUTE (
    ' SELECT COUNT(*) ' || queryStr || COALESCE(whereStr, ''))
  INTO amount;

  metaInfo = json_build_object('amount', amount);

  RETURN json_build_object('code', 'success', 'result', result, 'metaInfo', metaInfo);

END

$function$;
