[[$exchangeName := .Config.RbqExchangeName]]
CREATE OR REPLACE FUNCTION send_rbq_message()
  RETURNS TRIGGER AS $$

DECLARE

  publishState BOOLEAN;

BEGIN

  IF (TG_OP = 'INSERT')
  THEN

    SELECT amqp.publish(1, '[[$exchangeName]]', NEW.subscriber, NEW.message :: TEXT, 2)
    INTO publishState;

    IF (publishState)
    THEN
      NEW.state = 'success' :: rbq_message_state;
    ELSE
      NEW.state = 'fail' :: rbq_message_state;
    END IF;

  END IF;

  RETURN NEW;
END;

$$ LANGUAGE plpgsql;
