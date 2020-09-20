-- --------------------------------------------------------
-- --------------------------------------------------------
-- Домашняя работа к уроку №9 (видеоурок) начинается здесь.
-- --------------------------------------------------------

-- Практическое задание по теме “Хранимые процедуры и функции, триггеры"

-- Задача 9.3.3 (по желанию) Напишите хранимую функцию для вычисления произвольного числа Фибоначчи.
-- Числами Фибоначчи называется последовательность в которой число равно сумме двух
-- предыдущих чисел. Вызов функции FIBONACCI(10) должен возвращать число 55.
create database if not exists shop;
use shop;
drop function if exists fibonachi;
delimiter //
create function fibonachi (n int unsigned)
returns int deterministic
begin
	declare fi int;
	declare i int default 2;
	declare f_1i int default 1;
	declare f_2i int default 0;
	if n < 2 then
		return n;
	end if;
	while i <= n do
		set fi = f_1i + f_2i;
		set f_2i = f_1i;
		set f_1i = fi;
		set i = i + 1;
	end while;
	return fi;
end
//
delimiter ;
select fibonachi(10);


