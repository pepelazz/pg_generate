-- перевод сотрудника из одного бара в другой
-- параметры:
-- from_id       type: int
-- to_id         type: int
-- user_id       type: int

DROP FUNCTION IF EXISTS bar_user_transfer(params JSONB );
CREATE OR REPLACE FUNCTION bar_user_transfer(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE
  barTo        bar%ROWTYPE;
  barFrom      bar%ROWTYPE;
  userRecord   "user"%ROWTYPE;
  linkId       INT;
  checkMsg     TEXT;
  jsonRes      JSON;
  userPosition TEXT;
BEGIN

  -- проверка наличия обязательных параметров
  checkMsg = check_required_params(params, ARRAY ['from_id', 'to_id', 'user_id']);
  IF checkMsg IS NOT NULL
  THEN
    RETURN checkMsg;
  END IF;

  -- находим бар
  EXECUTE 'SELECT * from bar WHERE id=$1 AND deleted=FALSE;'
  INTO barTo
  USING (params ->> 'to_id') :: INT;

  IF barTo ISNULL
  THEN
    RETURN json_build_object('ok', FALSE, 'message', concat('bar not found. Wrong id: ', params ->> 'to_id'));
  END IF;

  -- увольняем сотрудника из бара (и проверяем что бар и сотрудник с такими id существуют)
  -- находим бар
  EXECUTE 'SELECT * from bar WHERE id=$1 AND deleted=FALSE;'
  INTO barFrom
  USING (params ->> 'from_id') :: INT;

  IF barFrom ISNULL
  THEN
    RETURN json_build_object('ok', FALSE, 'message', concat('bar not found. Wrong id: ', params ->> 'from_id'));
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
  USING barFrom.id, userRecord.id;

  IF linkId ISNULL
  THEN
    RETURN json_build_object('ok', FALSE, 'message',
                             concat_ws(' ', 'user', userRecord.fullname, 'not work in bar', barFrom.city,
                                       barFrom.address));
  END IF;

  EXECUTE 'UPDATE user_bar_link SET deleted=TRUE WHERE bar_id=$1 AND user_id=$2;'
  USING barFrom.id, userRecord.id;


  userPosition = (params ->> 'position');
  IF userPosition ISNULL
  THEN
    -- находим значение роли на предыдущей работе
    EXECUTE 'SELECT position FROM user_bar_link WHERE user_id=$1 AND bar_id=$2'
    INTO userPosition
    USING (params ->> 'user_id') :: BIGINT, (params ->> 'from_id') :: INT;
  END IF;

  -- связываем сотрудника с новым баром
  EXECUTE 'INSERT INTO user_bar_link (user_id, bar_id, position) VALUES ($1, $2, $3) ' ||
          'ON CONFLICT (user_id, bar_id) DO UPDATE SET deleted=FALSE, position=$3;'
  USING (params ->> 'user_id') :: BIGINT, barTo.id, userPosition;

  RETURN json_build_object('ok', TRUE, 'result', json_build_object('user', userRecord.fullname, 'bar',
                                                                   concat_ws(',', barTo.city, barTo.address)));

END

$function$;
