-- Пример
-- whereStr = where_str_build(params, ARRAY[
--     ['enum', 'state', 'q.state'],
--     ['notQuoted', 'surveyId', 'q.survey_id']
--   ])
-- tableAlias - буква для названия таблицы для которой определяем свойство delete

DROP FUNCTION IF EXISTS where_str_build(params JSONB, tableAlias VARCHAR, arr VARCHAR [] );
CREATE OR REPLACE FUNCTION where_str_build(params JSONB, tableAlias VARCHAR, arr VARCHAR [])
  RETURNS TEXT
LANGUAGE plpgsql
AS $function$
DECLARE
  m        VARCHAR [];
  whereStr TEXT := concat(' where ', tableAlias, '.deleted=', COALESCE((params ->> 'deleted'), 'false'));
BEGIN

  FOREACH m SLICE 1 IN ARRAY arr
  LOOP

    -- ENUM
    IF m [1] = 'enum'
    THEN
      IF (params ->> m [2]) IS NOT NULL AND (params ->> m [2]) != 'all'
      THEN
        whereStr = concat(whereStr, concat(' AND ', m [3], '='), quote_nullable(params ->> m [2]));
      END IF;
    END IF;

    -- ЗНАЧЕНИЕ БЕЗ КОВЫЧЕК
    IF m [1] = 'notQuoted'
    THEN
      IF (params ->> m [2]) IS NOT NULL
      THEN
        whereStr = concat(whereStr, concat(' AND ', m [3], '='), params ->> m [2]);
      END IF;
    END IF;

    -- ПОИСК ПО ТЕКСТУ
    IF m [1] = 'ilike'
    THEN
      IF (params ->> m [2]) IS NOT NULL
      THEN
        whereStr = concat(whereStr, concat(' AND ', m [3], ' ilike'), quote_literal(concat('%', (params ->> m[2]), '%')));
      END IF;
    END IF;

    -- FULL TEXT SEARCH
    IF m [1] = 'fts'
    THEN
      IF (params ->> m [2]) IS NOT NULL
      THEN
        whereStr = concat(whereStr, concat(' AND ', m [3], ' @@ '),
                          quote_literal(replace(trim((params ->> m[2])), ' ', '&')), ':: tsquery' );
      END IF;
    END IF;

  END LOOP;

  RETURN whereStr;
END;
$function$;

