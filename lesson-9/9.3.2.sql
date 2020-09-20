-- --------------------------------------------------------
-- --------------------------------------------------------
-- Домашняя работа к уроку №9 (видеоурок) начинается здесь.
-- --------------------------------------------------------

-- Практическое задание по теме “Хранимые процедуры и функции, триггеры"

-- Задача 9.3.2 В таблице products есть два текстовых поля: name с названием товара и description с его
-- описанием. Допустимо присутствие обоих полей или одно из них. Ситуация, когда оба поля
-- принимают неопределенное значение NULL неприемлема. Используя триггеры, добейтесь
-- того, чтобы одно из этих полей или оба поля были заполнены. При попытке присвоить полям
-- NULL-значение необходимо отменить операцию.

drop table if exists products;
CREATE TABLE `products` (
  `id` serial,
  `name` varchar(255) DEFAULT NULL COMMENT 'Название',
  `description` text,
  `price` decimal(11,2) DEFAULT NULL COMMENT 'Цена',
  `catalog_id` int unsigned DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
  );
delimiter //
drop trigger if exists check_products_null//
create trigger check_products_null before insert on products
    for each row BEGIN
	if (new.name is null) and (new.description is null) then
  	SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Оба поля name и description не могут быть null';
  	END IF;
    end//
insert into products (name, description, price) values (null, 'not null', 1000.00 ) //
insert into products (name, description, price) values ('also not null', null, 1000.00 ) //
insert into products (name, description, price) values ('both', ' not null', 1000.00 ) //
insert into products (name, description, price) values (null, null, 1000.00 ) //
select * from products //

