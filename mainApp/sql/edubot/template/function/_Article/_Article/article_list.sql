
DROP FUNCTION IF EXISTS article.article_list(params JSONB );
CREATE OR REPLACE FUNCTION article.article_list(params JSONB)
  RETURNS VOID
LANGUAGE plpgsql
AS $function$


BEGIN
-- тест функции для схемы
END

$function$;
