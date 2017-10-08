-- добавляем словари и настройки для полнотекстового поиска

DROP TEXT SEARCH DICTIONARY if exists ispell_ru cascade;
CREATE TEXT SEARCH DICTIONARY ispell_ru(
template=ispell,
  dictfile=ru,
  afffile=ru,
  stopwords=russian
);

DROP TEXT SEARCH DICTIONARY if exists ispell_en cascade;
CREATE TEXT SEARCH DICTIONARY ispell_en(
template=ispell,
  dictfile=en,
  afffile=en,
  stopwords=english
);

DROP TEXT SEARCH CONFIGURATION if exists ru cascade;
CREATE TEXT SEARCH CONFIGURATION ru(COPY=russian);

ALTER TEXT SEARCH CONFIGURATION ru
ALTER MAPPING
FOR word, hword, hword_part
WITH ispell_ru, russian_stem;

ALTER TEXT SEARCH CONFIGURATION ru
ALTER MAPPING
FOR asciiword, asciihword, hword_asciipart
WITH ispell_en,english_stem;

SET default_text_search_config='ru';