-- найти пользователя
-- параметры:
-- id          type: int      - id
-- login       type: string   - login

DROP FUNCTION IF EXISTS user_get(params JSONB );
CREATE OR REPLACE FUNCTION user_get(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  whereStr    TEXT;
  t_row       user%ROWTYPE;
  hasPassword BOOL;

BEGIN

  -- сборка условия WHERE
  IF (params ->> 'id') IS NOT NULL
  THEN
    whereStr = concat(' where doc.id=', quote_nullable((params ->> 'id')));
  END IF;

  IF (params ->> 'login') IS NOT NULL
  THEN
    whereStr = concat(' where doc.login=', quote_nullable((params ->> 'login')));
  END IF;

  IF (params ->> 'telegramChatId') IS NOT NULL
  THEN
    whereStr = concat(' where doc.telegram_chat_id=', quote_nullable((params ->> 'telegramChatId')));
  END IF;

  -- поиск пользователя
  EXECUTE (
    ' SELECT * FROM "user" as doc ' || COALESCE(whereStr, ''))
  INTO t_row;

  IF t_row.id ISNULL
  THEN
    RETURN json_build_object('code', 'error', 'message', 'UserNotFound');
  END IF;

  IF t_row.password ISNULL OR length(t_row.password) = 0
  THEN
    hasPassword = FALSE;
  ELSE
    hasPassword = TRUE;
  END IF;

  RETURN json_build_object('code', 'success', 'result', json_build_object(
      'id', t_row.id,
      'username', t_row.username,
      'telegram_chat_id', t_row.telegram_chat_id,
      'avatar', t_row.avatar,
      'name_first', t_row.name_first,
      'name_last', t_row.name_last,
      'role', t_row.role,
      'state', t_row.state,
      'login', t_row.login,
      'is_token_valid', t_row.is_token_valid,
      'has_password', hasPassword
  ));

END

$function$;
