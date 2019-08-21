-- получение списка баров
-- параметры:
-- chief_id      type: int

DROP FUNCTION IF EXISTS bar_list_for_chief(params JSONB );
CREATE OR REPLACE FUNCTION bar_list_for_chief(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE
  result   JSON;
  checkMsg TEXT;
BEGIN

  -- проверка наличия обязательных параметров
  checkMsg = check_required_params(params, ARRAY ['chief_id']);
  IF checkMsg IS NOT NULL
  THEN
    RETURN checkMsg;
  END IF;

  EXECUTE (
    ' SELECT array_to_json(array_agg(t)) FROM (SELECT b.id, b.city, b.title, b.address from bar b
        inner join user_bar_link l on l.bar_id = b.id
        where l.user_id=$1 AND l.is_chief=true) AS t')
  INTO result
  USING (params ->> 'chief_id') :: BIGINT;

  RETURN json_build_object('ok', TRUE, 'result', result);

END

$function$;
