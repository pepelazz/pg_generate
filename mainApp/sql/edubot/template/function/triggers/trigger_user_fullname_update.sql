
-- функция обновления поля fullname
CREATE OR REPLACE FUNCTION trigger_user_fullname_update() RETURNS trigger AS $$
BEGIN

    NEW.fullname  := COALESCE(NEW.name_last, '') || ' ' || COALESCE(NEW.name_first, '');

  RETURN NEW;
END;

$$ LANGUAGE plpgsql;
