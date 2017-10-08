-- удаление бара
-- параметры:
-- id           type: int

DROP FUNCTION IF EXISTS bar_delete(params JSONB );
CREATE OR REPLACE FUNCTION bar_delete(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE
  id       INT;
  bar      bar%ROWTYPE;
  checkMsg TEXT;
  userCnt  INT;
BEGIN

  -- проверка наличия обязательных параметров
  checkMsg = check_required_params(params, ARRAY ['id']);
  IF checkMsg IS NOT NULL
  THEN
    RETURN checkMsg;
  END IF;

  id = (params ->> 'id') :: INT;

  EXECUTE 'SELECT count(*) from user_bar_link WHERE bar_id=$1 AND deleted=FALSE;'
  INTO userCnt
  USING id;

  IF userCnt > 0 THEN
    RETURN json_build_object('ok', FALSE, 'message', concat('Bar has ', userCnt, ' linked users. Unlink users and then delete bar.'));
  END IF;


  EXECUTE 'UPDATE bar SET deleted=true WHERE id=$1 RETURNING *'
  INTO bar
  USING id;

  IF bar ISNULL
  THEN
    RETURN json_build_object('ok', FALSE, 'message', concat('bar not found. Wrong id: ', id));
  ELSE
    RETURN json_build_object('ok', TRUE, 'result', concat_ws(', ', bar.title, bar.city, bar.address));
  END IF;


END

$function$;
