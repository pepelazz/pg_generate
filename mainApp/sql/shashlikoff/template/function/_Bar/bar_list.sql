-- получение списка баров
-- параметры:

DROP FUNCTION IF EXISTS bar_list(params JSONB );
CREATE OR REPLACE FUNCTION bar_list(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE
  result       JSON;
BEGIN

  EXECUTE (
    ' SELECT array_to_json(array_agg(t)) FROM (SELECT b.*, u.fullname chief FROM bar b
        inner join user_bar_link l on l.bar_id= b.id
        inner join "user" u on u.id = l.user_id
        where b.deleted=false and l.is_chief=true and l.deleted=false and u.deleted=false) AS t')
  INTO result;

  RETURN json_build_object('ok', TRUE, 'result', result);

END

$function$;
