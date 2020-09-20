-- --------------------------------------------------------
-- --------------------------------------------------------
-- Домашняя работа к уроку №9 (видеоурок) начинается здесь.
-- --------------------------------------------------------

-- Практическое задание по теме “Хранимые процедуры и функции, триггеры"

-- Задача 9.1.3 (по желанию) Пусть имеется таблица с календарным полем created_at. В ней размещены
-- разряженые календарные записи за август 2018 года '2018-08-01', '2016-08-04', '2018-08-16' и
-- 2018-08-17. Составьте запрос, который выводит полный список дат за август, выставляя в
-- соседнем поле значение 1, если дата присутствует в исходном таблице и 0, если она отсутствует.

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
	(null, '2018-08-17');

drop table if exists august;
create table august (summertime date);

delimiter //
drop procedure if exists fill_august//
create procedure fill_august()
	begin
		declare day_of_august date default '2018-08-01';
		declare i int default 1;
		while i <= 31 do
			insert into august values (day_of_august);
			set day_of_august = date_add(day_of_august, interval 1 day);
			set i = i + 1;
		end while;
	end//
delimiter ;

call fill_august();

select 
	a.summertime as 'golden days of august',
	if(a.summertime = d.created_at, 1, 0) as '1 or 0'
from august a
left join dates d
 	on a.summertime = d.created_at;