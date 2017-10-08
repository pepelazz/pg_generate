-- рейтинг по конкретному пользователю
-- параметры:
-- userId       type: int - id задания
-- orderBy      type: string - поле для сортировки и направление сортировки.

DROP FUNCTION IF EXISTS rating_by_user(params JSONB );
CREATE OR REPLACE FUNCTION rating_by_user(params JSONB)
  RETURNS JSON
LANGUAGE plpgsql
AS $function$

DECLARE

  result   JSON;
  metaInfo JSON;
  username TEXT;
  avatar   TEXT;
  userId   INT;

BEGIN

  -- Для student: автоматически подставляем userId текущего пользователя currentUserId
  -- для admin нужно передать userId для которого формируем отчет
  -------------------------------------------------------------------------------
  IF (params ->> 'currentUserRole') = ANY ('{"student"}' :: TEXT [])
  THEN
    userId = (params ->> 'currentUserId') :: INT;
  ELSIF (params ->> 'userId') ISNULL
    THEN
      RAISE EXCEPTION 'ERROR: write userId field';
  ELSE
    userId = (params ->> 'userId') :: INT;
  END IF;

  EXECUTE (
    'select array_to_json(array_agg(t)) from ' ||
    ' (select * from ' ||
    '   (select s.id as survey_id, s.title as survey_title, s.sort_index, sum(a.score) as score, count(a.*) as total_answer, count(q.*) as total_qstn, '
    ||
    '   (count(a.*)*100/count(q.*)) as percent, ' ||
    '   count(nullif(a.is_right, false)) as cnt_right, ' ||
    '   count(nullif(a.is_right, true)) as cnt_wrong ' ||
    '   from (select user_answer, score, user_id, survey_qstn_id, is_right from user_answer where user_id = $1) as a '
    ||
    '   right outer join survey_qstn as q on q.id = a.survey_qstn_id ' ||
    '   inner join survey as s on s.id = q.survey_id ' ||
    '   group by s.id ' ||
    '   ) as t1 where percent > 0' ||
    '   order by ' || (params ->> 'orderBy') ||
    ') AS t'
  )
  INTO result
  USING userId, (params ->> 'orderBy') :: TEXT;

  -- заполняем информацию по пользователю
  EXECUTE (
    ' SELECT name_first || '' '' || name_last, avatar FROM "user" WHERE id=$1')
  INTO username, avatar
  USING userId;

  metaInfo = json_build_object('username', username, 'avatar', avatar, 'user_id', userId,
                               'orderBy',
                               (params ->> 'orderBy'));

  RETURN json_build_object('code', 'success', 'result', result, 'metaInfo', metaInfo);

END

$function$;
