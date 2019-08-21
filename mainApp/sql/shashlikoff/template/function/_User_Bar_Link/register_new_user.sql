-- обработка формы регистрации нового пользователя
-- параметры:
-- user_id          type: int
-- bar_id           type: int
-- last_name        type: string
-- first_name       type: string
-- position         type: string

DROP FUNCTION IF EXISTS register_new_user(params JSONB );
CREATE OR REPLACE FUNCTION register_new_user(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE
  checkMsg TEXT;
  tempRes  JSON;
  chiefId  INT;
  result   JSON;

BEGIN

  -- проверка наличия обязательных параметров
  checkMsg = check_required_params(params, ARRAY ['user_id', 'bar_id', 'last_name', 'first_name', 'position']);
  IF checkMsg IS NOT NULL
  THEN
    RETURN checkMsg;
  END IF;

  -- обновляем поля user
  EXECUTE ('UPDATE "user" set last_name=$2, first_name=$3, options= COALESCE(options || $4, $4) WHERE id=$1')
  USING (params ->> 'user_id') :: BIGINT, params ->> 'last_name', params ->> 'first_name', jsonb_build_object(
      'register_state', 'wait_auth');

  tempRes = bar_user_add(params);

  IF (tempRes ->> 'ok') :: BOOL
  THEN
    EXECUTE 'SELECT user_id FROM user_bar_link WHERE bar_id=$1 AND is_chief=TRUE AND deleted=false'
    INTO chiefId
    USING (params ->> 'bar_id') :: INT;
    RETURN json_build_object('ok', true, 'result', json_build_object('chief_id', chiefId));
  ELSE RETURN tempRes; END IF;

END

$function$;