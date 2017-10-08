-- сохранение ответа на вопрос
-- TODO: заменить answer TEXT на params JSONB
DROP FUNCTION IF EXISTS survey_save_answer(answer TEXT );
CREATE OR REPLACE FUNCTION survey_save_answer(answer TEXT)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  survey_id    INT;
  answer_id    INT;
  survey_state TEXT;
  survey_title TEXT;
  qstn_text    TEXT;
  answer_json  JSONB := answer :: JSONB;
  result       JSON;
  totalResult  JSON;
  rbqMessage   JSON;
  userFio      TEXT;

BEGIN

  --   проверяем статус опроса
  EXECUTE 'SELECT s.id, s.state::TEXT, s.title, q.text FROM survey_qstn AS q INNER JOIN survey AS s ON s.id = q.survey_id WHERE q.id = $1'
  INTO survey_id, survey_state, survey_title, qstn_text
  USING (answer_json ->> 'surveyQstnId') :: INT;

  -- если статус 'closed', то выходим из обработки
  IF survey_state = 'closed'
  THEN
    RETURN json_build_object('code', 'error', 'message', 'survey state "closed"');
  END IF;

  -- Сохраняем ответ пользователя
  EXECUTE 'INSERT INTO user_answer (user_id, survey_qstn_id, is_right, user_answer, score, created_at) VALUES ($1, $2, $3, $4, $5, now()) RETURNING id'
  INTO answer_id
  USING
    (answer_json ->> 'userId') :: INT,
    (answer_json ->> 'surveyQstnId') :: INT,
    (answer_json ->> 'isRight') :: BOOLEAN,
    answer_json ->> 'userAnswer',
    (answer_json ->> 'score') :: DOUBLE PRECISION;

  --  находим имя + фамилия пользователя для отправки в rabbitmq
  EXECUTE 'SELECT name_first || '' '' || name_last FROM "user" WHERE id = $1'
  INTO userFio
  USING (answer_json ->> 'userId') :: INT;

  -- Считаем общий результат пользователя по данному заданию
  -- сохраняем агрегированные результаты во временную таблицу (которую потом стираем), затем из нее формируем json

  EXECUTE
  'CREATE TABLE total_result as select sum(a.score) as sum, count(a.*) as total_answer, count(sq.*) as total_qstn, ' ||
  '(count(a.*)*100/count(sq.*)) as percent, count(nullif(a.is_right, false)) as cnt_right, '
  ||
  'count(nullif(a.is_right, true)) as cnt_wrong '
  'from user_answer as a ' ||
  'right outer join survey_qstn as sq on sq.id = a.survey_qstn_id ' ||
  'where (a.user_id = $1 or a.user_id is null) and sq.survey_id = $2 '
  USING
    (answer_json ->> 'userId') :: INT,
    survey_id;

  SELECT json_agg(x)
  INTO totalResult
  FROM
    (SELECT *
     FROM total_result) x;

  DROP TABLE IF EXISTS total_result;

  -- трансформируем массив из одного элемента просто в элемент
  totalResult = totalResult -> 0;

  -- добавляем поля в json  с ответом пользователя
  SELECT answer_json ||
         jsonb_build_object('id', answer_id, 'qstnText', qstn_text, 'surveyTitle', survey_title, 'username', userFio)
  INTO answer_json;

  -- создаем сообщение для RabbitMQ
  BEGIN
    rbqMessage = json_build_object('totalResult', totalResult, 'userAnswer', answer_json);

    INSERT INTO rbq_message
    (publisher_id, subscriber, message)
    VALUES
      ('1', 'survey.answer.' || survey_id, rbqMessage);
  END;

  RETURN json_build_object('code', 'success', 'totalResult', totalResult, 'userAnswer', answer_json);

END

$function$;
