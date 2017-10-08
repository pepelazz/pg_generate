-- функция обновления статуса вновь зарегестрировавшегося пользователя
DROP FUNCTION IF EXISTS register_new_user_change_state(state TEXT, userId INT, authUserId INT );
CREATE OR REPLACE FUNCTION register_new_user_change_state(state TEXT, userId INT, authUserId INT)

  RETURNS JSONB

AS $$

DECLARE

  result       JSONB;
  currentState user_state;

BEGIN

  -- находим текущее состояние пользователя
  EXECUTE 'SELECT state FROM "user" WHERE id = $1'
  INTO currentState
  USING userId;

  -- проверяем что пользователь с таким id существует
  IF currentState ISNULL
  THEN
    RAISE EXCEPTION 'Nonexistent ID user: %', userId
    USING HINT = 'Please check your user id';
  END IF;

  -- меняем состояние пользователя, только если он в статусе 'waitAuth'
  -- (подразумевается, что если уже кто-то изменил статус, то мы его не перезаписываем)
  IF currentState = 'waitAuth' :: user_state
  THEN
    EXECUTE 'UPDATE "user" SET (state, auth_user_id) = ($2, $3) WHERE id=$1;'
    USING userId, state :: user_state, authUserId;
    result = json_build_object('code', 'success', 'message', 'user state changed');
  ELSE
    result = json_build_object('code', 'success', 'message', 'user state not changed, because it was not "new"');
  END IF;

  RETURN result;

END

$$ LANGUAGE plpgsql;

