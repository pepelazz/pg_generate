DROP FUNCTION IF EXISTS register_update_user(userId INT, placeName TEXT, posName TEXT, lastName TEXT, firstName TEXT );
CREATE OR REPLACE FUNCTION register_update_user(userId INT, placeName TEXT, posName TEXT, lastName TEXT, firstName TEXT)

  RETURNS JSONB

AS $$

DECLARE

  placeId        INTEGER;
  placeNameEn    TEXT;
  positionId     INTEGER;
  rbqMessageData JSONB;
  rbqMessage     JSONB;
  result         JSONB;

BEGIN

  -- находим id заведения по названию
  EXECUTE 'SELECT id, title_en FROM business_place WHERE title = $1'
  INTO placeId, placeNameEn
  USING placeName;

  IF placeId ISNULL
  THEN
    RAISE EXCEPTION 'Nonexistent ID business_place --> %', placeName
    USING HINT = 'Please check your business_place name';
  END IF;
  ------------------------------------------------------------------------

  -- находим id должности для данного заведения по навзванию
  EXECUTE 'SELECT id FROM business_position WHERE place_id = $1 AND title = $2 '
  INTO positionId
  USING placeId, posName;

  IF positionId ISNULL
  THEN
    RAISE EXCEPTION 'Nonexistent ID business_position --> place: %, title: %', placeName, posName
    USING HINT = 'Please check your business_position title for this business_place';
  END IF;

  ------------------------------------------------------------------------

  -- заполняем поля пользователя и меняем статус
  EXECUTE 'UPDATE "user" SET (name_last, name_first, state) = ($2, $3, $4) WHERE id=$1;'
  USING userId, lastName, firstName, 'waitAuth' :: user_state;

  -- создаем связь user <-> business_position
  EXECUTE 'INSERT INTO link_business_position_user (user_id, position_id) VALUES ($1, $2);'
  USING userId, positionId;

  ------------------------------------------------------------------------

  -- создаем сообщение для RabbitMQ при смене статуса пользователя на waitAuth
  BEGIN
    rbqMessageData = json_build_object('place', placeName, 'position', posName, 'nameLast', lastName, 'nameFirst',
                                       firstName);
    rbqMessage = json_build_object('user_id', userId, 'data', rbqMessageData);

    INSERT INTO rbq_message
    (publisher_id, subscriber, message)
    VALUES
      ('1', 'register.' || placeNameEn, rbqMessage);
  END;

  RETURN json_build_object('code', 'success');

END

$$ LANGUAGE plpgsql;

