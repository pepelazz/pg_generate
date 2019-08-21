-- функция смены значения переменной rivescript barPosition после изменения должности сотрудника в баре

CREATE OR REPLACE FUNCTION user_bar_link_update()
  RETURNS TRIGGER AS $$

DECLARE
  params        JSONB;
  existPosition TEXT;
BEGIN

  IF TG_OP = 'INSERT'
  THEN
    EXECUTE 'INSERT INTO user_rivescript_var (user_id, var_name, var_value) VALUES ($1, $2, $3) ' ||
            'ON CONFLICT (user_id, var_name) DO UPDATE SET var_value=$3'
    USING NEW.user_id, 'barPosition', NEW.position;
  ELSIF TG_OP = 'UPDATE'
    THEN
      -- case: удаление сотрудника - прописано вручную в bar_user_remove. Иначе два триггер србатывают одновременно.
--       IF NEW.deleted != OLD.deleted AND NEW.deleted = TRUE
--       THEN
--         EXECUTE 'INSERT INTO user_rivescript_var (user_id, var_name, var_value) VALUES ($1, $2, $3) ' ||
--                 'ON CONFLICT (user_id, var_name) DO UPDATE SET var_value=$3'
--         USING NEW.user_id, 'barPosition', 'fired';
--       END IF;
      -- case: смена роли
      IF NEW.deleted != TRUE
      THEN
        -- сравниваем rivescript переменную с новой ролью, обновляем только в случае изменений
        EXECUTE 'SELECT var_value FROM user_rivescript_var WHERE user_id=$1 AND var_name=$2'
        INTO existPosition
        USING NEW.user_id, 'barPosition';

        IF existPosition != NEW.position
        THEN
          EXECUTE 'INSERT INTO user_rivescript_var (user_id, var_name, var_value) VALUES ($1, $2, $3) ' ||
                  'ON CONFLICT (user_id, var_name) DO UPDATE SET var_value=$3'
          USING NEW.user_id, 'barPosition', NEW.position;
        END IF;
      END IF;
  END IF;

  -- Result is ignored since this is an AFTER trigger
  RETURN NULL;
END;

$$ LANGUAGE plpgsql;