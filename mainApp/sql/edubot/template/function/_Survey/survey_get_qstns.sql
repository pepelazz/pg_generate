-- получение вопросов для данного опроса и данного пользователя
-- 1) проверка, что опрос в статусе 'opened'
-- 2) если нет неотвеченных вопросов, то возвращаем сообщение
-- 3) если все ок, то возвращаем коллекцию вопросов

DROP FUNCTION IF EXISTS survey_get_qstns(userId INT, survey INT);
CREATE OR REPLACE FUNCTION survey_get_qstns(userId INT, survey INT)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  survey_state TEXT;
  surveyTitle TEXT;
  info_msg     TEXT;
  result       JSON;

BEGIN

  -- проверяем статус опроса
  EXECUTE 'SELECT state::text, title, info_msg FROM survey WHERE id = $1'
  INTO survey_state, surveyTitle, info_msg
  USING survey;

  -- если статус 'closed', то выходим из обработки
  IF survey_state = 'closed'
  THEN
    RETURN json_build_object('code', 'error', 'message', info_msg, 'surveyTitle', surveyTitle);
  END IF;

  -- находим все неотвеченные вопросы для данного пользователя и данного опроса
  SELECT json_agg(x)
  INTO result
  FROM (WITH answered_qstns AS (SELECT *
                                FROM user_answer
                                WHERE user_id = userId)
  SELECT
    id,
    survey_id,
    state,
    text,
    type,
    true_answer,
    regex,
    answer,
    image,
    score,
    options
  FROM survey_qstn AS qstn
  WHERE qstn.survey_id = survey AND state = 'opened' AND qstn.id NOT IN (SELECT survey_qstn_id
                                                                         FROM answered_qstns)
    ORDER BY RANDOM()
       ) x;

  -- проверяем что если нет неотвеченных вопросов, то возвращаем сообщение
  IF result IS NULL
  THEN
    RETURN json_build_object('code', 'error', 'message', 'Вы ответили на все вопросы', 'surveyTitle', surveyTitle);
  END IF;

  RETURN json_build_object('code', 'success', 'result', result, 'surveyTitle', surveyTitle);

END

$function$;
