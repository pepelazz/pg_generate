-- увальнение сотрудника из бара
-- параметры:
-- bar_id           type: int
-- user_id          type: int

DROP FUNCTION IF EXISTS bar_user_remove(params JSONB );
CREATE OR REPLACE FUNCTION bar_user_remove(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE
  bar        bar%ROWTYPE;
  userRecord "user"%ROWTYPE;
  linkId     INT;
  checkMsg   TEXT;
BEGIN

  -- проверка наличия обязательных параметров
  checkMsg = check_required_params(params, ARRAY ['bar_id', 'user_id']);
  IF checkMsg IS NOT NULL
  THEN
    RETURN checkMsg;
  END IF;

  -- находим бар
  EXECUTE 'SELECT * from bar WHERE id=$1 AND deleted=FALSE;'
  INTO bar
  USING (params ->> 'bar_id') :: INT;

  IF bar ISNULL
  THEN
    RETURN json_build_object('ok', FALSE, 'message', concat('bar not found. Wrong id: ', params ->> 'bar_id'));
  END IF;

  -- находим сотрудника
  EXECUTE 'SELECT * from "user" WHERE id=$1 AND deleted=FALSE;'
  INTO userRecord
  USING (params ->> 'user_id') :: BIGINT;

  IF userRecord ISNULL
  THEN
    RETURN json_build_object('ok', FALSE, 'message', concat('user not found. Wrong id: ', params ->> 'user_id'));
  END IF;

  --проверяем работает ли данный сотрудник в этом баре
  EXECUTE 'SELECT id from user_bar_link WHERE bar_id=$1 AND user_id=$2 AND deleted=FALSE;'
  INTO linkId
  USING bar.id, userRecord.id;

  IF linkId ISNULL
  THEN
    RETURN json_build_object('ok', FALSE, 'message',
                             concat_ws(' ', 'user', userRecord.fullname, 'not work in bar', bar.city, bar.address));
  END IF;

  EXECUTE 'UPDATE user_bar_link SET deleted=TRUE WHERE bar_id=$1 AND user_id=$2;'
  USING bar.id, userRecord.id;

  -- в случае увольнения измененяем занчение rivescript переменной barPosition вручную, без триггера. Иначе кольцевая зависимость со срабатыванием триггеров и обновлением роли.
  EXECUTE 'INSERT INTO user_rivescript_var (user_id, var_name, var_value) VALUES ($1, $2, $3) ' ||
          'ON CONFLICT (user_id, var_name) DO UPDATE SET var_value=$3'
  USING userRecord.id, 'barPosition', 'fired';

  RETURN json_build_object('ok', TRUE, 'result', json_build_object('user', userRecord.fullname, 'bar',
                                                                   concat_ws(',', bar.city, bar.address)));

END

$function$;
