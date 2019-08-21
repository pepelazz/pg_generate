-- создание/обновление связи бар-сотрудник с ролью chief
-- параметры:
-- bar_id           type: int
-- fullname         type: string

DROP FUNCTION IF EXISTS bar_chief_upsert(barId INT, fullname TEXT );
CREATE OR REPLACE FUNCTION bar_chief_upsert(barId INT, fullname TEXT)
  RETURNS VOID
LANGUAGE plpgsql
AS $function$

DECLARE
  link     user_bar_link%ROWTYPE;
  userId   BIGINT;
BEGIN

  -- находим id пользователя
  EXECUTE ('SELECT id FROM "user" WHERE fullname=$1 AND deleted=false')
  INTO userId
  USING fullname;
  IF userId ISNULL
  THEN
    RAISE EXCEPTION 'not found user with fullname: %', fullname;
  END IF;

  -- находим связь между баром и его текущим шефом
  EXECUTE ('SELECT * FROM user_bar_link WHERE bar_id=$1 AND is_chief=TRUE AND deleted=FALSE')
  INTO link
  USING barId;

  IF link ISNULL
  THEN
    -- case1: у бара не было шефа. Назначаем сотрудника шефом
    EXECUTE ('INSERT INTO user_bar_link (user_id, bar_id, is_chief, position) VALUES ($1, $2, TRUE, $3) ' ||
             ' ON CONFLICT (user_id, bar_id) DO UPDATE SET is_chief=TRUE, deleted=FALSE')
    USING userId, barId, 'директор';

  ELSE
    -- case2: шеф у ресторана существует
    -- case: обновление сотрудника в существующей связи, если он изменился
    IF link.user_id != userId
    THEN
      -- убираем предыдущего директора
      EXECUTE ('UPDATE user_bar_link SET is_chief = FALSE WHERE id=$1')
      USING link.id;

      -- назначаем нового
      EXECUTE ('INSERT INTO user_bar_link (user_id, bar_id, is_chief, position) VALUES ($1, $2, TRUE, $3) ' ||
               ' ON CONFLICT (user_id, bar_id) DO UPDATE SET is_chief=TRUE')
      USING userId, barId, 'директор';
    END IF;

  END IF;

  RETURN;

END

$function$;