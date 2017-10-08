-- обновление задания
-- параметры:
-- id         type: int
-- state      type: survey_state
-- title      type: string
-- options    type: jsonb
-- info_msg   type: string
-- sort_index type: int
-- deleted    type: bool
-- удалять можно только задания, у которых нет вопросов. TODO: добавить эту проверку в код


DROP FUNCTION IF EXISTS survey_update(params JSONB );
CREATE OR REPLACE FUNCTION survey_update(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  temp_var      survey%ROWTYPE;
  updateValue   TEXT;
  queryStr      TEXT;

BEGIN

  [[rightsTmpl "Survey" "survey_update"]]

  -- проверика наличия id
  IF params ->> 'id' ISNULL
  THEN
    RETURN json_build_object('code', 'error', 'message', 'missing prop: id ');
  END IF;

  updateValue = '' || update_str_from_json(params, ARRAY [
  ['title', 'title', 'text'],
  ['state', 'state', 'enum'],
  ['options', 'options', 'jsonb'],
  ['infoMsg', 'info_msg', 'text'],
  ['sortIndex', 'sort_index', 'number'],
  ['deleted', 'deleted', 'bool']
  ]);

  queryStr = concat('UPDATE survey SET ', updateValue, ' WHERE id=', params ->> 'id', ' RETURNING *;');

  EXECUTE (queryStr)
  INTO temp_var;

  -- случай когда записи с таким id не найдено
  IF row_to_json(temp_var) ->> 'id' ISNULL
  THEN
    RAISE NOTICE 'id: "%"', row_to_json(temp_var) ->> 'id';
    RETURN json_build_object('code', 'error', 'message', 'wrong id');
  END IF;

  RETURN json_build_object('code', 'success', 'result', row_to_json(temp_var));

END

$function$;
