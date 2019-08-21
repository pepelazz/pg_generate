-- добавление сотрудника бара
-- параметры:
-- bar_id           type: int
-- user_id          type: int
-- position         type: string
-- name_last        type: string
-- name_first       type: string
-- name_mid         type: string

DROP FUNCTION IF EXISTS bar_user_add(params JSONB );
CREATE OR REPLACE FUNCTION bar_user_add(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE
  bar         bar%ROWTYPE;
  userRecord  "user"%ROWTYPE;
  linkId      INT;
  checkMsg    TEXT;
  queryStr    TEXT;
  updateValue TEXT;
BEGIN

  -- проверка наличия обязательных параметров
  checkMsg = check_required_params(params, ARRAY ['bar_id', 'user_id', 'position']);
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

  -- связываем сотрудника с новым баром
  EXECUTE 'INSERT INTO user_bar_link (user_id, bar_id, position) VALUES ($1, $2, $3) ' ||
          'ON CONFLICT (user_id, bar_id) DO UPDATE SET deleted=FALSE, position=$3'
  USING userRecord.id, bar.id, params ->> 'position';

  -- в случае передачи фио (из заполненной формы регистрации) вносим изменения в профиль пользователя
  IF params ->> 'name_last' IS NOT NULL
  THEN
    updateValue = '' || update_str_from_json(params, ARRAY [
    ['name_last', 'last_name_reg', 'text'],
    ['name_first', 'first_name_reg', 'text'],
    ['name_mid', 'mid_name_reg', 'text']
    ]);

    queryStr = concat('UPDATE "user" SET ', updateValue, ' WHERE id=', userRecord.id);

    EXECUTE (queryStr);
  END IF;

  RETURN json_build_object('ok', TRUE, 'result', json_build_object('user', userRecord.fullname, 'bar',
                                                                   concat_ws(',', bar.city, bar.address)));

END

$function$;
