-- создание бара
-- параметры:
-- id              type: int
-- title           type: string
-- city            type: string
-- address         type: string
-- chief           type: string
-- sort_index      type: int

DROP FUNCTION IF EXISTS bar_list_upsert(params JSONB );
CREATE OR REPLACE FUNCTION bar_list_upsert(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE
  newBar       bar%ROWTYPE;
  b            JSONB;
  barList      JSONB := '[]' :: JSONB;
  updateValue  TEXT;
  queryStr     TEXT;
  checkMsg     TEXT;
  userId       BIGINT;
  metaInfo     JSONB;
  cntCreateBar INT := 0;
  cntUpdateBar INT := 0;
BEGIN

  FOR b IN SELECT *
           FROM jsonb_array_elements(params)
  LOOP

    -- проверка наличия обязательных параметров
    checkMsg = check_required_params(b, ARRAY ['title', 'city', 'address', 'chief', 'positions']);
    IF checkMsg IS NOT NULL
    THEN
      RETURN checkMsg;
    END IF;

    IF b ->> 'id' ISNULL OR (b ->> 'id') :: INT = 0 -- case: создания нового бара
    THEN
      DECLARE
        errMessage     TEXT;
        constraintName TEXT;
      BEGIN
        EXECUTE ('INSERT INTO bar (title, city, address, positions, sort_index) VALUES ($1, $2, $3, $4, $5) ' ||
                 'ON CONFLICT (city, address) DO UPDATE SET title=$1, positions=$4, sort_index=$5, deleted=FALSE RETURNING *;')
        INTO newBar
        USING
          (b ->> 'title'),
          (b ->> 'city'),
          (b ->> 'address'),
          text_array_from_json((b ->> 'positions'):: JSONB),
          (b ->> 'sort_index') :: INT;
        cntCreateBar = cntCreateBar + 1;
        EXCEPTION WHEN OTHERS
        THEN
          GET STACKED DIAGNOSTICS errMessage = MESSAGE_TEXT,
          constraintName = CONSTRAINT_NAME;
          IF constraintName = 'address_for_this_city_exist'
          THEN errMessage = format('Адрес "%s" для города: "%s" уже существует. \nНужно изменить адрес.',
                                   (b ->> 'address'),
                                   (b ->> 'city')); END IF;
          RAISE EXCEPTION '%', errMessage;
          -- Do nothing, and loop to try the UPDATE again.
      END;

    ELSE -- case: обновления существующего бара

      updateValue = '' || update_str_from_json(b, ARRAY [
      ['title', 'title', 'text'],
      ['city', 'city', 'text'],
      ['address', 'address', 'text'],
      ['positions', 'positions', 'jsonArrayText'],
      ['sort_index', 'sort_index', 'number'],
      ['deleted', 'deleted', 'bool']
      ]);

      queryStr = concat('UPDATE bar SET ', updateValue, ' WHERE id=', b ->> 'id', ' RETURNING *;');

      EXECUTE (queryStr)
      INTO newBar;

      -- случай когда записи с таким id не найдено
      IF row_to_json(newBar) ->> 'id' ISNULL
      THEN
        RAISE EXCEPTION 'wrong id: %', b ->> 'id';
      END IF;

      cntUpdateBar = cntUpdateBar + 1;

    END IF;

    -- добавляем/обновляем шефа для этого бара
    PERFORM bar_chief_upsert(newBar.id, (b ->> 'chief'));

    barList = barList || row_to_json(newBar) :: JSONB;
  END LOOP;

  metaInfo = json_build_object('cnt_create_bar', cntCreateBar, 'cnt_update_bar', cntUpdateBar);

  RETURN json_build_object('ok', TRUE, 'result', barList, 'meta_info', metaInfo);

END

$function$;

-- select * from bar_list_upsert('[
--      {"title":"Шашлыкофф", "city":"Новосибирск", "address":"Бориса Богаткова, 221", "chief":"Markov Dmitry MarkovD", "sort_index":0},
--      {"title":"Шашлыкофф", "city":"Иркутск", "address":"ул. Дзержинского дом 28", "chief":"Marchello Pepelazz", "sort_index":1}
--  ]')

--  select * from qstn_list_upsert('[{"id":0,"topic":"exam_march_2017","text":"Укажи ТРИ органа сердечно-сосудистой системы",
--                          "answers":["вены","легкие","желудок","кровеносные сосуды","сердце","пищевод"],
--                          "true_answers":["вены","кровеносные сосуды","сердце"],
--                          "type":"multi_choice","score":8,"material":"","image":"",
--                          "tag_theme":["экзамен01","кулинария","этикет"],"tag_skill":null,"details":"",
--                          "details_image":"","uniq_title":"exam_march_2017 Укажи ТРИ органа сердечно-сосудистой системы"}]')