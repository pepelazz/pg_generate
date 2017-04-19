DROP MATERIALIZED VIEW IF EXISTS article.level_view;
CREATE MATERIALIZED VIEW article.level_view AS
  SELECT *
  FROM article.article;
