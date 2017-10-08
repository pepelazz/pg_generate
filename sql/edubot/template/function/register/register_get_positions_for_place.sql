

DROP FUNCTION IF EXISTS register_get_positions_for_place(placeName text);
CREATE OR REPLACE FUNCTION register_get_positions_for_place(placeName text)

  RETURNS JSONB

as $$

DECLARE

  placeId INTEGER;
  result JSONB;

BEGIN

  -- TODO: добавить обработку сценария когда место не найдено
  -- находим id заведения по названию
  EXECUTE 'SELECT id FROM business_place WHERE title = $1'
  INTO placeId
  USING placeName;

  IF placeId ISNULL
  THEN
    RAISE EXCEPTION 'Nonexistent ID business_place --> %', placeName
    USING HINT = 'Please check your business_place name';
  END IF;
  ------------------------------------------------------------------------

  -- Создаем временную таблицу, чтобы решить задачу формирования красивых названий полей в json.
  -- Иначе выводится в формате {f1:2, f2:}
  DROP TABLE IF EXISTS x;
  CREATE TEMP TABLE x (id INTEGER, title varchar(200)) ON COMMIT DROP;

  EXECUTE '
    SELECT json_agg((position.id, position.title)::x) FROM business_position AS position
    WHERE position.place_id = $1'
  INTO result USING placeId;

  RETURN result;

END

$$ LANGUAGE plpgsql;

