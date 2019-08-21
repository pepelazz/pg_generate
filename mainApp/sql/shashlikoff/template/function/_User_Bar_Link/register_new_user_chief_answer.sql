-- обработка ответа шефа на запрос о регистрации пользователя
-- параметры:
-- user_id          type: int
-- is_auth          type: bool

DROP FUNCTION IF EXISTS register_new_user_chief_answer(params JSONB );
CREATE OR REPLACE FUNCTION register_new_user_chief_answer(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE
  checkMsg TEXT;
BEGIN

  -- проверка наличия обязательных параметров
  checkMsg = check_required_params(params, ARRAY ['user_id', 'is_auth']);
  IF checkMsg IS NOT NULL
  THEN
    RETURN checkMsg;
  END IF;

  IF (params ->> 'is_auth') :: BOOL
  THEN
    -- обновляем поля user
    EXECUTE ('UPDATE "user" set options= COALESCE(options || $2, $2) WHERE id=$1')
    USING (params ->> 'user_id') :: BIGINT, jsonb_build_object('register_state', 'success');
  ELSE
    -- обновляем поля user
    EXECUTE ('UPDATE "user" set state=$2, options= COALESCE(options || $3, $3) WHERE id=$1')
    USING (params ->> 'user_id') :: BIGINT, 'blocked'::user_state, jsonb_build_object('register_state', 'blocked');
    -- удаляем пользователя из связей с баром
    EXECUTE ('UPDATE user_bar_link set deleted= true WHERE user_id=$1')
    USING (params ->> 'user_id') :: BIGINT;
  END IF;

  RETURN json_build_object('ok', TRUE );

END

$function$;