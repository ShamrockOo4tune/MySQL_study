-- MySQL dump 10.13  Distrib 8.0.21, for Linux (x86_64)
--
-- Host: localhost    Database: 5_1_1
-- ------------------------------------------------------
-- Server version	8.0.21-0ubuntu0.20.04.4

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint unsigned NOT NULL DEFAULT '0',
  `name` varchar(255) DEFAULT NULL COMMENT 'Имя покупателя',
  `birthday_at` date DEFAULT NULL COMMENT 'Дата рождения',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'Геннадий','1990-10-05','2020-09-06 11:22:22','2020-09-06 11:22:22'),(2,'Наталья','1984-11-12','2020-09-06 11:22:22','2020-09-06 11:22:22'),(3,'Александр','1985-05-20','2020-09-06 11:22:22','2020-09-06 11:22:22'),(4,'Сергей','1988-02-14','2020-09-06 11:22:22','2020-09-06 11:22:22'),(5,'Иван','1998-01-12','2020-09-06 11:22:22','2020-09-06 11:22:22'),(6,'Мария','1992-08-29','2020-09-06 11:22:22','2020-09-06 11:22:22');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2020-09-06 19:38:47

--
-- Домашнее задание к уроку №5. Часть2. Тема: Агрегация данных.
--

-- Задача 5.2.2 "Подсчитайте количество дней рождения, которые приходятся на каждый из дней недели. Следует учесть, что необходимы дни недели текущего года, а не года рождения"

select
    id,
    name,
    birthday_at,
    if (
        year(timestampadd(year, timestampdiff(year, birthday_at, now()), birthday_at)) < year(now()),
        timestampadd(year, timestampdiff(year, birthday_at, now()) + 1, birthday_at),
        timestampadd(year, timestampdiff(year, birthday_at, now()), birthday_at)
    ) as Дата_ДР_в_этом_году,
    dayofweek(
        if (
            year(timestampadd(year, timestampdiff(year, birthday_at, now()), birthday_at)) < year(now()),
            timestampadd(year, timestampdiff(year, birthday_at, now()) + 1, birthday_at),
            timestampadd(year, timestampdiff(year, birthday_at, now()), birthday_at)
        )
    ) as №_дня_недели_ДР
from users;
select
    dayofweek(
        if (
            year(timestampadd(year, timestampdiff(year, birthday_at, now()), birthday_at)) < year(now()),
            timestampadd(year, timestampdiff(year, birthday_at, now()) + 1, birthday_at),
            timestampadd(year, timestampdiff(year, birthday_at, now()), birthday_at)
        )
    ) as №_дня_недели_ДР,
    count(*) as Количество_ДР_в_этот_день
from users
    group by №_дня_недели_ДР
        order by №_дня_недели_ДР;
