-- Lesson 4 Homework starts here
-- on 02.09.2020

-- task 4.3.: Повторить все действия с CRUD

-- INSERT #1
-- Вставляем одну запись:
INSERT into users (email ,pass ,name ,surname ,phone ,gender ,birthday ,hometown ,photo_id ,created_at ) values
('qwe@asdf.qw','fdkjgsdflskdjfgsdfg142356214','Сергей','Сергеев','123123123','m','1983-03-21','Одинцово',395, '2020-08-31 22:55:58.0');

-- Вставляем пачку записей:
INSERT into users (email ,pass ,name ,surname ,phone ,gender ,birthday ,hometown ,photo_id ,created_at ) values
('ejaslem1@typepad.com','c2ca3c61fe024e49a9c758a109611c65aac31a15','Вера','Клюквина','804-926-3977','f','1987-03-15','Сатка',652,'2020-08-31 22:55:58.0'),
('cattack2@unc.edu','5f91ea663688cc873be65a6cc107f07da84664ae','Ирина','Кийко','213-952-7247','f','1986-05-22','Зубцов',75,'2020-08-31 22:55:58.0'),
('scasotti3@usgs.gov','f93c320ee2275544eb1b42d8278133c343fa5030','Виктория','Водопьянова','418-701-1526','f','1984-04-06','Костерево',418,'2020-08-31 22:55:58.0'),
('segginton4@cam.ac.uk','e6ab5f555555fb26c7c60ddd23c8118307804330','Дмитрий','Тимашов','451-335-9033','m','1984-06-19','Горячий Ключ',865,'2020-08-31 22:55:58.0'),
('aswaddle5@altervista.org','b25e49362b83833eece7d225717f2e285213bf25','Владислав','Авраменко','187-446-2339','m','1987-07-07','Павловское',72,'2020-08-31 22:55:58.0'),
('fleahey6@ftc.gov','07521436ef4b4ad464ed04cdceb99f422bbbd9c5','Алексей','Величко','295-179-8252','m','1984-11-27','Кедровый',763,'2020-08-31 22:55:58.0'),
('rcasley7@exblog.jp','5aac7b105729d4ad431db6a4e73604ecec132fa8','Артем','Филипцов','323-732-2265','m','1984-08-04',NULL,601,'2020-08-31 22:55:58.0'),
('rlantry8@pen.io','ba6c51c3064c20f9de84d4ed69733d9dd408e504','Елена','Колдаева','373-114-4657','f','1989-08-07','Усолье-Сибирское',713,'2020-08-31 22:55:58.0'),
('egoatcher9@behance.net','16f4e6ac1aedd2d9707b56d767f452f3246e67f7','Андрей','Антипов','877-485-8608','m','1984-09-04','Яхрома',760,'2020-08-31 22:55:58.0')
;

-- INSERT #2
-- Вставляем именованно набором занчений:
INSERT  into users set
    email ='dcolquita@ucla.edu',
    pass ='1487c1cf7c24df739fc97460a2c791a2432df062',
    name ='Евгений', 
    surname ='Евгений', -- Ошибка при вводе. TODO поправить 'Грачев'
    phone ='Евгений', -- Ошибка при вводе. TODO поправить '974-490-6651'
    gender ='m',
    birthday ='1987-11-26',
    hometown ='Боровое',
    photo_id ='663';

-- INSERT #3 insert ... select
-- воспроизводим структуру таблицы users:
SHOW create table users ;

-- копируем данные из users в users1:
INSERT users1 SELECT * from users ;


-- создаем usesrs1 со структурой users:
CREATE TABLE `users1` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `email` varchar(150) DEFAULT NULL,
  `pass` varchar(100) DEFAULT NULL,
  `name` varchar(50) NOT NULL,
  `surname` varchar(50) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `gender` char(1) DEFAULT NULL,
  `birthday` date DEFAULT NULL,
  `hometown` varchar(100) DEFAULT NULL,
  `photo_id` bigint unsigned DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `email` (`email`),
  KEY `phone` (`phone`),
  KEY `name` (`name`,`surname`)
);

   
-- Исправляем ошибки ввода стр.№№ 30 и 31 и заодно попрактикуем UPDATE:
UPDATE users 
    set surname ='Грачев', phone ='974-490-6651'
    WHERE name ='Евгений' and email ='dcolquita@ucla.edu';

-- некоторые эксперименты с запросом select:
SELECT  2+2*2;

select * from users1 limit 3 offset 100;

select name, surname, email from users1;

select concat(name, '. email: ',email) as 'user@email', phone FROM users1 limit 5 offset 100;

select * FROM users1 where name like 'А%';

select * FROM users1 where gender  is NULL ;

select name, surname FROM users1 where gender = 'm' or gender is NULL ;

select * FROM users1 where name like 'А_т%';

SELECT  COUNT(gender) FROM users where gender ='m' ;

DELETE from users1  where id  < 100;

INSERT users1 select * from users where id > 20 and id < 30;

insert users1 (email ,pass ,name ,surname ,phone ,gender ,birthday ,hometown ,photo_id) 
    SELECT email ,pass ,name ,surname ,phone ,gender ,birthday ,hometown ,photo_id FROM users
    where id > 30 and id < 35;
   
TRUNCATE table users1;

