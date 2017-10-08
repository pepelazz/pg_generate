-- Пример
--  updateValue = '' || update_str_from_json(params, ARRAY [
-- ['infoMsg', 'info_msg', 'text'],
-- ['state', 'state', 'enum']
-- ]);
-- первое значение - поле в json
-- второе значение - поле в postgres
-- третье значение - тип

DROP FUNCTION IF EXISTS update_str_from_json(params JSONB, arr VARCHAR [] );
CREATE OR REPLACE FUNCTION update_str_from_json(params JSONB, arr VARCHAR [])
  RETURNS TEXT
LANGUAGE plpgsql
AS $function$
DECLARE
  i             RECORD;
  m             VARCHAR [];
  columnNameStr TEXT :='(';
  valueStr      TEXT :='(';
BEGIN

  FOR i IN SELECT *
           FROM jsonb_each_text(params)
  LOOP
    FOREACH m SLICE 1 IN ARRAY arr
    LOOP
      IF m [1] = i.key
      THEN
        columnNameStr = concat(columnNameStr, concat(m [2], ','));
        CASE m [3]
          WHEN 'text'
          THEN valueStr = concat(valueStr, quote_literal(i.value), ',');
          WHEN 'enum'
          THEN valueStr = concat(valueStr, quote_literal(i.value), ',');
          WHEN 'jsonb'
          THEN valueStr = concat(valueStr, quote_literal(i.value :: JSONB), ',');
          WHEN 'number'
          THEN valueStr = concat(valueStr, i.value, ',');
          WHEN 'bool'
          THEN valueStr = concat(valueStr, i.value, ',');
          WHEN 'arrayText'
          THEN valueStr = concat(valueStr, quote_literal(string_to_array(trim(i.value), '|')), ',');
        ELSE
          RAISE NOTICE 'else case';
        END CASE;
      END IF;
    END LOOP;
  END LOOP;

  columnNameStr = rtrim(columnNameStr, ',');
  columnNameStr = concat(columnNameStr, ')');

  valueStr = rtrim(valueStr, ',');
  valueStr = concat(valueStr, ')');

  RETURN concat(columnNameStr, ' = ', valueStr);
END;
$function$;

