-- создание задания
-- параметры:
-- title type: string - название задания
-- state type: string - default close
-- sortIndex: integer - индекс сортировки
-- infoMsg type: string - сообщение, которое показывается когда задание недоступно
-- options type: jsonb - различные опции

DROP FUNCTION IF EXISTS survey_create(params JSONB );
CREATE OR REPLACE FUNCTION survey_create(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE
  temp_var survey%rowtype;
  sortIndex INT;
BEGIN

  -- находим максимальный sort_index, для того чтобы новому полю присвоить max+1
  EXECUTE ('SELECT MAX(sort_index) from survey;')
  INTO sortIndex;

  EXECUTE ('INSERT INTO survey (title, info_msg, options, sort_index, state) VALUES ($1, $2, $3, $4, $5) RETURNING *;')
  INTO temp_var
  USING
    (params ->> 'title'),
    COALESCE(params ->> 'infoMsg', NULL),
    COALESCE(params ->> 'options', NULL)::JSONB,
    COALESCE((params ->> 'sortIndex')::INT, sortIndex+1),
    COALESCE((params ->> 'state')::survey_state, 'closed'::survey_state);

  RETURN json_build_object('code', 'success', 'result', row_to_json(temp_var));

END

$function$;
