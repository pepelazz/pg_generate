-- получение списка пользователей
-- параметры:
-- state          type: user_state - статус пользователя
-- authUserId     type: int - id пользователя, который авторизовал
-- deleted        type: bool - удаленные / существующие. Дефолт: false
-- orderBy        type: string - поле для сортировки и направление сортировки. Например, orderBy: "id desc"
-- pageNum        type: int - номер страницы. Дефолт: 1
-- perPage        type: int - количество записей на странице. Дефолт: 10
-- searchFullname type: string - текстовый поиск по fullname


DROP FUNCTION IF EXISTS user_list(params JSONB );
CREATE OR REPLACE FUNCTION user_list(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  result       JSON;
  metaInfo     JSON;
  docState     user_state;
  condQueryStr TEXT;
  whereStr     TEXT;
  amount       INT;

BEGIN

  -- сборка условия WHERE (where_str_build - функция из папки base)
  whereStr = where_str_build(params, 'doc', ARRAY [
  ['enum', 'state', 'doc.state'],
  ['ilike', 'searchFullname', 'doc.fullname']
  ]);

  -- финальная сборка строки с условиями выборки (build_query_part_for_list - функция из папки base)
  condQueryStr = '' || whereStr || build_query_part_for_list(params);

  EXECUTE (
    ' SELECT array_to_json(array_agg(t)) FROM (SELECT *  FROM "user" as doc ' ||  condQueryStr || ') AS t')
  INTO result;

  -- считаем количество записей для pagination
  EXECUTE (
    ' SELECT COUNT(*) FROM "user" as doc ' || COALESCE(whereStr, ''))
  INTO amount;

  metaInfo = json_build_object('amount', amount);

  RETURN json_build_object('code', 'success', 'result', result, 'metaInfo', metaInfo);

END

$function$;
