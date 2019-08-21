-- функция создание записей в таблице rabbit_event с историей изменений (при записи в таблицу отправляются события на rabbit)

CREATE OR REPLACE FUNCTION rabbit_event()
  RETURNS TRIGGER AS $$
DECLARE
  hString hstore;
BEGIN
  IF (TG_OP = 'INSERT')
  THEN
      hString = hstore(NEW) - ARRAY ['updated_at'];
  ELSIF (TG_OP = 'UPDATE')
    THEN
      -- считаем дельту между старой и новой версией
      -- из полученной дельты убираем поле updated_at
      hString = hstore(NEW) - hstore(OLD) - ARRAY ['updated_at'];
  END IF;

  INSERT INTO rbq_message
  (publisher_id, subscriber, message)
  VALUES
    (1, 'event', json_build_object('docType', TG_TABLE_NAME, 'id', NEW.id, 'flds', hstore_to_json_loose(hString)));

  RETURN NULL;
END;

$$ LANGUAGE plpgsql;

