
-- функция обновления рабочих полей (created_at, updated_at)

CREATE OR REPLACE FUNCTION builtin_fld_update() RETURNS trigger AS $$
BEGIN

  IF (TG_OP = 'INSERT') THEN

    NEW.created_at  := now();
    NEW.updated_at  := now();

  ELSIF (TG_OP = 'UPDATE') THEN

    NEW.updated_at  := now();

  END IF;

  RETURN NEW;
END;

$$ LANGUAGE plpgsql;

-- DROP TRIGGER IF EXISTS user_created ON "user";
-- CREATE TRIGGER user_created BEFORE INSERT OR UPDATE ON "user" FOR EACH ROW EXECUTE PROCEDURE builtin_fld_update();
--
-- DROP TRIGGER IF EXISTS rbq_message_created ON rbq_message;
-- CREATE TRIGGER rbq_message_created BEFORE INSERT OR UPDATE ON rbq_message FOR EACH ROW EXECUTE PROCEDURE builtin_fld_update();
--
-- DROP TRIGGER IF EXISTS survey_created ON survey;
-- CREATE TRIGGER survey_created BEFORE INSERT OR UPDATE ON survey FOR EACH ROW EXECUTE PROCEDURE builtin_fld_update();
--
-- DROP TRIGGER IF EXISTS survey_qstn_created ON survey_qstn;
-- CREATE TRIGGER survey_qstn_created BEFORE INSERT OR UPDATE ON survey_qstn FOR EACH ROW EXECUTE PROCEDURE builtin_fld_update();
--
--

