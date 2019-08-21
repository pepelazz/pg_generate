-- триггер для обновления индекса для полнотекстового поиска по таблице survey_qstn

CREATE OR REPLACE FUNCTION survey_qstn_vector_update()
  RETURNS TRIGGER AS $$

BEGIN
  IF (TG_OP = 'UPDATE')
  THEN
    IF (OLD.answer <> NEW.answer OR OLD.true_answer <> NEW.true_answer)
    THEN
      NEW.fts = setweight(coalesce(to_tsvector('ru', NEW.text), ''), 'A') || ' ' ||
                setweight(coalesce(array_to_tsvector(NEW.true_answer), ''), 'B') || ' ' ||
                setweight(coalesce(array_to_tsvector(NEW.answer), ''), 'D');
      RETURN NEW;
    ELSE
      RETURN NEW;
    END IF;
  ELSIF (TG_OP = 'INSERT')
    THEN
      NEW.fts = setweight(coalesce(to_tsvector('ru', NEW.text), ''), 'A') || ' ' ||
                setweight(coalesce(array_to_tsvector(NEW.true_answer), ''), 'B') || ' ' ||
                setweight(coalesce(array_to_tsvector(NEW.answer), ''), 'D');
      RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

