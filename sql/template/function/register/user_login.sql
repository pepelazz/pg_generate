-- функция обновления статуса вновь зарегестрировавшегося пользователя
DROP FUNCTION IF EXISTS user_login( LOGIN TEXT, PASSWORD TEXT );
CREATE OR REPLACE FUNCTION user_login(login TEXT, password TEXT)

  RETURNS JSONB

AS $$

DECLARE

  userId INT;
  t_row  user%ROWTYPE;

BEGIN

  -- провереям есть ли пользователь с таким username
  EXECUTE 'SELECT id FROM "user" WHERE login = $1'
  INTO userId
  USING login;

  IF userId ISNULL
  THEN
    RETURN json_build_object('code', 'error', 'message', 'UserNotFound');
  END IF;

  -- провереям пароль
  EXECUTE 'SELECT * FROM "user" WHERE login = $1 AND password = $2'
  INTO t_row
  USING login, password;
  --   id, username, telegram_chat_id, name_first, name_last, role, state

  -- случай когда пароль неверный
  IF row_to_json(t_row) ->> 'id' ISNULL
  THEN
    RETURN json_build_object('code', 'error', 'message', 'WrongPassword');
  END IF;

  -- обновляем поле is_token_valid, потому что оно нужно только для того чтобы перевести пользователя на логин страницу
  -- поэтому раз пользователь уже логинится, то переводим is_token_valid в состояние true
  EXECUTE 'UPDATE "user" SET is_token_valid=true WHERE login = $1'
  USING login;

  RETURN json_build_object('code', 'success', 'result', json_build_object(
      'id', t_row.id,
      'username', t_row.username,
      'telegram_chat_id', t_row.telegram_chat_id,
      'name_first', t_row.name_first,
      'name_last', t_row.name_last,
      'role', t_row.role,
      'state', t_row.state,
      'login', t_row.login
  ));

END

$$ LANGUAGE plpgsql;

