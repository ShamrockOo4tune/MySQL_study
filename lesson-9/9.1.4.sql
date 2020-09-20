-- --------------------------------------------------------
-- --------------------------------------------------------
-- Домашняя работа к уроку №9 (видеоурок) начинается здесь.
-- --------------------------------------------------------

-- Практическое задание по теме “Хранимые процедуры и функции, триггеры"

-- Задача 9.1.4 (по желанию) Пусть имеется любая таблица с календарным полем created_at. Создайте 
-- запрос, который удаляет устаревшие записи из таблицы, оставляя только 5 самых свежих записей.

create database if not exists august;
use august; 
drop table if exists dates;
create table dates (
	smth varchar(50),
	created_at date);

INSERT into dates values 
	('dfd', '2018-08-01'),
	('dfsdf', '2016-08-04'),
	('wwqe', '2018-08-16'),
	(null, '2018-08-17'),
	('jgh', '2018-08-27'),
	('kkg', '2018-08-22'),
	('ds', '2018-08-31');

drop table if exists tmp;
create temporary table tmp (smth varchar(50), created_at date);
insert into tmp (select * from dates order by created_at desc limit 5);

delete from dates;
insert into dates (select * from tmp);
select * from dates;	