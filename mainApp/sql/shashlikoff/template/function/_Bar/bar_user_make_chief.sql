-- назначение сотрудника начальником
-- параметры:
-- bar_id   type: int
-- user_id  type: int
-- fullname type: string

DROP FUNCTION IF EXISTS bar_user_make_chief(params JSONB );
CREATE OR REPLACE FUNCTION bar_user_make_chief(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE
  bar        bar%ROWTYPE;
  userRecord "user"%ROWTYPE;
  userId     BIGINT;
  barId      INT;
  linkId     INT;
  checkMsg   TEXT;
BEGIN

  -- проверка наличия обязательных параметров
  checkMsg = check_required_params(params, ARRAY ['bar_id']);
  IF checkMsg IS NOT NULL
  THEN
    RETURN checkMsg;
  END IF;

  -- проверяем что указан либо user_id, либо fullname
  IF params ->> 'user_id' ISNULL AND params ->> 'fullname' ISNULL
  THEN
    RETURN json_build_object('ok', FALSE, 'message', 'missing prop: user_id or fullname');
  END IF;

  -- находим пользователя в случае если указан fullname
  IF params ->> 'fullname' IS NOT NULL
  THEN
    EXECUTE ('SELECT * FROM "user" WHERE fullname=$1 AND deleted=false')
    INTO userRecord
    USING params ->> 'fullname';
    IF userRecord ISNULL
    THEN
      RETURN json_build_object('ok', FALSE, 'message',
                               concat('not found user with fullname: ', params ->> 'fullname'));
    END IF;
  END IF;

  -- находим пользователя в случае если указан user_id
  IF params ->> 'user_id' IS NOT NULL
  THEN
    EXECUTE ('SELECT * FROM "user" WHERE id=$1 AND deleted=false')
    INTO userRecord
    USING (params ->> 'user_id')::BIGINT;
    IF userRecord ISNULL
    THEN
      RETURN json_build_object('ok', FALSE, 'message',
                               concat('not found user with id: ', params ->> 'user_id'));
    END IF;
  END IF;

  -- проверяем что бар с таким id существует
  EXECUTE 'SELECT * from bar WHERE id=$1 AND deleted=FALSE;'
  INTO bar
  USING (params ->> 'bar_id') :: INT;

  IF bar ISNULL
  THEN
    RETURN json_build_object('ok', FALSE, 'message', concat('bar not found. Wrong id: ', params ->> 'bar_id'));
  END IF;

  -- обновляем роль
  PERFORM bar_chief_upsert(bar.id, userRecord.fullname);

  RETURN json_build_object('ok', TRUE , 'result',
                           json_build_object('user', userRecord.fullname, 'bar', concat_ws(', ', bar.city, bar.address)));

END

$function$;