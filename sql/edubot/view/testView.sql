DROP MATERIALIZED VIEW IF EXISTS user_level_view;
CREATE MATERIALIZED VIEW user_level_view AS
  SELECT *
  FROM article.article;
