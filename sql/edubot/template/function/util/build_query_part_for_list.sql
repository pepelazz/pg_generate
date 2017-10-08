-- построение части строки запроса списка документов
-- параметры:
-- orderBy      type: string - поле для сортировки и направление сортировки.
-- pageNum      type: int - номер страницы. Дефолт: 1
-- perPage      type: int - количество записей на странице. Дефолт: 10

DROP FUNCTION IF EXISTS build_query_part_for_list(params JSONB );
CREATE OR REPLACE FUNCTION build_query_part_for_list(params JSONB)
  RETURNS TEXT
LANGUAGE plpgsql
AS $function$

DECLARE

  orderBy      TEXT;
  limitNum     TEXT;
  pageNum      INT;
  perPage      INT := COALESCE((params ->> 'perPage') :: INT, 10);
  page         INT := COALESCE((params ->> 'page') :: INT, 1);

BEGIN

  -- сборка сортировки
  IF (params ->> 'orderBy') IS NOT NULL
  THEN
    orderBy = concat(' ORDER BY ', (params ->> 'orderBy'));
  END IF;

  -- сборка pagination
  limitNum = concat(' LIMIT ', perPage, ' OFFSET ', COALESCE((page - 1) * perPage, 0));

  RETURN '' || COALESCE(orderBy, '') || limitNum;

END

$function$;
