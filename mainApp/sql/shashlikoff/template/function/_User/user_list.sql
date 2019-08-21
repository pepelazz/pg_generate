-- получение списка пользователей (переопределяем метод из основного eduBot, для получения списка пользователей привязанных к бару)
-- параметры:
-- state           type: user_state - статус пользователя
-- deleted         type: bool - удаленные / существующие. Дефолт: false
-- order_by        type: string - поле для сортировки и направление сортировки. Например, orderBy: "id desc"
-- page_num        type: int - номер страницы. Дефолт: 1
-- per_page        type: int - количество записей на странице. Дефолт: 1000
-- search_fullname type: string - текстовый поиск по fullname
-- bar_id          type: int - бар, к которому прикреплены пользователи

DROP FUNCTION IF EXISTS user_list(params JSONB );
CREATE OR REPLACE FUNCTION user_list(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  result       JSON;
  metaInfo     JSON;
  docState     user_state;
  condQueryStr TEXT;
  whereStr     TEXT;
  amount       INT;
  barId        INT;
  barCount        INT;

BEGIN

  -- рассматриваем отдельно случай когда список пользователей с привязкой к бару
  IF (params ->> 'bar_id') IS NOT NULL OR (params ->> 'chief_id') IS NOT NULL
  THEN
    -- если указан id шефа, то находим id бара
    IF (params ->> 'chief_id') IS NOT NULL
    THEN

      IF (params ->> 'bar_id') IS NOT
         NULL -- если указан bar_id, то это подразумевается что пользователь является шефом в нескольких барах и выбираем только соответствующий бар
      THEN
        EXECUTE 'SELECT bar_id FROM user_bar_link WHERE user_id=$1 AND bar_id=$2 AND is_chief=true AND deleted=false'
        INTO barId
        USING (params ->> 'chief_id') :: BIGINT, (params ->> 'bar_id') :: INT;
        IF barId ISNULL
        THEN
          RETURN json_build_object('ok', FALSE, 'message', 'Not found bar with for this chief.');
        END IF;
      ELSE
        -- проверяем что если пользователь является шефом больше чем в одном баре, то возвращаем ошибку с требованием указать id бара
        EXECUTE 'SELECT count(*) FROM user_bar_link WHERE user_id=$1 AND is_chief=true AND deleted=false'
        INTO barCount
        USING (params ->> 'chief_id') :: BIGINT;
        IF barCount > 1 THEN
          RETURN json_build_object('ok', FALSE, 'message', 'find more then one bar. You need write bar_id');
        END IF;

        EXECUTE 'SELECT bar_id FROM user_bar_link WHERE user_id=$1 AND is_chief=true AND deleted=false'
        INTO barId
        USING (params ->> 'chief_id') :: BIGINT;
        IF barId ISNULL
        THEN
          RETURN json_build_object('ok', FALSE, 'message', 'Not found bar with for this chief.');
        END IF;

      END IF;

    ELSE

      EXECUTE ('SELECT id FROM bar WHERE id=$1 AND deleted=FALSE')
      INTO barId
      USING (params ->> 'bar_id') :: INT;
      IF barId ISNULL
      THEN
        RETURN json_build_object('ok', FALSE, 'message', concat('Wrong bar id:', (params ->> 'bar_id')));
      END IF;

    END IF;

    EXECUTE 'SELECT array_to_json(array_agg(t)) FROM ( select u.*, l.position from "user" u
      left join user_bar_link l on l.user_id=u.id
      where u.deleted=false and l.deleted=false and l.bar_id=$1) t '
    INTO result
    USING barId;

    RETURN json_build_object('ok', TRUE, 'result', result);
  END IF;

  -- сборка условия WHERE (where_str_build - функция из папки base)
  whereStr = where_str_build(params, 'doc', ARRAY [
  ['enum', 'state', 'doc.state'],
  ['ilike', 'search_fullname', 'doc.fullname']
  ]);

  -- финальная сборка строки с условиями выборки (build_query_part_for_list - функция из папки base)
  condQueryStr = '' || whereStr || build_query_part_for_list(params);

  EXECUTE (
    ' SELECT array_to_json(array_agg(t)) FROM (SELECT *  FROM "user" as doc ' || condQueryStr || ') AS t')
  INTO result;

  -- считаем количество записей для pagination
  EXECUTE (
    ' SELECT COUNT(*) FROM "user" as doc ' || COALESCE(whereStr, ''))
  INTO amount;

  metaInfo = json_build_object('amount', amount);

  RETURN json_build_object('ok', TRUE, 'result', result, 'meta_info', metaInfo);

END

$function$;
