-- обновление пользователя
-- параметры:
-- nameFirst   type: string   - имя
-- nameLast    type: string   - фамилия
-- state       type: string   - статус пользователя
-- login       type: string   - логин пользователя
-- role        type: string   - роль пользователя
-- authUserId  type: int      - id пользователя, который авторизовал данного пользователя
-- deleted     type: bool

DROP FUNCTION IF EXISTS user_update(params JSONB );
CREATE OR REPLACE FUNCTION user_update(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  temp_var    "user"%ROWTYPE;
  result      JSONB;
  updateValue TEXT;
  queryStr    TEXT;

BEGIN

  -- проверика наличия id
  IF params ->> 'id' ISNULL
  THEN
    RETURN json_build_object('code', 'error', 'message', 'missing prop: id ');
  END IF;

  updateValue = '' || update_str_from_json(params, ARRAY [
  ['nameFirst', 'name_first', 'text'],
  ['nameLast', 'name_last', 'text'],
  ['state', 'state', 'enum'],
  ['login', 'login', 'text'],
  ['role', 'role', 'text'],
  ['avatar', 'avatar', 'text'],
  ['authUserId', 'auth_user_id', 'number'],
  ['deleted', 'deleted', 'bool']
  ]);

  queryStr = concat('UPDATE "user" SET ', updateValue, ' WHERE id=', params ->> 'id', ' RETURNING *;');

  EXECUTE (queryStr)
  INTO temp_var;

  -- случай когда записи с таким id не найдено
  IF row_to_json(temp_var) ->> 'id' ISNULL
  THEN
    RETURN json_build_object('code', 'error', 'message', 'wrong id');
  END IF;

  result = row_to_json(temp_var) :: JSONB;

  RETURN json_build_object('code', 'success', 'result', result);

END

$function$;
