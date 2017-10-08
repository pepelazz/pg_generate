
-- создаем места
INSERT INTO business_place (title, title_en) VALUES
  ('ресторан в Академгородке', 'akadem'),
  ('ресторан в Омске', 'omsk'),
  ('ресторан на ул. Ленина', 'lenina')
ON CONFLICT (title, title_en)
  DO NOTHING;

INSERT INTO business_position (place_id, title) VALUES
  (1, 'официант'),
  (1, 'повар'),
  (1, 'менеджер'),
  (1, 'бармен'),

  (2, 'официант'),
  (2, 'повар'),
  (2, 'менеджер'),

  (3, 'официант'),
  (3, 'повар'),
  (3, 'менеджер'),
  (3, 'хостес')

ON CONFLICT (title, place_id)
  DO NOTHING;
--
-- добавляю пользователя для тестирования
-- INSERT INTO "user" (username, telegram_chat_id, name_last, login, password, role)
-- VALUES ('Pepelazz', '110579637', 'Marchello', 'pepelazz', 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3', 'admin')
-- ON CONFLICT (telegram_chat_id)
--   DO NOTHING;

-- INSERT INTO link_auth_business_place_user (user_id, place_id) VALUES
--   (2, 1),
--   (2, 2),
--   (2, 3)
-- ON CONFLICT (user_id, place_id)
--   DO NOTHING;

SELECT * FROM survey_get_all('{}');
