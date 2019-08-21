-- триггер при изменении статуса пользователя

CREATE OR REPLACE FUNCTION trigger_user_change_state()
  RETURNS TRIGGER AS $$

DECLARE

  rbqMessage JSONB;

BEGIN

  IF (TG_OP = 'UPDATE')
  THEN
    -- обрабатываем только кейсы когда у пользователя меняется статус, но когда это не первоначальная регистрация
    -- так же игнорируем случае смены статуса на 'unknown', потому что мы никого не уведомляем об этом.
    IF NEW.state != OLD.state AND NEW.state != 'waitAuth' :: user_state AND NEW.state != 'unknown' :: user_state
    THEN

      -- создаем сообщение для RabbitMQ о смене статуса пользователя
      BEGIN
        rbqMessage = json_build_object('userId', OLD.id, 'userTgId', OLD.telegram_chat_id, 'stateNew', NEW.state, 'stateOld', OLD.state);

        INSERT INTO rbq_message
        (publisher_id, subscriber, message)
        VALUES
          ('1', 'user.state.change', rbqMessage);
      END;


    END IF;
  END IF;

  RETURN NEW;
END;

$$ LANGUAGE plpgsql;
