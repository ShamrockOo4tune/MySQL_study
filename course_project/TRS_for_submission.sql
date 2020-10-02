/*База данных TRS - представляет структуры для хранения информации о бизнес процессе подразделения ТРС
(сервис по предоставлению оборудования и персонала для выполнения нефтесервисных услуг при строительстве
нефтяных и газовых скважин). 
В своей работе ТРС использует большое количество различной номенклатуры оборудования - данные об оборудовании
хранятся в таблице assets.
Работы выполняются командой специалистов - детали по персоналу хранятся в таблице hands.
Работы выполняются на локациях (объектах заказчика и различных базах), данные хранятся в таблице locations.
Перемещения оборудования отслеживается при отправках c одной локации на другую (таблицы shipments, 
shipments_assets). Текущее местонахождение каждой единицы оборудования указывается в каждой записи в таблице 
assets, поле location_id.
При внесении записи об отправке оборудования (shipments_assets) предусмотрены триггеры для изменения 
значения местонахождения перемещаемой единицы оборудования.
В процессе ТРС работ производятся действия над различными типоразмерами труб (принадлежат заказчику).
Данные о трубах хранятся в таблице tubulars.
Основной процесс деятельности ТРС - работа (таблица jobs). Работы имеют отношения типа многие ко многим с
таблицами assets, hands, tubulars через таблицы jobs_assets, jobs_hands, jobs_tubulars.
Сведения о техобслуживании оборудования хранятся в таблице workorders, workorders_assets.
Целостность данных и непротиворечивость сведений достигается при использовании внешних ключей и триггеров.
Так при внесении записи о произведенной работе jobs, jobs_assets - отрабатывает триггер 
count_utilization... для обновления сведений о наработке использованного оборудования.
Составлены типовые запросы в виде select, view и процедуры для получения типовых сведений о бизнес процессе.
*/

Drop database if exists TRS;
Create Database TRS;
use TRS;

drop table if exists hands; -- сведения о персонале ТРС
create table hands (
	GIN bigint unsigned unique primary key, -- табельный номер
	alias varchar(50) unique, -- общий внутрикорпоративный псевдоним
	name varchar(255),
	surname varchar(255),
	grade char (3), -- разряд
	mapping char (3), -- приписан к геолокации по географии деятельности компании  
	jobs_run int unsigned, -- участвовал в полевых работах, раз
	sup_run int unsigned, -- в роли руководителя бригады, раз
	last_deployed date,
	last_onshift date,
	last_ondaysoff date,
	updated_at datetime default now()
	);

drop table if exists locations;
create table locations (
	id serial primary key,
	name varchar(255) unique,
	client_name varchar(255), -- название клиента
	contract varchar(255), -- номер контракта
	is_active bool, -- действующая локация или нет
	is_offshore bool, -- в море или на суше
	project_scope text -- описание
	);

drop table if exists tubulars; -- описание труб
create table tubulars (
	id serial primary key,
	OD float unsigned,
	wall_mm float unsigned,
	ppf float unsigned,
	drift float unsigned,
	grade varchar(255),
	`connection` varchar(255),
	coating varchar(255) default 'n/a',
	maximum int unsigned,
	optimum int unsigned,
	minimum int unsigned,
	max_shoulder int unsigned default null,
	min_shoulder int unsigned default null, 
	updated_at datetime default now()
	);

DROP table if exists jobs; -- работы "в полях"
	create table jobs (
	id serial primary key,
	location_id bigint unsigned, 
	well_no varchar(50),
	nominal_size set ('42"','36"','30"','26"','20"','18 5/8"','16 3/4"','13 5/8"','13 3/8"','12 3/4"','10 3/4"','9 7/8"','9 5/8"','8 5/8"','7 5/8"','7"','6 5/8"','5 7/8"','5 1/2"','5"','4 1/2"','4"','3 1/2"','2 7/8"','2 3/8"'),
	job_type enum ('conductor', 'casing', 'liner', 'tubing', 'DP') DEFAULT 'casing',
	is_RIH_or_POOH enum ('RIH', 'POOH') default 'RIH',
	start_date date,
	end_date date,
	meters_run int unsigned DEFAULT 0,
	CSS int unsigned, 
	foreign key (location_id) references locations (id) on update cascade on delete no action 
	);

DROP table if exists jobs_tubulars; -- на одной работе может быть несколько видов труб и также разные виды трубы могут быть на разных работах 
CREATE table jobs_tubulars (
    id serial primary key,
    job_id bigint unsigned,
    tubular_id bigint unsigned,
	foreign key (job_id) references jobs (id) on update cascade on DELETE cascade,
	foreign key (tubular_id) references tubulars (id) on update cascade on DELETE cascade,
    meterage int unsigned, -- метраж этой трубы на этой работе
    qty int unsigned  -- количество этой трубы (шт) на этой работе
	);

DROP table if exists jobs_hands; -- несколько специалистов участвуют в работе. на каждой работе могут работать разные.  
CREATE table jobs_hands (
    id serial primary key,
    job_id bigint unsigned, -- ID работы
    hands_GIN bigint unsigned, -- табельный сотрудника
    is_supervisor bool, -- в роли руководителя бригады
    shift enum ('days', 'nights', 'fulltime'), -- смена
    foreign key (job_id) references jobs (id) on update cascade on DELETE cascade,
    foreign key (hands_GIN) references hands (GIN) on update cascade on DELETE no action
    );

drop table if exists assets; -- описывает оборудование
create table assets (
	id serial primary key,
	`class` enum ('circulation', 'CRT', 'gripping', 'hoisting', 'make_up', 'other'),
	description text,
	`type` enum ('basket','bowl','casing_swage','center_latch_elevator','computer_system','container','control_console','c-plate','crossover','CRT','drift','dump_valve','SE_guides','hinged_casing_spider','HPU','hydraulic_hoses','spider_slips','lift_cylinder','lifting_nubbin','links','load_cell','manual_slips','manual_tong','manual_tong_jaws','pneumatic_tubing_spider','power_cable','power_tong','pump_in_sub','safety_clamp','safety_nubbing','side_entry_sub','side_door_elevator','single_joint_elevator','slip_type_elevator','spider_elevator','spring_hanger','stabbing_guide','stump_guide','stump_stand','swivel','sling','thread_protector','tong_backup_jaw_die','tong_backup_jaw_set','tong_jaw_set','torque_gauge','other'),
	casing_size_max_inch float unsigned,
	hoist_capacity_LBS float unsigned,
	torque_capacity_ftlbs int,
	pressure_capacity_PSI int,
	flow_rate_GPM int,
	OEM varchar(255), -- производитель
	MFG_date date, -- дата производства
	OEM_sn varchar(255), -- заводской серийный номер
	OEM_pn varchar(255), 
	FMS_sn varchar(255), -- инвентарный номер
	FMS_pn varchar(255),
	CCD VARCHAR(255), 
	location_id bigint unsigned, -- местонахождение
	utilization_unit enum ('meters', 'hours') default 'hours', -- наработка ведется в метрах или часах
	utilization_current bigint unsigned default 0, -- текущая наработка (до очередного капремонта)
	utilization_accumulated bigint unsigned default 0, -- накопленная наработка
	foreign key (location_id) references locations (id) on update cascade
	);
create index OEM_SN on assets(OEM_SN);
create index FNS_SN on assets(FMS_SN);

DROP table if exists jobs_assets; -- оборудование отработавшее на конкретной работе
CREATE table jobs_assets (
	job_id bigint unsigned, -- номер работы
	asset_id bigint unsigned, -- номер единицы оборудования
	utilization bigint unsigned not null default 0, -- наработка этой единицы оборудования на этой работе
	foreign key (job_id) references jobs (id),
	foreign key (asset_id) references assets (id)
	);

Drop table if exists shipments; -- перемещения между локациями
create table shipments (
	id serial primary key,
	origin_id bigint unsigned,
	destination_id bigint unsigned,
	shipment_date datetime default now(),
	foreign key (origin_id) references locations (id),
	foreign key (destination_id) references locations (id)
	);
	
DROP table if exists shipments_assets; -- список перемещаемого при конкретном перемещении
create table shipments_assets (
	shipment_id bigint unsigned,
	asset_id bigint unsigned,
	foreign key (shipment_id) references shipments (id) on update cascade,
	foreign key (asset_id) references assets (id) on update cascade
	);

drop table if exists workorders; -- учет Техобслуживания оборудования. Каждый  WO может включать несколько единиц оборудования
create table workorders (
	id serial primary key,
	fms_wo bigint unsigned, 
	ordered_by varchar(50),
	status enum ('draft', 'open', 'complete'),
	opened_at datetime default now(),
	required_at datetime,
	completed_at datetime
	);

drop table if exists workorders_assets; -- детально по ТО оборудования для каждой конкретной единицы
create table workorders_assets (
	workorder_id bigint unsigned,
	asset_id bigint unsigned,
	work_cat set ('repair', 'MPI', 'VI', 'DIM', 'UTT', 'Cat4', 'Cat3', 'Cat2'),
	work_scope text,
	criteria varchar(255),
	`result` enum ('pass', 'fail'),
	report_no varchar(255),
	report_date datetime,
	file_name varchar(255),
	foreign key (workorder_id) references workorders (id) on update cascade,
	foreign key (asset_id) references assets (id) on update cascade
	);

drop trigger if exists count_utilization_after_job; -- Подсчет (прибавки) наработки оборудования (хранится в assets.utilization_current и assets.utilization_accumulated) при создании записи о работе оборудования в jobs_assets.utilization
delimiter //
create trigger count_utilization_after_job after INSERT on jobs_assets for each row
begin
	UPDATE assets set utilization_current=utilization_current+new.utilization WHERE id=new.asset_id;
	UPDATE assets set utilization_accumulated=utilization_accumulated+new.utilization WHERE id=new.asset_id;
end//
delimiter ;
 
drop trigger if exists count_utilization_after_job_update; -- Коррекция наработки оборудования (хранится в assets.utilization_current и assets.utilization_accumulated) при изменении записи о работе оборудования в jobs_assets.utilization
delimiter //
create trigger count_utilization_after_job_update before UPDATE on jobs_assets for each row
begin
	UPDATE assets set utilization_current=utilization_current-old.utilization+new.utilization WHERE id=new.asset_id;
	UPDATE assets set utilization_accumulated=utilization_accumulated-old.utilization+new.utilization WHERE id=new.asset_id;
end//
delimiter ;

drop trigger if exists change_location; -- Изменение местонахождения оборудования (assests.location_id) при создании записи о перемещении оборудования (shipments_assets)
delimiter //
create trigger change_location after INSERT on shipments_assets for each row
begin
	UPDATE assets set location_id=(SELECT destination_id from shipments s WHERE s.id=new.shipment_id) WHERE id=new.asset_id;
end//
delimiter ;

drop trigger if exists update_location;  -- Изменение местонахождения оборудования (assests.location_id) при изменении записи о перемещении оборудования (shipments)
delimiter //
create trigger update_location before UPDATE on shipments for each row
begin
	UPDATE assets set location_id=new.destination_id WHERE id in (select asset_id from shipments_assets sa where sa.shipment_id=OLD.id);
end//
delimiter ;

-- скрипты заполнения базы данными
INSERT into locations (
	name, 			client_name,	contract, 		is_active, 	is_offshore, 	project_scope) values 
	('North Base',	'n/a',			'n/a',			true,		false,			'Main base and support facility of the company'),
	('Odoptu-More',	'RN-SMNG',		'100018/04013Д',true,		false,			'Provide equipment and personnel and run tubulars: 508mm, 340mm, 245mm, 168mm, 140mm, 89mm, 73mm'),
	('SLB-CPL',		'Schlumberger',	'n/a',			TRUE,		FALSE,			'rental equipment for internal client local SKG Completions segment'),
	('SLB-RUL', 	'Schlumberger', 'n/a',			true,		false,			'owned by other SLB districts on RUL'),
	('Mira56/7',	'WIS',			'n/a',			true,		false,			'owned by WIS'),
	('scrapped',	'n/a',			'n/a',			false,		false,			'item has been written off and needs to be removed from DB'),	
	('Saudi',		'Schlumberger', 'n/a',			true,		false,			'owned by other SLB districts on MEA'),
	('Techinkome',	'Techinkome',	null,			true,		false,			'storage facility within Yuzhno-Sakhalinsk area')
	;

insert into jobs (
	location_id,	well_no,		job_type, 		nominal_size, 	start_date, 	end_date, 	meters_run,		CSS) values
	(2, '275', 'conductor', '20"', '2020-08-29', '2020-08-29', 121, 45),
	(2, '275', 'casing', '13 3/8"', null, null, null, null),
	(2, '275', 'liner', '9 5/8"', null, null, null, null),
	(2, '275', 'liner', '6 5/8"', null, null, null, null)
	;
		
INSERT into hands (
	GIN,		alias,		name,		surname,	grade,		mapping) values
	(04573788, 'SGumerov',	'Shamil', 	'Gumerov', 	'G10', 		'SKG'),
	(06016299, 'HFirst', 	'Hand', 	'First',	'G08',		'SKG'),
	(06005062, 'SSecond', 	'Second', 	'Hand',		'G09',		'SKG'),
	(04463097, 'TThird', 	'Hand', 	'Third',	'G09',		'SKG')
	;

INSERT into tubulars (
	OD,			wall_mm,	ppf,	drift,		grade,		`connection`,						coating,	maximum,	optimum,	minimum,	max_shoulder,	min_shoulder) values
	(508.00,	11.13, 		94,		481.77,		'K55',		'BTC',								'n/a',		null,		null,		null,		null,			null),
	(339.72,	12.19,		68,		311.37,		'N80',		'TMK UP PF',						'GW',		49500,		45000,		40500,		36000,			6750),	
	(244.48,	11.05, 		43.5,	218.41,		'P110',		'TMK UP PF ET',						'GW',		49500,		45000,		40500,		36000,			6750),	
	(168.28,	8.94,		24,		147.22,		'N80',		'TMK UP PF ET',						'GW',		20500,		18600,		16700,		14880,			2790),	
	(73.02,		5.51,		6.4,	59.62,		'K72',		'НКТ 73,02 по ГОСТ Р 53366-2009',	'n/a',		1944,		1555,		1322, 		null,			null),	
	(88.90,		6.45,		9.2,	72.82,		'N80Q',		'НКТ 88,9 по ГОСТ Р 53366-2009',	'n/a',		3513,		2810,		2108,	 	null,			null)
	;	


insert into assets (
	class, description, `type`, casing_size_max_inch, hoist_capacity_LBS, torque_capacity_ftlbs, pressure_capacity_PSI,flow_rate_GPM,OEM,MFG_date,OEM_sn,OEM_pn,FMS_sn,FMS_pn, CCD ,location_id,utilization_unit) VALUES
	('make_up','basket for storage and movement of key KT 2000','basket',null,null,'50000',null,null,null,null,null,null,'56068JA',null,null,'1','hours'),
	('circulation','Sub  X-over  Plain  6 5/8 FH Box x 6 5/8 REG Pin  200 mm OD x 3 ID  24 OAL','crossover',null,null,null,null,null,'BDT','2016-05-04',null,null,'DTR-SKG-0132',null,'Local manufacture','1','hours'),
	('circulation','Sub  crossover  6 5/8 FH BOX x 6 5/8 REG Pin  350mm STSL  P530','crossover',null,null,null,null,null,'BDT','2016-06-21',null,null,'DTR-SKG-0113',null,'Local manufacture','1','hours'),
	('circulation','STEEL crossover  6 5/8 REG PIN x NC61 PIN','crossover',null,null,null,null,null,'BDT','2013-06-05',null,null,'62405J',null,'Local manufacture','1','hours'),
	('circulation','STEEL crossover  XT-57 BOX x 6 5/8 REG PIN','crossover',null,null,null,null,null,'BDT','2012-06-14',null,null,'62463J',null,'Local manufacture','1','hours'),
	('circulation','crossover 6-5/8 REG PIN x UXT-57 BOX 8 OD x 7-3/4 OD x 3-1/4 ID x 36 OVERAL LENGTH','crossover',null,null,null,null,null,'SURBO','2012-10-22','0908712-15',null,'0908712-15.1',null,null,'1','hours'),
	('circulation','Steel CRT crossover SUB  7.50” OD x 3.50” ID  XT-57 BOX x 6 5/8 REG PIN','crossover',null,null,null,null,null,'BDT','2015-11-13',null,null,'DTR-SKG-0061',null,'IN4319851','1','hours'),
	('circulation','Steel CRT crossover SUB  7.50” OD x 3.50” ID  XT-57 BOX x 6 5/8 REG PIN','crossover',null,null,null,null,null,'BDT','2015-11-13',null,null,'DTR-SKG-0062',null,'IN4319851','1','hours'),
	('CRT','CRT service stand','stump_stand',null,null,null,null,null,'BDT','2016-03-29',null,null,'DTR-SKG-0129',null,'Local manufacture','1','hours'),
	('CRT','The CRTI bulkhead board','stump_stand',null,null,null,null,null,'NEFTEPROMSERVICE','2014-06-30',null,null,'96637J',null,'СЧФ 2151-28072014','1','hours'),
	('CRT','The CRTI bulkhead board','stump_stand',null,null,null,null,null,'NEFTEPROMSERVICE','2014-06-30',null,null,'95913J',null,'СЧФ 2151-30072014','1','hours'),
	('circulation','9-5/8 OD X 12 EXTENSION SUB W/ 6-5/8 REG BOX X 6-5/8 REG PIN ','crossover',null,null,null,null,null,'NOV','2015-04-06','USAW1851733-1',null,'11152K','73732/015',null,'1','hours'),
	('circulation','9-5/8 OD X 12 EXTENSION SUB W/ 6-5/8 REG BOX X 6-5/8 REG PIN ','crossover',null,null,null,null,null,'NOV','2014-10-30','USAW1851733-2',null,'11977K','73732/015',null,'1','hours'),
	('circulation','Steel crossover  7 1/2” OD  6 5/8 REG PIN*5 1/2 FH 6 5/8FH BOX','crossover',null,null,null,null,null,'BDT','2011-09-28','4710-AK-1',null,'78262H',null,'KZU BDT manufacture','1','hours'),
	('other','side_entry_sub5-1/2 IF Pin x 5-1/2 IF Box  Complete With 2” 1502Female Threaded Side ConnectioNOVerall length: 610mm','side_entry_sub',null,null,null,null,null,'WELONG','2018-06-19',null,null,'40091K',null,'10707090-260718-0008799','2','hours'),
	('other','side_entry_sub5-1/2 IF Pin x 5-1/2 IF Box  Complete With 2” 1502Female Threaded Side ConnectioNOVerall length: 610mm','side_entry_sub',null,null,null,null,null,'WELONG','2018-06-19',null,null,'40092K',null,'10707090-260718-0008799','2','hours'),
	('other','circulation Sub  5-1/2 IF Pin x 2” 1502 Female Threaded TopConnectioNOVerall length: 550mm','pump_in_sub',null,null,null,null,null,'WELONG','2018-06-19',null,null,'40089K',null,'10707090-260718-0008799','2','hours'),
	('other','circulation Sub  5-1/2 IF Pin x 2” 1502 Female Threaded TopConnectioNOVerall length: 550mm','pump_in_sub',null,null,null,null,null,'WELONG','2018-06-19',null,null,'40090K',null,'10707090-260718-0008799','2','hours'),
	('circulation','crossover SUB 6 5/8 FH BOX X 6 5/8 REG PIN OD 7 7/8','crossover',null,null,null,null,null,'BDT','2011-11-08','80557H',null,'80557HA',null,'Local manufacture','2','hours'),
	('hoisting','B+V TYPE SET OF ELEVATOR links  API8C-PSL1  3 1/2* 240  500 TON','links',null,'500',null,null,null,'B+V','2010-12-23','73601 A/B 13491/13492',null,'59816HA',null,'PO-293140  receipted on 15/11/11 from CISLAB LLC  delivery #3 DD 03022011  customs ref #3','1','hours'),
	('hoisting','ELEVATOR C/L TYPE HYC 200 TON LESS SLIPS & GUIDES PN 55310 complete with HYC 7 x 7 Slips assy 2','center_latch_elevator',null,'200',null,null,null,'BVM','2011-02-23','25287',null,'68319HA',null,'from 4','2','hours'),
	('CRT','CRTI-2-8.63-BASE TOOL INCLUDES SEAL AND HARDWARE KITS.','CRT',null,'599','85000','5000','1161','VOLANT',null,null,null,'19297J',null,null,'2','meters'),
	('CRT','CRTI-2-8.63-BASE TOOL INCLUDES SEAL AND HARDWARE KITS.','CRT',null,'599','85000','5000','1161','VOLANT',null,null,null,'99618J',null,null,'2','meters'),
	('other','6 5/8 FH LIFT CAP','lifting_nubbin',null,null,null,null,null,'THOMAS TOOLS',null,'76370',null,'76370',null,'10707090-020616-0005418','2','hours'),
	('CRT','CRTI-2-8.63-BASE TOOL INCLUDES SEAL AND HARDWARE KITS.','CRT',null, null,'85000','5000','1161','VOLANT','2013-07-15','82307-03-4314A01-03',null,'84323J',null,'10707090-241213-0010934','7','meters'),
	('CRT','CRTI-2-8.63-BASE TOOL INCLUDES SEAL AND HARDWARE KITS.','CRT',null, null,'85000','5000','1161','VOLANT','2013-07-15','82307-03-4314A01-02',null,'84324JA',null,'10707090-241213-0010934','7','meters'),
	('make_up','ASSEMBLY  CYLINDER  LIFT  3.5B  2R  48S LCR-045','lift_cylinder',null,'9000',null,'3000',null,'MCCOY','2018-06-29','1614-7','55-0000028',null,'55-0000028','10702070-200918-0139641','1','hours'),
	('make_up','SM50-44-CASSEMBLY  COMPRESSION load_cell  44 ARM  50K FT-LBS','torque_gauge',null,null,'50000',null,null,'MCCOY','2018-04-16','M30576/77','SM50-44-C',null,'SM50-44-C','10707090-260618-0007407','1','hours'),
	('make_up','KITHOSE-50SET OF 50 FT HOSES 1 & 1-1/4 M-F','hydraulic_hoses',null,null,null,null,null,'MCCOY',null,null,'KITHOSE-50',null,'KITHOSE-50','10702070-200918-0139641','1','hours'),
	('make_up','KITHOSE-50SET OF 50 FT HOSES 1 & 1-1/4 M-F','hydraulic_hoses',null,null,null,null,null,'MCCOY',null,null,'KITHOSE-50',null,'KITHOSE-50','10702070-200918-0139641','1','hours'),
	('make_up','KITHOSE-50SET OF 50 FT HOSES 1 & 1-1/4 M-F','hydraulic_hoses',null,null,null,null,null,'MCCOY',null,null,'KITHOSE-50',null,'KITHOSE-50','10702070-200918-0139641','1','hours'),
	('make_up','MTT-6021-0302-0304-01-00-EXASSEMBLY  WINCATT  PURGED EX ATEX  STANDARD load_cellS  PN - MTT-6021-0302-0304-01','computer_system',null,null,null,null,null,'MCCOY','2018-02-11','A18020025','MTHOMAS TOOLS-6021-0302-0304-01-00-EX','41096K',null,'10707090-100119-0000096','1','hours'),
	('make_up','10-0016C/ ASSEMBLY  COMPRESSION load_cell  36 ARM  40.000 FT-LB','torque_gauge',null,null,null,null,null,'MCCOY','2017-08-06','C104049-1/2','10-0016C','31975K',null,'10707090-290817-0011751','1','hours'),
	('make_up','Spring lifter assembly TQ508/70Y-1221','lift_cylinder',null,'6613',null,'2610',null,'JIANGSU RUTONG',null,null,'TQ508/70-1207',null,null,'10707090-160718-0008279','1','hours'),
	('make_up','Spring lifter assembly TQ508/70Y-1221','lift_cylinder',null,'6613',null,'2610',null,'JIANGSU RUTONG',null,null,'TQ508/70-1207',null,null,'10707090-160718-0008279','1','hours'),
	('make_up','PRESSURE AND torque_gauge MODEL: TQ508/70','torque_gauge',null,null,'50000',null,null,'JIANGSU RUTONG',null,'179011',null,null,null,'10707090-160718-0008279','1','hours'),
	('make_up','PRESSURE AND torque_gauge MODEL: TQ508/70','torque_gauge',null,null,'50000',null,null,'JIANGSU RUTONG',null,'179028',null,null,null,'10707090-160718-0008279','1','hours'),
	('make_up','Torque turn computer_system NKY-C15Ex Type','computer_system',null,null,null,null,null,'JSPM','2018-06-25','DO1806CU',null,'40136K',null,'10707090-130818-0009531','1','hours'),
	('make_up','computer_system','computer_system',null,null,null,null,null,'JSPM','2018-06-25',null,null,'40167K',null,'10707090-130818-0009531','1','hours'),
	('make_up','computer_system','computer_system',null,null,null,null,null,'JSPM','2018-06-25',null,null,'40168K',null,'10707090-130818-0009531','1','hours'),
	('make_up','6ton rated torque sensor for the NKY-C15ex computer_system CGQ134-L6T/4P','load_cell',null,null,null,null,null,'JSPM','2018-06-01','DL1801A1',null,null,null,null,'1','hours'),
	('make_up','6ton rated torque sensor for the NKY-C15ex computer_system CGQ134-L6T/4P','load_cell',null,null,null,null,null,'JSPM','2018-06-01','DL1801AJ',null,null,null,null,'1','hours'),
	('make_up','inline unloading valve with solenoid to release the hydraulic pressure inside the system of YZBF-120 HPU / Casing tong / NKY- C15Ex computer_system','dump_valve',null,null,null,null,null,'JSPM','2018-06-29',null,null,null,null,null,'1','hours'),
	('make_up','inline unloading valve with solenoid to release the hydraulic pressure inside the system of YZBF-120 HPU / Casing tong / NKY- C15Ex computer_system','dump_valve',null,null,null,null,null,'JSPM','2018-06-29',null,null,null,null,null,'1','hours'),
	('make_up','the cable with sockets to connect the NKY-C15Ex computer_system and pressure release valve','dump_valve',null,null,null,null,null,'JSPM','2018-06-29',null,null,null,null,null,'1','hours'),
	('make_up','the cable with sockets to connect the NKY-C15Ex computer_system and pressure release valve','dump_valve',null,null,null,null,null,'JSPM','2018-06-29',null,null,null,null,null,'1','hours'),
	('make_up','the cable with sockets to connect the NKY-C15Ex computer_system and pressure release valve','dump_valve',null,null,null,null,null,'JSPM','2018-06-29',null,null,null,null,null,'1','hours'),
	('make_up','torque_gauge KT14000','torque_gauge',null,null,'50000',null,null,'WELONG','2018-05-20','17.9321',null,null,null,'10702070-031018-0147220','1','hours'),
	('make_up','power_cable 25mm^2 for YZBF HPU 30m','power_cable',null,null,null,null,null,null,null,null,null,null,null,null,'1','hours'),
	('make_up','power_cable 25mm^2 for YZBF HPU 30m','power_cable',null,null,null,null,null,null,null,null,null,null,null,null,'1','hours'),
	('make_up','power_cable 25mm^2 for YZBF HPU 30m','power_cable',null,null,null,null,null,null,null,null,null,null,null,null,'1','hours'),
	('make_up','power_cable 25mm^2 for YZBF HPU 30m','power_cable',null,null,null,null,null,null,null,null,null,null,null,null,'1','hours'),
	('make_up','hinge jaw reference p/n 55707  position #23 on the spec aTHOMAS TOOLSached Q4~17-135kNm','manual_tong_jaws',null,null,'135000',null,null,'JIANGSU RUTONG','2018-08-28',null,null,null,null,'10707090-041018-0011796','1','hours'),
	('make_up','hinge jaw reference p/n 55707  position #23 on the spec aTHOMAS TOOLSached Q4~17-135kNm','manual_tong_jaws',null,null,'135000',null,null,'JIANGSU RUTONG','2018-08-28',null,null,null,null,'10707090-041018-0011796','1','hours'),
	('other','power_cable extension 220v ExProof','power_cable',null,null,null,null,null,'ООО Завод ГОРЭЛТЕХ','2019-09-01','1.91203E+11',null,null,null,null,'1','hours'),
	('hoisting','swivel 5.6t','swivel',null,'5.6',null,null,null,'Qingdao Dacheng Rigging CO. Ltd.','2015-08-06','TRS022007','PW',null,null,null,'1','hours'),
	('make_up','torque_gauge  52  72000','torque_gauge',null,null,'72000',null,null,'MCCOY',null,'14680/14681',null,null,null,null,'1','hours'),
	('hoisting','FCS control_console','control_console',null, null,null,null,null,'DEN-CON',null,null,null,null,null,'from 4','1','hours'),
	('make_up','FTE- Компьютерная система для контроля момента свинчивания и построения графиков процесса свинчивания ExProof','computer_system',null,null,null,null,null,'CISLAB',null,'79639С',null,null,null,null,'1','hours'),
	('make_up','Hydraulic Power Station for TQ365-55Y tong + set of hydraulic_hoses','HPU',null,null,null,'3100','31.7','JSPM','2018-06-05','18113',null,'40142K',null,'10707090-130818-0009531','1','hours'),
	('make_up','HPU','HPU',null,null,null,'3100','31.7','JSPM','2018-06-05','18111',null,'40169K',null,'10707090-130818-0009531','1','hours'),
	('make_up','HPU','HPU',null,null,null,'3100','31.7','JSPM','2018-06-05','18112',null,'40170K',null,'10707090-130818-0009531','1','hours'),
	('make_up','Electric Hydraulic Power Unit YZBF-120LD','HPU',null,null,null,'3100','31.7','JSPM','2019-02-28','190201',null,'43734K',null,'10702070-170518-0086657','1','hours'),
	('make_up','ASSEMBLY  HANGER  SPRING  3001-6000 LBS SH-060','spring_hanger',null,'6000',null,null,null,'MCCOY','2018-08-09','6006673-1','SH-060','40179K',null,'10702070-200918-0139641','2','hours'),
	('make_up','ASSEMBLY  TABLET  WINCATHOMAS TOOLS SYSTEM  ELECTRONIC & TRANSPORT BOX  FOR ONE TABLET WINCATHOMAS TOOLS','computer_system',null,null,null,null,null,'MCCOY','2018-05-23','A18050030',null,'40180K',null,'10702070-200918-0139641','2','hours'),
	('make_up',' PU2500E24-10ASSEMBLY  POWER UNIT  ELECTRIC  WITH COOLER & HEATER','HPU',null,null,null,'2500','23','MCCOY','2018-06-21','U180109','PU2500E24-10','40178K',null,'10702070-200918-0139641','2','hours'),
	('make_up','MTHOMAS TOOLS-6021-0302-0304-01-00-EXASSEMBLY  WINCATHOMAS TOOLS  PURGED EX ATEX  STANDARD load_cellS  PN - MTHOMAS TOOLS-6021-0302-0304-01','computer_system',null,null,null,null,null,'MCCOY','2019-07-05','A18060041','MTHOMAS TOOLS-6021-0302-0304-01-00-EX','44405K',null,'10702070-260619-0117943','2','hours'),
	('make_up','10-0016C/ ASSEMBLY  COMPRESSION load_cell  36 ARM  40.000 FT-LB','torque_gauge',null,null,null,null,null,'MCCOY','2017-08-06','C104049-3/4','10-0016C','31976K',null,'10707090-290817-0011751','2','hours'),
	('make_up','PRESSURE AND torque_gauge MODEL: TQ508/70','torque_gauge',null,null,'50000',null,null,'YLC-6022 JHWL-01 201906C25 / 018-06-293',null,null,null,null,null,null,'2','hours'),
	('make_up','PRESSURE AND torque_gauge MODEL: TQ508/70','torque_gauge',null,null,'50000',null,null,'YLC-6022 JHWL-01 201906C23 / 018-08-225',null,null,null,null,null,null,'2','hours'),
	('make_up','torque_gauge KT14000','torque_gauge',null,null,'50000',null,null,'YLC-6022 JHWL-01 201906003 / 018-06-223',null,null,null,null,null,null,'2','hours'),
	('make_up','Suspension Spring Set','spring_hanger',null,null,null,null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('make_up','lift_cylinder','lift_cylinder',null,null,null,null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('make_up','6T torque sensor for the NKY-C15ex computer_system 6吨 传感器','load_cell',null,null,null,null,null,'JSPM',null,null,null,null,null,null,'2','hours'),
	('make_up','Lift','lift_cylinder',null,null,null,null,null,'WELONG',null,null,null,null,null,'10702070-031018-0147220','2','hours'),
	('make_up','Electric Hydraulic Power Unit  YZBF-120LD','HPU',null,null,null,'3100','31.7','JSPM','2018-06-05','18114',null,'17196',null,'from ASG','2','hours'),
	('make_up','hydraulic_hoses set 1 and 1 1/4 10m','hydraulic_hoses',null,null,null,null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('make_up','hydraulic_hoses set 1 and 1 1/4 10m','hydraulic_hoses',null,null,null,null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('make_up','hydraulic_hoses set 1 and 1 1/4 10m','hydraulic_hoses',null,null,null,null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('make_up','hydraulic_hoses set 1 and 1 1/4 10m','hydraulic_hoses',null,null,null,null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('make_up','hydraulic_hoses set 1 and 1 1/4 10m','hydraulic_hoses',null,null,null,null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('make_up','hydraulic_hoses set 1 and 1 1/4 10m','hydraulic_hoses',null,null,null,null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('make_up','hydraulic_hoses set 1 and 1 1/4 25m','hydraulic_hoses',null,null,null,null,null,'JSPM',null,null,null,null,null,'10702070-170518-0086657','2','hours'),
	('make_up','hydraulic_hoses set 1 and 1 1/4 25m','hydraulic_hoses',null,null,null,null,null,'JSPM',null,null,null,null,null,'10702070-170518-0086657','2','hours'),
	('hoisting','weldless links 216x350t','links',null,'350',null,null,null,'JSPM','2018-06-17','180701',null,'40171K',null,'10707090-130818-0009531','2','hours'),
	('hoisting','swivel KLW 13-8 5.3ton','swivel',null,'5.3',null,null,null,'EVROTREYD',null,null,null,'40665K',null,null,'2','hours'),
	('hoisting','swivel KLW 13-8 5.3ton','swivel',null,'5.3',null,null,null,'EVROTREYD',null,null,null,'40666K',null,null,'2','hours'),
	('other','Safety sling for tong BK-5.72-3500','sling',null,'5.72',null,null,null,'RIGTEK','2018-08-23','2583',null,null,null,null,'2','hours'),
	('other','Safety sling for tong BK-5.72-3000','sling',null,'5.72',null,null,null,'RIGTEK','2018-08-23','2582',null,null,null,null,'2','hours'),
	('other','Safety sling for tong BK-5.72-2500','sling',null,'5.72',null,null,null,'RIGTEK','2018-08-23','2581',null,null,null,null,'2','hours'),
	('other','Safety sling for tong BK-2.96-1500','sling',null,'2.96',null,null,null,'RIGTEK','2018-08-23','248367',null,null,null,null,'2','hours'),
	('other','Safety sling for tong BK-2.96-1500','sling',null,'2.96',null,null,null,'RIGTEK','2018-08-23','248398',null,null,null,null,'2','hours'),
	('other','Safety sling for tong BK-2.96-1200','sling',null,'2.96',null,null,null,'RIGTEK','2018-08-23','248002',null,null,null,null,'2','hours'),
	('other','Safety sling for tong BK-2.96-1200','sling',null,'2.96',null,null,null,'RIGTEK','2018-08-23','248033',null,null,null,null,'2','hours'),
	('other','Safety sling for tong BK-2.96-1200','sling',null,'2.96',null,null,null,'RIGTEK','2018-08-23','248061',null,null,null,null,'2','hours'),
	('hoisting','sling set for SJE 2CK-5.98-1500','sling',null,'5.98',null,null,null,'RIGTEK','2019-08-23','247637',null,null,null,null,'2','hours'),
	('hoisting','sling set for SJE 2CK-5.98-1500','sling',null,'5.98',null,null,null,'RIGTEK','2019-08-23','247668',null,null,null,null,'2','hours'),
	('make_up','85-0106HDS/ ASSEMBLY  HANGER  SPRING ','spring_hanger',null,null,null,null,null,'MCCOY',null,'P02003660-01','85-0106HDS','31971K',null,'10707090-290817-0011751','2','hours'),
	('make_up','85-0106HDS/ ASSEMBLY  HANGER  SPRING ','spring_hanger',null,null,null,null,null,'MCCOY',null,'P02003660-02','85-0106HDS','31972K',null,'10707090-290817-0011751','2','hours'),
	('make_up','CE-85-0008-01/ ASSEMBLY  lift_cylinder  48IN STROKE  14000LBS','lift_cylinder',null,null,null,null,null,'MCCOY',null,'JW114662-5','CE-85-0008-01','31973K',null,'10707090-290817-0011751','2','hours'),
	('make_up','CE-85-0008-01/ ASSEMBLY  lift_cylinder  48IN STROKE  14000LBS','lift_cylinder',null,null,null,null,null,'MCCOY',null,'JW114448-17','CE-85-0008-01','31974K',null,'10707090-290817-0011751','2','hours'),
	('hoisting','weldless links 216x350t','links',null,'350',null,null,null,'JSPM','2018-05-14','180702',null,'40164K',null,'10707090-130818-0009531','4','hours'),
	('make_up','TONG lift_cylinder /CLE 14000-09','lift_cylinder',null,null,null,null,null,'MCCOY',null,'8371',null,null,null,null,'4','hours'),
	('hoisting',' Weldless Elevator links 600 long x 350t rat ','links',null,'350',null,null,null,'WELONG','2018-07-11','WL001/WL002',null,'40093K',null,'10707090-220818-0009969','8','hours'),
	('make_up','Jaws set for TQ356-50Y 13 3/8 340mm ','tong_backup_jaw_set','14.37',null,'50000',null,null,'JSPM',null,null,null,null,'JAWTQ356-50Y1338','10707090-130818-0009531','2','hours'),
	('make_up','Jaws set for TQ356-50Y 14 356mm','tong_backup_jaw_set','14.37',null,'50000',null,null,'JSPM',null,null,null,null,'JAWTQ356-50Y14','10707090-130818-0009531','2','hours'),
	('make_up','Jaws set for TQ356-50Y 11 3/4 298mm','tong_backup_jaw_set','12.75',null,'50000',null,null,'JSPM',null,null,null,null,'JAWTQ356-50Y1134','10707090-130818-0009531','2','hours'),
	('hoisting','Elevator  Center Latch  Type MAA 250 Ton 3-1/2 EU Drill Pipe Square ','center_latch_elevator','3.5','250',null,null,null,'CANAM','2017-03-30','38189-S',null,'28939K',null,'10707090-190517-0005987','1','hours'),
	('hoisting',' DDZ Elevator for 3.1/2  18 degree tapered for drill pipe 250 ton rated, DDZ 3.1/2/250T EU PN 000902003 ','center_latch_elevator','3.5','250',null,null,null,'JIANGSU RUTONG','2017-06-07','70409',null,'31650K',null,'10707090-210717-0009704','1','hours'),
	('hoisting',' DDZ Elevator for 3.1/2  18 degree tapered for drill pipe 250 ton rated, DDZ 3.1/2/250T EU PN 000902003 ','center_latch_elevator','3.5','250',null,null,null,'JIANGSU RUTONG','2017-06-07','61212',null,'31657K',null,'10707090-210717-0009704','1','hours'),
	('circulation','circulation Sub  VX38 Pin x 2” 1502 Female Threaded Top Connection','pump_in_sub','3.5',null,null,null,null,'TIANHE','2017-07-01','0617261-1',null,'32048K',null,null,'1','hours'),
	('circulation','circulation Sub  VX38 Pin x 2” 1502 Female Threaded Top Connection','pump_in_sub','3.5',null,null,null,null,'TIANHE','2017-07-01','0617281-1',null,'35019K',null,null,'1','hours'),
	('circulation','side_entry_sub  VX38 Pin x VX38 Box  Complete With 2” 1502 Female Threaded Side Connection','side_entry_sub','3.5',null,null,null,null,'TIANHE','2017-07-01','0617261-2',null,'32049K',null,null,'1','hours'),
	('circulation','side_entry_sub  VX38 Pin x VX38 Box  Complete With 2” 1502 Female Threaded Side Connection','side_entry_sub','3.5',null,null,null,null,'TIANHE','2017-07-01','0617281-2',null,'35020K',null,null,'1','hours'),
	('make_up','Jaws set for TQ356-50Y 10 3/4 273mm ','tong_backup_jaw_set','10.75',null,'50000',null,null,'JSPM',null,null,null,null,'JAWTQ356-50Y1034','10707090-130818-0009531','2','hours'),
	('make_up','Jaws set for TQ356-50Y 9 5/8 244mm ','tong_backup_jaw_set','10.63',null,'50000',null,null,'JSPM',null,null,null,null,'JAWTQ356-50Y958','10707090-130818-0009531','2','hours'),
	('make_up','Jaws set for TQ356-50Y 7 5/8 194mm ','tong_backup_jaw_set','8.5',null,'50000',null,null,'JSPM',null,null,null,null,'JAWTQ356-50Y758','10707090-130818-0009531','2','hours'),
	('make_up','Jaws set for TQ356-50Y 7 178mm ','tong_backup_jaw_set','7.63',null,'50000',null,null,'JSPM',null,null,null,null,'JAWTQ356-50Y7','10707090-130818-0009531','2','hours'),
	('make_up','Jaws set for TQ356-50Y 6 5/8 168mm ','tong_backup_jaw_set','7.39',null,'50000',null,null,'JSPM',null,null,null,null,'JAWTQ356-50Y658','10707090-130818-0009531','2','hours'),
	('gripping','VARCO 29-3/8 - 30-1/2 MP-XL Clamp  complete','safety_clamp','30.5',null,null,null,null,'NOV','2016-05-17','V33039',null,'19781K','V33039','10707090-180616-0006281','1','hours'),
	('gripping','VARCO 29-3/8 - 30-1/2 MP-XL Clamp  complete','safety_clamp','30.5',null,null,null,null,'NOV','2016-05-17','V33039',null,'19794K','V33039','10707090-180616-0006281','1','hours'),
	('hoisting','ELEVATOR SLX150 30 CASING RATING 150 STON / 136 TONNE BORE- 644 MANUAL OPERATED PSL API 8C PSL1','side_door_elevator','30','150',null,null,null,'NOV','2014-07-22','NL4936038',null,'19779K','52755Y644','10707090-180616-0006281','1','hours'),
	('hoisting','ELEVATOR SLX150 30 CASING RATING 150 STON / 136 TONNE BORE- 644 MANUAL OPERATED PSL API 8C PSL1','side_door_elevator','30','150',null,null,null,'NOV','2013-10-02','NL2448769',null,'19780K','52755Y644','10707090-180616-0006281','1','hours'),
	('gripping','MP type safety_clamp for 30 28 links  MP-XL 29.3/8-30.1/2','safety_clamp','30',null,null,null,null,'JIANGSU RUTONG','2018-04-27','80420',null,'38478K',null,'10707090-160718-0008279','1','hours'),
	('gripping','Casing Slips type UC-3 for 30inch casing 24 segments  UC-3 30','manual_slips','30',null,null,null,null,'JIANGSU RUTONG','2018-05-11','805001',null,'38475K',null,'10707090-160718-0008279','1','hours'),
	('gripping','UCS Casing slip','manual_slips','30',null,null,null,null,'NOV','2016-05-19','10384474-001',null,'27077K','7704-5005','10707090-070616-0005699','1','hours'),
	('gripping','8 5/8 100 API Spider','bowl','8.63','100',null,null,null,'DRECO MIDDLE EAST',null,'2510937-7-1',null,'14687K','507323/005','10707090-180915-0009834',null,'hours'),
	('gripping','JOY 13.3/8/200T Casing Spider','hinged_casing_spider','13.38','200',null,null,null,'JIANGSU RUTONG','2018-05-17','51201',null,'38469K',null,'10707090-160718-0008279','1','hours'),
	('make_up','21” jaws for TQ508/70 backup tong','tong_backup_jaw_set','21',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,'10707090-290518-0006216','1','hours'),
	('make_up','20” jaws for TQ508/70 backup tong','tong_backup_jaw_set','20',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,'10707090-160718-0008279','1','hours'),
	('make_up','20” jaws for TQ508/70 backup tong','tong_backup_jaw_set','20',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,'10707090-160718-0008279','1','hours'),
	('make_up','20 jaws for TQ508/70 master tong','tong_jaw_set','20',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,'10707090-160718-0008279','1','hours'),
	('make_up','20 jaws for TQ508/70 master tong','tong_jaw_set','20',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,'10707090-160718-0008279','1','hours'),
	('make_up','FARR TONG MODEL KT20000STAFFA 080 MOTOR  LIFT VALVE ASSEMBLY TORQUE-CAPACITY: 50000 FT/LB','power_tong','20',null,'50000',null,null,'MCCOY','2011-07-01','20115018',null,'87680HA',null,'10005023-231111-0059487','1','hours'),
	('circulation','Переводник. Муфта З-152 / Ниппель TMK UP MAGNA GW 508 x 11.13mm. L-350mm. Гр.пр. L-80','casing_swage','20','959','30622',null,null,'UniTec','2018-07-13','986.1',null,null,null,'SRUO02892A','1','hours'),
	('gripping','8 5/8 100 API Spider','bowl','8.63','100',null,null,null,'JSPM','2018-06-19','Y171203',null,'40143K',null,'10707090-130818-0009531','1','hours'),
	('make_up','Casing Tong 20 and accessories. TQ508/70 Casing power_tong  size range 7~20  High Gear Torque 7500ft-lbs  Low Gear Torque 50000ft-lbs  with Backup Tong  c/w Jaw sets 13.3/8 and 20.','power_tong','20',null,'50000','2610','35','JIANGSU RUTONG','2018-05-01','18011',null,'38434K',null,'10707090-160718-0008279','2','hours'),
	('make_up','Casing Tong 20 and accessories. TQ508/70 Casing power_tong  size range 7~20  High Gear Torque 7500ft-lbs  Low Gear Torque 50000ft-lbs  with Backup Tong  c/w Jaw sets 13.3/8 and 20.','power_tong','20',null,'50000','2610','35','JIANGSU RUTONG','2018-05-01','18012',null,'38435K',null,'10707090-160718-0008279','2','hours'),
	('make_up','JAW ASSEMBLY LEFT / RiGHT 20','tong_jaw_set','20',null,'50000',null,null,'MCCOY',null,null,null,null,'80015240','10005023-231111-0059487','2','hours'),
	('gripping','13.3/8×9.5/8 Bushing for JOY 13.3/8/200T','hinged_casing_spider','10.75','200',null,null,null,'JIANGSU RUTONG','2018-05-21','80529',null,'38471K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','SLX elevator SLX /150 20','side_door_elevator','20','150',null,null,null,'JIANGSU RUTONG','2018-05-16','80506',null,'38467K',null,'10707090-160718-0008279','2','hours'),
	('hoisting','SLX elevator SLX /150 20','side_door_elevator','20','150',null,null,null,'JIANGSU RUTONG','2018-05-16','80507',null,'38468K',null,'10707090-160718-0008279','2','hours'),
	('hoisting','SJ Auxiliary elevator 20  SJ 20','single_joint_elevator','20','5',null,null,null,'JIANGSU RUTONG','2017-05-17','707123',null,'38481K',null,'10707090-160718-0008279','2','hours'),
	('hoisting','SJ Auxiliary elevator 20  SJ 20','single_joint_elevator','20','5',null,null,null,'JIANGSU RUTONG','2017-05-17','707125',null,'38482K',null,'10707090-160718-0008279','2','hours'),
	('gripping','Casing Slips type UC-3 for 20inch casing 17 segments  UC-3 20','manual_slips','20',null,null,null,null,'JIANGSU RUTONG','2018-05-11','805002',null,'38476K',null,'10707090-160718-0008279','2','hours'),
	('gripping','Casing Slips type UC-3 for 20inch casing 17 segments  UC-3 20','manual_slips','20',null,null,null,null,'JIANGSU RUTONG','2018-05-11','805003',null,'38477K',null,'10707090-160718-0008279','2','hours'),
	('gripping','MP type safety_clamp for 20 19 links  MP-XL 19.3/8-20.3/8','safety_clamp','20',null,null,null,null,'JIANGSU RUTONG','2018-04-27','80422',null,'38479K',null,'10707090-160718-0008279','2','hours'),
	('gripping','MP type safety_clamp for 20 19 links  MP-XL 19.3/8-20.3/8','safety_clamp','20',null,null,null,null,'JIANGSU RUTONG','2018-04-27','80423',null,'38480K',null,'10707090-160718-0008279','2','hours'),
	('other','API drift for 20 #94ppf casing','drift','20',null,null,null,null,null,null,'TRS031901',null,null,null,null,'2','meters'),
	('other','API drift for 20 #94ppf casing','drift','20',null,null,null,null,null,null,null,null,null,null,null,'2','meters'),
	('other','API drift for 20 #94ppf casing','drift','20',null,null,null,null,null,null,null,null,null,null,null,'2','meters'),
	('make_up','JAW ASSEMBLY LEFT / RiGHT 18 5/8','tong_jaw_set','18.63',null,'50000',null,null,'MCCOY',null,null,null,null,'80015239','10005023-231111-0059487','2','hours'),
	('make_up','Type SDD Tong Complete for sizes 4 to17 C/ W Lever less Hinge\n & Lug Jaws 100.000/ft/lbs torque','manual_tong','17',null,'100000',null,null,'BVM','2017-03-30','37607-1A',null,'28941K',null,'10707090-190517-0005987','1','hours'),
	('make_up','Type SDD Tong Complete for sizes 4 to17 C/ W Lever less Hinge\n & Lug Jaws 100.000/ft/lbs torque','manual_tong','17',null,'100000',null,null,'BVM','2017-03-30','37607-1B',null,'28942K',null,'10707090-190517-0005987','1','hours'),
	('make_up','SDD manual_tongs Lug jaw #5  SDD Tong 5# Lug Jaw 16~17','manual_tong_jaws','17',null,'135000',null,null,'JIANGSU RUTONG','2018-05-21','5C08',null,null,'10409011','10707090-160718-0008279','1','hours'),
	('make_up','SDD manual_tongs Lug jaw #5  SDD Tong 5# Lug Jaw 16~17','manual_tong_jaws','17',null,'135000',null,null,'JIANGSU RUTONG','2018-05-21','5814',null,null,'10409011','10707090-160718-0008279','1','hours'),
	('make_up','LUG JAW 8- 17 FOR  BV 65 TONG','manual_tong_jaws','17',null,'65000',null,null,'B+V',null,'80965',null,null,null,null,'1','hours'),
	('make_up','LUG JAW 16 - 17 FOR  BV 65 TONG','manual_tong_jaws','17',null,'65000',null,null,'B+V',null,'80888',null,null,'80011494',null,'1','hours'),
	('make_up','manual_tong TYPE BV 65 3 1/2 - 21 1/2 /16 3/4/','manual_tong','17',null,'65000',null,null,'B+V',null,null,null,'59810H',null,null,'2','hours'),
	('make_up','JAW ASSEMBLY LEFT / RiGHT 16 3/4','tong_jaw_set','16.75',null,'50000',null,null,'MCCOY',null,null,null,null,'80021087','10005023-250712-0036860','2','hours'),
	('make_up','SDD manual_tongs Lug jaw #4  SDD Tong 4# Lug Jaw 15.3/4','manual_tong_jaws','15.75',null,'135000',null,null,'JIANGSU RUTONG','2018-05-21','5C37',null,null,'10409010','10707090-160718-0008279','1','hours'),
	('make_up','SDD manual_tongs Lug jaw #4  SDD Tong 4# Lug Jaw 15.3/4','manual_tong_jaws','15.75',null,'135000',null,null,'JIANGSU RUTONG','2018-05-21','5C38',null,null,'10409010','10707090-160718-0008279','1','hours'),
	('make_up','SDD manual_tongs Lug jaw #3  SDD Tong 3# Lug Jaw 12~15','manual_tong_jaws','15',null,'135000',null,null,'JIANGSU RUTONG','2018-05-17','4924',null,null,'10409009','10707090-160718-0008279','1','hours'),
	('make_up','SDD manual_tongs Lug jaw #3  SDD Tong 3# Lug Jaw 12~15','manual_tong_jaws','15',null,'135000',null,null,'JIANGSU RUTONG','2018-05-17','2234',null,null,'10409009','10707090-160718-0008279','1','hours'),
	('make_up','ASSEMBLY  DOVETAIL ADAPTER  15 X 14 3/8','tong_backup_jaw_set','14.38',null,null,null,null,'MCCOY',null,null,'BUDT15-14375A',null,'BUDT15-14375A','10702070-200918-0139641','1','hours'),
	('make_up',' 14 3/8 D.T. JAW SET ASSY. 50K FT./LB. LIMIT, SOLID JAWS SET CONSIST OF TWO 2 JAWS ','tong_jaw_set','14.38',null,null,null,null,'MCCOY',null,null,'CJDT14H14375',null,'CJDT14H14375','10702070-200918-0139641','1','hours'),
	('make_up','14 3/8 jaws for TQ508/70 master tong','tong_jaw_set','14.38',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,null,'1','hours'),
	('make_up','14 3/8 jaws for TQ508/70 master tong','tong_jaw_set','14.38',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,null,'1','hours'),
	('make_up','14 3/8 jaws for TQ508/70 backup tong','tong_backup_jaw_set','14.38',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,null,'1','hours'),
	('make_up','14 3/8 jaws for TQ508/70 backup tong','tong_backup_jaw_set','14.38',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,null,'1','hours'),
	('make_up','LUG JAW 11 3/4 - 14 3/8 FOR  BV 65 TONG','manual_tong_jaws','14.38',null,'65000',null,null,'B+V',null,'78311',null,null,'80011493',null,'1','hours'),
	('make_up','ASSEMBLY  JAW  DT  14 X 14 3/8','tong_jaw_set','14.38',null,'50000',null,null,'MCCOY',null,'CJDT14H14375',null,null,null,'10703070-070819-0023862','2','hours'),
	('make_up','ASSEMBLY  DOVETAIL ADAPTER  15 X 14 3/8 set of 3','tong_backup_jaw_set','14.38',null,'50000',null,null,'MCCOY',null,'BUDT15-14375',null,null,null,'10703070-070819-0023862','2','hours'),
	('make_up','CLE 14000-50 Casing tong','power_tong','14',null,'50000','2500','35','MCCOY','2017-08-28','C170050',null,'38433K',null,'10707090-260618-0007407','1','hours'),
	('make_up','TQ356-50Y/TB365-50Y Hydraulic power_tong with backup  with Hanger Spring  Tong lift_cylinder and torque_gauge ','power_tong','14',null,'50000','2610',null,'JSPM','2018-06-29','18122',null,'40141K',null,'10707090-130818-0009531','1','hours'),
	('make_up','Jaws for casing tong 14  set ','tong_jaw_set','14',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS14','10702070-031018-0147220','1','hours'),
	('make_up','Jaws for backup tong 14 3/8   set','tong_backup_jaw_set','14',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS1438B','10702070-031018-0147220','1','hours'),
	('hoisting','SE500 14 spider  SE 4.1/2~14/500T Spider Body  less slips','spider_elevator','14','500',null,null,null,'JIANGSU RUTONG','2018-05-17','80501',null,'38485K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','SE500 14 elevator  SE 4.1/2~14/500T Elevator Body  less slips','spider_elevator','14','500',null,null,null,'JIANGSU RUTONG','2018-05-17','80502',null,'38484K',null,'10707090-160718-0008279','1','hours'),
	('gripping','c-plate for SE500 spider  SE 4.1/2~14/500T c-plate','c-plate','14','500',null,null,null,'JIANGSU RUTONG','2018-05-17','70102',null,'38498K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','14 slips + boTHOMAS TOOLSom guides for SE500 elevator  SE 4.1/2~14/500T 14 slip assy + bottom guides','spider_elevator','14','500',null,null,null,'JIANGSU RUTONG','2018-05-17','80305',null,'38487K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','14 slips + top guides for SE500 spider  SE 4.1/2~14/500T 14 slip assy + top guides','spider_elevator','14','500',null,null,null,'JIANGSU RUTONG','2018-05-17','80304',null,'38489K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','14 slips + boTHOMAS TOOLSom guides for SE500 elevator  SE 4.1/2~14/500T 14 slip assy + boTHOMAS TOOLSom guides','spider_elevator','14','500',null,null,null,'JIANGSU RUTONG','2018-05-17','80309',null,'38486K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','14 slips + top guides for SE500 spider  SE 4.1/2~14/500T 14 slip assy + top guides','spider_elevator','14','500',null,null,null,'JIANGSU RUTONG','2018-05-17','80310',null,'38488K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','FLUSH MOUNTED SPIDER COMPLETED WITH FCS1400 BODY ASSY AIR','spider_elevator','14','500',null,null,null,'DEN-CON',null,'31500 / 25262',null,'67686H',null,'from 4','1','hours'),
	('hoisting','SLIP ASSY 14x13 3/8 FOR DEN-CON  FLUSH CASING SPIDER 1400','spider_elevator','14','500',null,null,null,'DEN-CON',null,'70734-5',null,null,null,'from 4','1','hours'),
	('make_up','14 Jaw assembly 58.686.00','tong_jaw_set','14',null,'50000',null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('make_up','Casing tong 14 with Hydraulic lift_cylinder  spring_hanger  torque_gauge. max MU torque 50000ft lb ','power_tong','14',null,'50000','2500','40','WELONG','2018-07-01','18025',null,'40063K',null,'10702070-031018-0147220','2','hours'),
	('make_up','CLE 14000-50 Casing tong','power_tong','14',null,'50000','2500','35','MCCOY','2019-02-05','U190064',null,'U190064',null,'10702070-120719-0132167','2','hours'),
	('make_up','14Clincher Casing Tong with Backup  lift_cylinder  torque_gauge Assembly','power_tong','14',null,null,null,null,'MCCOY',null,'8369',null,'79348HA  ',null,null,'4','hours'),
	('other','stump_guide-13.63','stump_guide','13.63',null,null,null,null,'VOLANT',null,'82901-4432A23-1',null,'AH71056',null,null,null,'hours'),
	('other','stump_guide-13.63','stump_guide','13.63',null,null,null,null,'VOLANT',null,'82901-4432A23-2',null,'AH71057',null,null,null,'hours'),
	('other','safety_nubbing 13.63-88.2lb-VAMTOP','safety_nubbing','13.63',null,null,null,null,'VOLANT',null,'82900-4380A11-01','82900',null,null,null,null,'hours'),
	('other','safety_nubbing 13.63-88.2lb-VAMTOP','safety_nubbing','13.63',null,null,null,null,'VOLANT',null,'82900-4361A07-02','82900',null,null,null,null,'hours'),
	('other','safety_nubbing 13.63-88.2lb-VAMTOP','safety_nubbing','13.63',null,null,null,null,'VOLANT',null,'82900-4380A11-02','82900','33369K',null,null,'1','hours'),
	('other','safety_nubbing 13.63-88.2lb-VAMTOP','safety_nubbing','13.63',null,null,null,null,'VOLANT',null,'82900-4380A11-03','82900','27523K',null,null,'1','hours'),
	('other','safety_nubbing 13.63-88.2lb-VAMTOP','safety_nubbing','13.63',null,null,null,null,'VOLANT',null,'82900-4361A07-01','82900','33370K',null,null,'1','hours'),
	('make_up','13-5/8 DOVETAIL JAW SET FOR 14 TONG #CJDT14H13625','tong_jaw_set','13.63',null,null,null,null,'MCCOY',null,null,'CJDT14H13625',null,'80017259',null,'2','hours'),
	('gripping','safety_clamp TYPE C 12-1/2 - 13-5/8 16 SEGMENT','safety_clamp','13.63',null,null,null,null,'TIOT','2013-02-13','TI30332',null,'61806JA',null,'10216020-300413-0009673','2','hours'),
	('make_up','JAW ASSEMBLY 15x13 5/8','tong_backup_jaw_set','13.63',null,null,null,null,'MCCOY',null,null,'BUDT1513625A',null,'80017266',null,'4','hours'),
	('other','safety_nubbing/OD 14.43/ ID 12.260/ PIN 13-5/8 VAM TOP 88.2 ppf','safety_nubbing','13.63',null,null,null,null,'SLB KZ','27.11.2015','7075-AK5',null,'14829K',null,'ГТД 50711-250414-0002357','1','hours'),
	('make_up','ASSEMBLY  DOVETAIL ADAPTER  15 X 13 3/8','tong_backup_jaw_set','13.38',null,null,null,null,'MCCOY',null,null,'BUDT15-13375',null,'BUDT15-13375','10707090-260618-0007407','1','hours'),
	('make_up','ASSEMBLY  JAW  DT  14 X 13 3/8','tong_jaw_set','13.38',null,null,null,null,'MCCOY',null,null,'CJDT14H13375',null,'CJDT14H13375','10707090-260618-0007407','1','hours'),
	('make_up','13 3/8” jaws for TQ508/70 backup tong','tong_backup_jaw_set','13.38',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,'10707090-160718-0008279','1','hours'),
	('make_up','13 3/8” jaws for TQ508/70 backup tong','tong_backup_jaw_set','13.38',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,'10707090-160718-0008279','1','hours'),
	('make_up','13 3/8 jaws for TQ508/70 master tong','tong_jaw_set','13.38',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,'10707090-160718-0008279','1','hours'),
	('make_up','13 3/8 jaws for TQ508/70 master tong','tong_jaw_set','13.38',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,'10707090-160718-0008279','1','hours'),
	('make_up','Jaw set of master tong 13 3/8','tong_jaw_set','13.38',null,'50000',null,null,'WELONG',null,null,null,null,null,'10702070-031018-0147220','1','hours'),
	('make_up','Jaw set of backup tong 13 3/8','tong_backup_jaw_set','13.38',null,'50000',null,null,'WELONG',null,null,null,null,null,'10702070-031018-0147220','1','hours'),
	('make_up','Jaws for casing tong 13 3/8  set ','tong_jaw_set','13.38',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS1338','10702070-031018-0147220','1','hours'),
	('make_up','Jaws for backup tong 13 3/8   set ','tong_backup_jaw_set','13.38',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS1338B','10702070-031018-0147220','1','hours'),
	('make_up','13 3/8 Jaw assembly 58.630.00','tong_jaw_set','13.38',null,'50000',null,null,'JSPM','2019-04-25','190404',null,null,null,null,'1','hours'),
	('gripping','13.3/8×9.5/8 Bushing for JOY 13.3/8/200T','hinged_casing_spider','10.75','200',null,null,null,'JIANGSU RUTONG','2018-05-21','80530',null,'38472K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','SJ Auxiliary elevator 13 3/8','single_joint_elevator','13.38','5',null,null,null,'JSPM','2018-06-28','180630',null,'40139K',null,'10707090-130818-0009531','1','hours'),
	('hoisting','side_door_elevator SX 13.3/8/500T  PN001018007','side_door_elevator','13.38','500',null,null,null,'JIANGSU RUTONG','2017-06-06','60121',null,'31665K',null,'10707090-210717-0009704','1','hours'),
	('hoisting','side_door_elevator SLX 13.3/8/350T','side_door_elevator','13.38','500',null,null,null,'JIANGSU RUTONG','2017-06-06','50306',null,'29741K',null,'10707090-220617-0008102','1','hours'),
	('hoisting','SJ 13.3/8 single_joint_elevator','single_joint_elevator','13.38','5',null,null,null,'JIANGSU RUTONG','2017-06-06','61286',null,'29743K',null,'10707090-220617-0008102','1','hours'),
	('hoisting','TOP GUIDE 13 3/8','SE_guides','13.38','500',null,null,null,'DEN-CON',null,'18419-10',null,null,null,'from 4','1','hours'),
	('gripping','Casing slip type CMS for 13.3/8 casing  CMS-XL 13.3/8  PN000202008','manual_slips','13.38',null,null,null,null,'JIANGSU RUTONG','2017-06-06','70606',null,'31662K',null,'10707090-210717-0009704','1','hours'),
	('circulation','13 3/8” Water Bushing  5 ½” FH Box X 61# TSH MS Pin','casing_swage','13.38','856','14510','6190',null,'IRI','2017-06-23','170620',null,'29747K',null,'10707090-250717-0009880','1','hours'),
	('other','stump_guide 13.38','stump_guide','13.38',null,null,null,null,'VOLANT',null,'82901-4361A03-01','82901','33374K',null,null,'1','hours'),
	('other','API drift 13-3/8 61#','drift','13.38',null,null,null,null,'SCTSS','2017-05-01','1717',null,'29333K',null,null,'1','meters'),
	('other','stump_guide 13.38','stump_guide','13.38',null,null,null,null,'VOLANT',null,null,'82901','33373K',null,null,'1','hours'),
	('make_up','JAW ASSEMBLY LEFT / RiGHT 13 3/8','tong_jaw_set','13.38',null,'50000',null,null,'MCCOY',null,null,null,null,'80015238','10005023-231111-0059487','2','hours'),
	('make_up','13 3/8 Jaw assembly 58.640.00','tong_jaw_set','13.38',null,'50000',null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('gripping',' TS Tubing Spider TS 5.1/2-100 with slips 5.1/2×5 PN00051701 ','bowl','5.5','100',null,null,null,'JIANGSU RUTONG','2017-06-07','70506-70407',null,'29755K',null,'10707090-210717-0009704','1','hours'),
	('hoisting','FTE-13-3/8 single_joint_elevator W/slingS 5 TON','single_joint_elevator','13.38','5',null,null,null,'JIANGSU RUTONG','2017-06-07','509197',null,'SJ509197',null,'RC1137312 from Usinsk','2','hours'),
	('hoisting','SJ Auxiliary elevator 13 3/8','single_joint_elevator','13.38','5',null,null,null,'JSPM','2018-06-28','180629',null,'40138K',null,'10707090-130818-0009531','2','hours'),
	('hoisting','SLX elevator SLX/350 13 3/8','side_door_elevator','13.38','350',null,null,null,'JSPM','2018-06-19','180505',null,'40140K',null,'10707090-130818-0009531','2','hours'),
	('hoisting','FTE-Elevator  S/D Type SLX 250 Ton for size 13-3/8 Casing 339.7mm','side_door_elevator','13.38','250',null,null,null,'JIANGSU RUTONG','2017-06-07','51020',null,'S/D51020',null,'from 4','2','hours'),
	('gripping','Casing Slips for 13 3/8” Casing Type UC-3  12 segments complete with inserts','manual_slips','13.38',null,null,null,null,'BVM','2013-11-09','32861-1 2',null,'79344JA','7704-5025','10216020-091013-0023609','2','hours'),
	('gripping','Casing Slips type UC-3 for 13 3/8inch casing 12 segments','manual_slips','13.38',null,null,null,null,'JSPM','2018-06-19','180501',null,'40137K',null,'10707090-130818-0009531','2','hours'),
	('make_up','ASSEMBLY  JAW  DT  14 X 13 3/8','tong_jaw_set','13.38',null,'50000',null,null,'MCCOY',null,'CJDT14H13375',null,null,null,'10703070-070819-0023862','2','hours'),
	('gripping','WA-C Type Safty clamp for 13 3/8 16 links  WA-C 12.1/2-13.5/8 16 links','safety_clamp','13.38',null,null,null,null,'JIANGSU RUTONG','2018-04-20','80492',null,'38505K',null,'10707090-160718-0008279','2','hours'),
	('gripping','WA-C Type Safty clamp for 13 3/8 16 links  WA-C 12.1/2-13.5/8 16 links','safety_clamp','13.38',null,null,null,null,'JIANGSU RUTONG','2018-04-20','80493',null,'38506K',null,'10707090-160718-0008279','2','hours'),
	('make_up','13-3/8 DOVETAIL JAW  SET FOR 14 TONG #CJDT14H13375','tong_jaw_set','13.38',null,null,null,null,'MCCOY',null,null,'CJDT14H13375',null,'80017260',null,'2','hours'),
	('other','stabbing_guide 13 3/8','stabbing_guide','13.38',null,null,null,null,'JIANGSU RUTONG','2018-05-10',null,null,'38507K',null,'10707090-160718-0008279','2','hours'),
	('other','Casing protector model 13 3/8','thread_protector','13.38',null,null,null,null,'JSPM','2018-06-17','180507',null,null,'CP1338','10707090-130818-0009531','2','hours'),
	('other','Casing protector model 13 3/8','thread_protector','13.38',null,null,null,null,'JSPM','2018-06-17','180508',null,null,'CP1338','10707090-130818-0009531','2','hours'),
	('other','Casing protector model 13 3/8','thread_protector','13.38',null,null,null,null,'JSPM','2018-06-17','180509',null,null,'CP1338','10707090-130818-0009531','2','hours'),
	('other','12.259 OD TEFLON / NYLON drift  12  C/W EYE BOLTS ON BOTH ENDS *FOR 13-3/8 68#','drift','13.38',null,null,null,null,'HUNTING','2018-06-05',null,'Dfift-12.259',null,'12.259','10707090-260618-0007393','2','meters'),
	('other','12.259 OD TEFLON / NYLON drift  12  C/W EYE BOLTS ON BOTH ENDS *FOR 13-3/8 68#','drift','13.38',null,null,null,null,'HUNTING','2018-06-06',null,'Dfift-12.259',null,'12.259','10707090-260618-0007393','2','meters'),
	('other','12.358 OD TEFLON / NYLON drift  12  C/W EYE BOLTS ON BOTH ENDS *FOR 13-3/8 61#','drift','13.38',null,null,null,null,'HUNTING','2018-06-07',null,'Dfift-12.358',null,'12.358','10707090-260618-0007393','2','meters'),
	('make_up','ASSEMBLY  DOVETAIL ADAPTER  15 X 13 3/8 set of 3','tong_backup_jaw_set','13.38',null,'50000',null,null,'MCCOY',null,'BUDT15-13375',null,null,null,'10703070-070819-0023862','2','hours'),
	('make_up','JAW ASSEMBLY 15x13 3/8','tong_backup_jaw_set','13.38',null,null,null,null,'MCCOY',null,null,'BUDT1513375A ',null,'80017267',null,'4','hours'),
	('other','stump_guide 13.38','stump_guide','13.38',null,null,null,null,'VOLANT',null,'82901-4380A12-01','82901','84329J',null,null,'7','hours'),
	('other','stump_guide 13.38','stump_guide','13.38',null,null,null,null,'VOLANT',null,'82901-4380A12-02','82901','84326J',null,null,'7','hours'),
	('other','stump_guide 13.38','stump_guide','13.38',null,null,null,null,'VOLANT',null,'82901-4361A08-01','82901','84330J',null,null,'7','hours'),
	('make_up','12-3/4 Jaw Die Kit for KT20000','tong_jaw_set','12.75',null,'50000',null,null,'MCCOY',null,null,null,'69443JA',null,null,'1','hours'),
	('make_up','JAW SET ASSEMBLY 14x12 3/4','tong_jaw_set','12.75',null,null,null,null,'MCCOY',null,null,'CJDT14H12750',null,'80018551',null,'2','hours'),
	('make_up','JAW ASSEMBLY 15x12 3/4','tong_backup_jaw_set','12.75',null,null,null,null,'MCCOY',null,null,'BUDT1512750A',null,'80018553',null,'4','hours'),
	('make_up','Lug Jaw  For Item # 4 Type SDD Tong LJ8.5to12','manual_tong_jaws','12',null,'100000',null,null,'BVM','2017-03-30','36805-3',null,null,'LJ8.5TO12','10707090-190517-0005987','1','hours'),
	('make_up','Lug Jaw  For Item # 4 Type SDD Tong LJ8.5to12','manual_tong_jaws','12',null,'100000',null,null,'BVM','2017-03-30','36805-12',null,null,'LJ8.5TO12','10707090-190517-0005987','1','hours'),
	('make_up','ASSEMBLY  DOVETAIL ADAPTER  15 X 11 3/4','tong_backup_jaw_set','11.75',null,null,null,null,'MCCOY',null,null,'BUDT15-11750',null,'BUDT15-11750','10707090-260618-0007407','1','hours'),
	('make_up','ASSEMBLY  JAW  DT  14 X 11 3/4','tong_jaw_set','11.75',null,null,null,null,'MCCOY',null,null,'CJDT14H11750',null,'CJDT14H11750','10702070-200918-0139641','1','hours'),
	('make_up','DIE  LOCKJAW  FINE TOOTH  15.000 IN X 11.750 IN 5 OD / BUC150011750','tong_backup_jaw_die','11.75',null,'50000',null,null,'MCCOY',null,null,'BUC150011750','33375K',null,'10707090-240717-0009837','1','hours'),
	('make_up','DIE  LOCKJAW  FINE TOOTH  15.000 IN X 11.750 IN 5 OD / BUC150011750','tong_backup_jaw_die','11.75',null,'50000',null,null,'MCCOY',null,null,'BUC150011750','33376K',null,'10707090-240717-0009837','1','hours'),
	('make_up','DIE  LOCKJAW  FINE TOOTH  15.000 IN X 11.750 IN 5 OD / BUC150011750','tong_backup_jaw_die','11.75',null,'50000',null,null,'MCCOY',null,null,'BUC150011750','33377K',null,'10707090-240717-0009837','1','hours'),
	('make_up','11 3/4 Jaw assembly 58.684.00','tong_jaw_set','11.75',null,'50000',null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('make_up','JAW SET ASSEMBLY 14x11 3/4','tong_jaw_set','11.75',null,null,null,null,'MCCOY',null,null,'CJDT14H11750',null,'80017261',null,'2','hours'),
	('make_up','JAW ASSEMBLY 15x11 3/4','tong_backup_jaw_set','11.75',null,null,null,null,'MCCOY',null,null,'BUDT1511750A',null,'80017268',null,'4','hours'),
	('make_up','LUG JAW 8- 11 1/4 FOR  BV 65 TONG','manual_tong_jaws','11.25',null,'65000',null,null,'B+V',null,'78703',null,null,'80011492',null,'1','hours'),
	('make_up','ASSEMBLY  DOVETAIL ADAPTER  15 X 10 3/4','tong_backup_jaw_set','10.75',null,null,null,null,'MCCOY',null,null,'BUDT15-10750',null,'BUDT15-10750','10707090-260618-0007407','1','hours'),
	('make_up','10 3/4 D.T. JAW SET ASSY. 50K FT./LB. LIMIT SET CONSIST OF TWO 2 JAWS','tong_jaw_set','10.75',null,null,null,null,'MCCOY',null,null,'CJDT14H1075014',null,'CJDT14H1075014','10707090-260618-0007407','1','hours'),
	('make_up','Jaws for casing tong 10 3/4  set','tong_jaw_set','10.75',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS1034','10702070-031018-0147220','1','hours'),
	('make_up','Jaws for backup tong 9 5/8   set ','tong_backup_jaw_set','10.75',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS1034B','10702070-031018-0147220','1','hours'),
	('gripping','13.3/8×7.5/8 Bushing for JOY 13.3/8/200T','hinged_casing_spider','8.63','200',null,null,null,'JIANGSU RUTONG','2018-05-21','60908',null,'38473K',null,'10707090-160718-0008279','1','hours'),
	('gripping','13.3/8×7.5/8 Bushing for JOY 13.3/8/200T','hinged_casing_spider','8.63','200',null,null,null,'JIANGSU RUTONG','2018-05-21','80534',null,'38474K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','BJ TYPE SJL ELEVATOR FOR 10-3/4CASING ','single_joint_elevator','10.75','5',null,null,null,'NOV','2012-08-01','NL0142210',null,'28929K','70502Y142','10707090-050517-0005232','1','hours'),
	('hoisting','BJ TYPE SJL ELEVATOR FOR 10-3/4CASING','single_joint_elevator','10.75','5',null,null,null,'NOV','2014-04-03','NL2618254',null,'28928K','70502Y142','10707090-050517-0005232','1','hours'),
	('make_up','10 3/4 jaws for TQ508/70 master tong','tong_jaw_set','10.75',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,null,'1','hours'),
	('make_up','10 3/4 jaws for TQ508/70 master tong','tong_jaw_set','10.75',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,null,'1','hours'),
	('make_up','10 3/4 jaws for TQ508/70 backup tong','tong_backup_jaw_set','10.75',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,null,'1','hours'),
	('make_up','10 3/4 jaws for TQ508/70 backup tong','tong_backup_jaw_set','10.75',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,null,'1','hours'),
	('circulation','10 3/4” Water Bushing  XT57 box X 51# JFE FOX pin 2 3/8”ID','casing_swage','10.75','712','17250','8060',null,'IRI','2016-05-23','160510',null,'19786K',null,'10707090-290616-0006964','1','hours'),
	('other','stump_guide-10.75','stump_guide','10.75',null,null,null,null,'VOLANT',null,'82901-4432A23-2',null,'AH71054',null,null,'1','hours'),
	('hoisting','TYPE SMX 350T SD DR ELEV F/10-3/4 CAS  SEE NOTE','side_door_elevator','10.75','350',null,null,null,'NOV','18.08.2015','NL25634375','10143587','28924K','50006440Y142','10707090-050517-0005232','1','hours'),
	('hoisting','TYPE SMX 350T SD DR ELEV F/10-3/4 CAS  SEE NOTE','side_door_elevator','10.75','350',null,null,null,'NOV','29.04.2016','NL37479426','10143587','28923K','50006440Y142','10707090-050517-0005232','1','hours'),
	('make_up','10 3/4 Jaw assembly 58.673.00','tong_jaw_set','10.75',null,'50000',null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('gripping','UC-3 10.3/4null9.5/8 1:4 Tapered manual casing slips','manual_slips','10.75',null,null,null,null,'JIANGSU RUTONG','2018-09-04','809007',null,'39893K',null,'10707090-041018-0011783','2','hours'),
	('make_up','14 X 10 3/4 D.T. JAW SET ASSY. 50K FT./LB. LIMIT SET CONSIST OF TWO 2 JAWS','tong_jaw_set','10.75',null,'50000',null,null,'MCCOY',null,'CJDT14H10750',null,null,null,'10703070-070819-0023862','2','hours'),
	('make_up','ASSEMBLY  DOVETAIL ADAPTER  15 X 10 3/4 set of 3','tong_backup_jaw_set','10.75',null,'50000',null,null,'MCCOY',null,'BUDT15-10750',null,null,null,'10703070-070819-0023862','2','hours'),
	('make_up','JAW SET ASSEMBLY 14x10 3/4','tong_jaw_set','10.75',null,null,null,null,'MCCOY',null,null,'CJDT14H10750',null,'80017262',null,'2','hours'),
	('make_up','JAW ASSEMBLY 15x10 3/4','tong_backup_jaw_set','10.75',null,null,null,null,'MCCOY',null,null,'BUDT1510750A',null,'80017269',null,'4','hours'),
	('other','stump_guide-10.75','stump_guide','10.75',null,null,null,null,'VOLANT',null,'82083-4458A13-1',null,'AH71055',null,null,'4','hours'),
	('other','safety_nubbing/OD11.75/ ID 9.514/ PIN 10 3/4 VAM TOP 60.7 ppf','safety_nubbing','10.75',null,null,null,null,'SLB KZ','27.11.2015',null,null,'14827K',null,'ГТД 50711-250414-0002357','1','hours'),
	('gripping','safety_clamp 9 5/8','safety_clamp','10.63',null,null,null,null,'JSPM','2018-06-26','180611',null,'180611',null,'10707090-240818-0010101','2','hours'),
	('gripping','C type safety_clamp 9 5/8','safety_clamp','10.63',null,null,null,null,'JSPM','2018-06-17','180527',null,'40158K',null,'10707090-130818-0009531','2','hours'),
	('make_up','JAW SET ASSEMBLY 14x9 7/8','tong_jaw_set','9.88',null,null,null,null,'MCCOY',null,null,'CJDT14H09875',null,'80018552',null,'2','hours'),
	('make_up','JAW ASSEMBLY 15x9 7/8','tong_backup_jaw_set','9.88',null,null,null,null,'MCCOY',null,null,'BUDT1509875A',null,'80018554',null,'4','hours'),
	('other','stump_guide-9.63','stump_guide','9.63',null,null,null,null,'VOLANT',null,'82083-4389A07-06',null,'AH71053',null,null,null,'hours'),
	('other','safety_nubbing 9.63-47ppf-VAMTOP','safety_nubbing','9.63',null,null,null,null,'VOLANT',null,'82953-04-4380A19-01','82953',null,null,null,null,'hours'),
	('make_up','ASSEMBLY  JAW  DT  14 X 9 5/8 ','tong_jaw_set','9.63',null,null,null,null,'MCCOY',null,null,'CJDT14H09625',null,'CJDT14H09625','10707090-260618-0007407','1','hours'),
	('make_up','Jaw set of master tong 9 5/8','tong_jaw_set','9.63',null,'50000',null,null,'WELONG',null,null,null,null,null,'10702070-031018-0147220','1','hours'),
	('make_up','Jaw set of backup tong 9 5/8','tong_backup_jaw_set','9.63',null,'50000',null,null,'WELONG',null,null,null,null,null,'10702070-031018-0147220','1','hours'),
	('make_up','Jaws for casing tong 9 5/8  set ','tong_jaw_set','9.63',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS958','10702070-031018-0147220','1','hours'),
	('make_up','Jaws for backup tong 10 3/4   set ','tong_backup_jaw_set','9.63',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS958B','10702070-031018-0147220','1','hours'),
	('hoisting','9.5/8 slips + boTHOMAS TOOLSom guides for SE500 elevator  SE 4.1/2~14/500T 9.5/8 slip assy + boTHOMAS TOOLSom guides','spider_elevator','9.63','500',null,null,null,'JIANGSU RUTONG','2018-05-17','80401',null,'38490K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','9.5/8 slips + boTHOMAS TOOLSom guides for SE500 elevator  SE 4.1/2~14/500T 9.5/8 slip assy + boTHOMAS TOOLSom guides','spider_elevator','9.63','500',null,null,null,'JIANGSU RUTONG','2018-05-17','80402',null,'38491K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','9.5/8 slips + top guides for SE500 spider  SE 4.1/2~14/500T 9.5/8 slip assy + top guides','spider_elevator','9.63','500',null,null,null,'JIANGSU RUTONG','2018-05-17','80403',null,'38492K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','9.5/8 slips + top guides for SE500 spider  SE 4.1/2~14/500T 9.5/8 slip assy + top guides','spider_elevator','9.63','500',null,null,null,'JIANGSU RUTONG','2018-05-17','80404',null,'38493K',null,'10707090-160718-0008279','1','hours'),
	('other','API drift 9 5/8 #43.5ppf ','drift','9.63',null,null,null,null,null,null,'9.625-43.5-2',null,null,null,null,'1','meters'),
	('make_up','9 5/8 jaws for TQ508/70 master tong','tong_jaw_set','9.63',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,null,'1','hours'),
	('make_up','9 5/8 jaws for TQ508/70 master tong','tong_jaw_set','9.63',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,null,'1','hours'),
	('make_up','9 5/8 jaws for TQ508/70 backup tong','tong_backup_jaw_set','9.63',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,null,'1','hours'),
	('make_up','9 5/8 jaws for TQ508/70 backup tong','tong_backup_jaw_set','9.63',null,'50000',null,null,'JIANGSU RUTONG',null,null,null,null,null,null,'1','hours'),
	('make_up','9 5/8 Jaw assembly 58.671.00','tong_jaw_set','9.63',null,'50000',null,null,'JSPM','2019-04-25','190403',null,null,null,null,'1','hours'),
	('hoisting','side_door_elevator 9 5/8 500t','side_door_elevator','9.63','500',null,null,null,'WELONG','2019-07-16','4181123',null,'40062K',null,'10702070-031018-0147220','1','hours'),
	('hoisting','SJ elevator 9 5/8','single_joint_elevator','9.63','5',null,null,null,'JSPM','2018-06-17','180504',null,'40152K',null,'10707090-130818-0009531','1','hours'),
	('hoisting','side_door_elevator 9 5/8 350t','side_door_elevator','9.63','350',null,null,null,'JSPM','2018-06-17','180504',null,'40148K',null,'10707090-130818-0009531','1','hours'),
	('hoisting','SLIP ASSY 9 5/8x9 5/8 FOR DEN-CON  FLUSH CASING SPIDER 1400','spider_elevator','9.63','500',null,null,null,'DEN-CON',null,'13840-1',null,null,null,'from 4','1','hours'),
	('hoisting','TOP GUIDE  9 5/8','SE_guides','9.63','500',null,null,null,'DEN-CON',null,'18419-7',null,'18419-7',null,'from 4','1','hours'),
	('circulation','9-5/8” Water Bushing  XT57 box X 47# JFE BEAR PIN 2-3/8 ID','casing_swage','9.63','664','28280','9440',null,'IRI','2016-05-23','160511',null,'19787K',null,'10707090-290616-0006964','1','hours'),
	('gripping','BAASH-ROSS TYPE C safety_clamp COMPLETE W/ 12 inserts & WRENCH suitable for 8-1/2” – 9-5/8” OD tubulars','safety_clamp','9.63',null,null,null,null,'AOT','1997-09-26','6550',null,'9546',null,'10707090-020616-0005418','1','hours'),
	('circulation','9 5/8” Water Bushing  5 ½” FH Box X 40# TSH MS Pin','casing_swage','9.63','560','11930','7900',null,'IRI','2017-06-23','170621',null,'29748K',null,'10707090-250717-0009880','1','hours'),
	('circulation','9 5/8” Water Bushing  5 ½” FH Box X 40# TSH MS Pin','casing_swage','9.63','560','11930','7900',null,'IRI','2017-06-23','170622',null,'29749K',null,'10707090-250717-0009880','1','hours'),
	('other','safety_nubbing 9.63-47ppf-VAMTOP','safety_nubbing','9.63',null,null,null,null,'VOLANT',null,'82953-04-4380A19-03','82953','33371K',null,null,'1','hours'),
	('other','safety_nubbing 9.63-47ppf-VAMTOP','safety_nubbing','9.63',null,null,null,null,'VOLANT',null,'81556-5260-AK-2','81556','33372K',null,null,'1','hours'),
	('other','safety_nubbing 9.63-47lb-TENARIS WEDJE 563','safety_nubbing','9.63',null,null,null,null,'VOLANT',null,'82384-4152A14-01','82384','25860K',null,null,'1','hours'),
	('other','safety_nubbing 9.63-47lb-TENARIS WEDJE 563','safety_nubbing','9.63',null,null,null,null,'VOLANT',null,'81318-4342A06-07','82384','25861K',null,null,'1','hours'),
	('other','stump_guide 9.63','stump_guide','9.63',null,null,null,null,'VOLANT',null,'81318-4342A06-06','81318','84325J',null,null,'1','hours'),
	('other','API drift for 9 5/8 #40ppf casing ','drift','9.63',null,null,null,null,null,null,'TRS071902',null,null,null,null,'1','meters'),
	('other','safety_nubbing 9.63-47ppf-VAMTOP','safety_nubbing','9.63',null,null,null,null,'VOLANT',null,'82953-04-4380A19-02','82953',null,null,null,'1','hours'),
	('other','safety_nubbing 9.63-47ppf-VAMTOP','safety_nubbing','9.63',null,null,null,null,'VOLANT',null,'81556-5260-AK-4','81556',null,null,null,'1','hours'),
	('other','stump_guide 9.63','stump_guide','9.63',null,null,null,null,'VOLANT',null,'81318-3914B04-4','81318',null,'80018279',null,'1','hours'),
	('other','stump_guide 9.63','stump_guide','9.63',null,null,null,null,'VOLANT',null,'82901-4380A12-03','81318',null,'80018279',null,'1','hours'),
	('make_up','9 5/8 Jaw assembly 58.630.00','tong_jaw_set','9.63',null,'50000',null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('hoisting','side_door_elevator 9 5/8 500t','side_door_elevator','9.63','500',null,null,null,'WELONG','2019-07-16','4181124',null,'40061K',null,'10702070-031018-0147220','2','hours'),
	('gripping','CMS manual_slips 9 5/8','manual_slips','9.63',null,null,null,null,'JSPM','2018-06-17','180532',null,'40155K',null,'10707090-130818-0009531','2','hours'),
	('hoisting','SJ elevator 9 5/8','single_joint_elevator','9.63','5',null,null,null,'JSPM','2018-06-17','180503',null,'40151K',null,'10707090-130818-0009531','2','hours'),
	('hoisting','SJ elevator 9 5/8','single_joint_elevator','9.63','5',null,null,null,'JIANGSU RUTONG','2017-06-07','60977',null,'31652KA',null,'10707090-210717-0009704','2','hours'),
	('hoisting','SJ elevator 9 5/8','single_joint_elevator','9.63','5',null,null,null,'JIANGSU RUTONG','2017-06-07','60985',null,'31653K',null,'10707090-210717-0009704','2','hours'),
	('hoisting','side_door_elevator 9 5/8 350t','side_door_elevator','9.63','350',null,null,null,'JSPM','2018-06-17','180503',null,'40147K',null,'10707090-130818-0009531','2','hours'),
	('gripping','UC-3 10.3/4×9.5/8 1:4 Tapered manual casing slips','manual_slips','9.63',null,null,null,null,'JSPM','2019-06-12','190601',null,'190601',null,'10702070-300719-0146601','2','hours'),
	('make_up','ASSEMBLY  JAW  DT  14 X 9 5/8','tong_jaw_set','9.63',null,'50000',null,null,'MCCOY',null,'CJDT14H09625',null,null,null,'10703070-070819-0023862','2','hours'),
	('make_up','ASSEMBLY  DOVETAIL ADAPTER  15 X 9 5/8','tong_backup_jaw_set','9.63',null,'50000',null,null,'MCCOY',null,'BUDT15-09625',null,null,null,'10703070-070819-0023862','2','hours'),
	('gripping','VARCO 9-5/8 CMS-XL Casing Slip 14Segments V5309','manual_slips','9.63',null,null,null,null,'NOV','2016-05-17','V5309',null,'19778K','V5309','10707090-180616-0006281','2','hours'),
	('make_up','JAW SET ASSEMBLY 14x9 5/8','tong_jaw_set','9.63',null,null,null,null,'MCCOY',null,null,'CJDT14H09625',null,'80017263',null,'2','hours'),
	('other','stabbing_guide 9 5/8','stabbing_guide','9.63',null,null,null,null,'JSPM','2018-06-26',null,null,'39868K',null,'10707090-160718-0008279','2','hours'),
	('other','thread_protector 9 5/8','thread_protector','9.63',null,null,null,null,'JSPM','2018-06-26',null,null,'40159K',null,'10707090-130818-0009531','2','hours'),
	('other','thread_protector 9 5/8','thread_protector','9.63',null,null,null,null,'JSPM','2018-06-26',null,null,'40160K',null,'10707090-130818-0009531','2','hours'),
	('other','thread_protector 9 5/8','thread_protector','9.63',null,null,null,null,'JSPM','2018-06-26',null,null,'40161K',null,'10707090-130818-0009531','2','hours'),
	('other','thread_protector 9 5/8','thread_protector','9.63',null,null,null,null,'JSPM','2018-06-26',null,null,'40162K',null,'10707090-130818-0009531','2','hours'),
	('other','thread_protector 9 5/8','thread_protector','9.63',null,null,null,null,'JSPM','2018-06-26',null,null,'40163K',null,'10707090-130818-0009531','2','hours'),
	('other','thread_protector 9 5/8','thread_protector','9.63',null,null,null,null,'JSPM','2018-06-26',null,null,'40164K',null,'10707090-130818-0009531','2','hours'),
	('other','stabing guide 9 5/8','stabbing_guide','9.63',null,null,null,null,'JSPM','2018-06-17',null,null,'40165K',null,'10707090-130818-0009531','2','hours'),
	('other','API drift 9 5/8#47ppf','drift','9.63',null,null,null,null,null,null,null,null,null,null,null,'2','meters'),
	('other','API drift 9 5/8 #43.5ppf ','drift','9.63',null,null,null,null,null,null,'TRS022001',null,null,null,null,'2','meters'),
	('other','API drift for 9 5/8 #40ppf casing ','drift','9.63',null,null,null,null,null,null,'TRS071901',null,null,null,null,'2','meters'),
	('make_up','ASSEMBLY  DOVETAIL ADAPTER  15 X 9 5/8 ','tong_backup_jaw_set','9.63',null,null,null,null,'MCCOY',null,null,'BUDT15-09625',null,'BUDT15-09625','10707090-260618-0007407','4','hours'),
	('make_up','JAW ASSEMBLY 15x9 5/8','tong_backup_jaw_set','9.63',null,null,null,null,'MCCOY',null,null,'BUDT1509625A',null,'80017271',null,'4','hours'),
	('other','stump_guide-9.63','stump_guide','9.63',null,null,null,null,'VOLANT',null,'81318-4406A03-3',null,'AH71052',null,null,'7','hours'),
	('other','stump_guide 9.63','stump_guide','9.63',null,null,null,null,'VOLANT',null,'81318-4342A06-05','81318','84328J',null,null,'7','hours'),
	('other','stump_guide 9.63','stump_guide','9.63',null,null,null,null,'VOLANT',null,'81318-4342A06-06','81318','84327J',null,null,'7','hours'),
	('gripping','UC-3 10.3/4×9.5/8 1:4 Tapered manual casing slips','manual_slips','9.63',null,null,null,null,'JSPM','2019-06-12','190602',null,'190602',null,'10702070-300719-0146601','6','hours'),
	('other','stump_guide 9.63','stump_guide','9.63',null,null,null,null,'VOLANT',null,'81318-3914B04-5','81318',null,null,null,null,'hours'),
	('other','safety_nubbing/OD10.62/ ID 8.535/ PIN 9-5/8 VAM TOP 47 ppf','safety_nubbing','9.63',null,null,null,null,'SLB KZ','27.11.2015',null,null,'14825K',null,'ГТД 50711-250414-0002357','1','hours'),
	('gripping','SPIDER BUSHING 30-20 HINGE CASING SPIDER 30 200 TON ','hinged_casing_spider','20','200',null,null,null,null,null,null,null,'87269H-1',null,'10130050-181111-0021389','1','hours'),
	('gripping','HINGE CASING SPIDER 30 200 TON','hinged_casing_spider','30','200',null,null,null,null,null,null,null,'87268H-1',null,'10130050-181111-0021389','1','hours'),
	('gripping','8 5/8 100 API Spider','bowl','8.63','100',null,null,null,null,null,null,null,'16771K',null,null,'1','hours'),
	('gripping','8 5/8 100 API Spider','bowl','8.63','100',null,null,null,null,null,'10738',null,null,null,null,'2','hours'),
	('gripping','30x20 bushing for JOY30/200 spider','hinged_casing_spider','20','200',null,null,null,'JSPM','2018-05-29','180502',null,'40144K',null,'10707090-130818-0009531','2','hours'),
	('gripping','TYPE C safety_clamp FOR 8-1/8 OD WASH PIPE','safety_clamp','8.63',null,null,null,null,'DRECO MIDDLE EAST',null,'507217/005-1',null,'12798K','NPN/01','from fishing','1','hours'),
	('gripping','TYPE C safety_clamp FOR 8-1/8 OD WASH PIPE','safety_clamp','8.63',null,null,null,null,'DRECO MIDDLE EAST',null,'507217/005-2',null,'12801K','NPN/01','from fishing','1','hours'),
	('make_up','KT 8625 FCBU','power_tong','8.63',null,null,null,null,'MCCOY','2012-11-22','20120458',null,'61719JA',null,'4','1','hours'),
	('make_up','HD 8625','power_tong','8.63',null,null,null,null,'MCCOY','2019-03-09','U190098',null,'U190098',null,null,'1','hours'),
	('gripping','JOY30/200 CASING SPIDER','hinged_casing_spider','30','200',null,null,null,'JSPM','2018-05-29','180501',null,'40145K',null,'10707090-130818-0009531','2','hours'),
	('gripping','JOY 13.3/8/200T Casing Spider','hinged_casing_spider','13.38','200',null,null,null,'JIANGSU RUTONG','2018-05-17','51202',null,'38470K',null,'10707090-160718-0008279','2','hours'),
	('make_up','HD 8625 CONFIGUREDTONG W CLINCHER BU 80-0605-5 ','power_tong','8.63',null,'35000','3000','60','MCCOY','2017-06-26','C170035',null,'31969K',null,'10707090-290817-0011751','2','hours'),
	('make_up','HD 8625 CONFIGUREDTONG W CLINCHER BU 80-0605-5 ','power_tong','8.63',null,'35000','3000','60','MCCOY','2018-06-26','C170038',null,'31970K',null,'10707090-290817-0011751','2','hours'),
	('make_up','Lug Jaw  For Item # 4 Type SDD Tong LJ4to8.5','manual_tong_jaws','8.5',null,'100000',null,null,'BVM','2017-03-30','36804',null,null,'LJ4TO8.5','10707090-190517-0005987','1','hours'),
	('make_up','Lug Jaw  For Item # 4 Type SDD Tong LJ4to8.5','manual_tong_jaws','8.5',null,'100000',null,null,'BVM','2017-03-30','36804',null,null,'LJ4TO8.5','10707090-190517-0005987','1','hours'),
	('make_up','LUG JAW 3 1/2 - 8 1/4 FOR  BV 65 TONG','manual_tong_jaws','8.25',null,'65000',null,null,'B+V',null,'80120',null,null,'80011491',null,'1','hours'),
	('make_up','ASSEMBLY  JAW  DT  14 X 7 5/8','tong_jaw_set','7.63',null,null,null,null,'MCCOY',null,null,'CJDT14H07625',null,'CJDT14H07625','10702070-200918-0139641','1','hours'),
	('make_up','7.625 JAW DIE KIT KT 7585  PN 1050-JDK-155-S','tong_jaw_set','7.63',null,'29000',null,null,'MCCOY',null,null,'1050-JDK-155-S','40734K',null,'10707090-031218-0014063','1','hours'),
	('make_up','Jaws for casing tong 7 5/8  set ','tong_jaw_set','7.63',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS758','10702070-031018-0147220','1','hours'),
	('make_up','Jaws for backup tong 7 5/8   set ','tong_backup_jaw_set','7.63',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS758B','10702070-031018-0147220','1','hours'),
	('gripping','E/175 7.5/8 Slip Assy Integral slip','pneumatic_tubing_spider','7.63','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 7.5/8 ','10707090-240818-0010101','1','hours'),
	('hoisting','7.5/8 slips + boTHOMAS TOOLSom guides for SE500 elevator  SE 4.1/2~14/500T 7.5/8 slip assy + boTHOMAS TOOLSom guides','spider_elevator','7.63','500',null,null,null,'JIANGSU RUTONG','2018-05-17','60807',null,'38494K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','7.5/8 slips + boTHOMAS TOOLSom guides for SE500 elevator  SE 4.1/2~14/500T 7.5/8 slip assy + boTHOMAS TOOLSom guides','spider_elevator','7.63','500',null,null,null,'JIANGSU RUTONG','2018-05-17','60805',null,'38495K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','7.5/8 slips + top guides for SE500 spider  SE 4.1/2~14/500T 7.5/8 slip assy + top guides','spider_elevator','7.63','500',null,null,null,'JIANGSU RUTONG','2018-05-17','71009',null,'38497K',null,'10707090-160718-0008279','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.625 IN OD ','tong_backup_jaw_die','7.63',null,'29000',null,null,'MCCOY',null,null,null,'33787K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.625 IN OD ','tong_backup_jaw_die','7.63',null,'29000',null,null,'MCCOY',null,null,null,'33788K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.625 IN OD ','tong_backup_jaw_die','7.63',null,'29000',null,null,'MCCOY',null,null,null,'33789K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.625 IN OD ','tong_backup_jaw_die','7.63',null,'29000',null,null,'MCCOY',null,null,null,'33790K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.625 IN OD ','tong_backup_jaw_die','7.63',null,'29000',null,null,'MCCOY',null,null,null,'33791K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.625 IN OD','tong_backup_jaw_die','7.63',null,'29000',null,null,'MCCOY',null,null,null,'33792K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-155 / 7.625 JAW DIE KIT HD8625','tong_jaw_set','7.63',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-155','31989K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-155 / 7.625 JAW DIE KIT HD8625','tong_jaw_set','7.63',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-155','31990K',null,'10707090-290817-0011751','1','hours'),
	('hoisting','7.5/8 slips + top guides for SE500 spider  SE 4.1/2~14/500T 7.5/8 slip assy + top guides','spider_elevator','7.63','500',null,null,null,'JIANGSU RUTONG','2018-05-17','71001',null,'38496K',null,'10707090-160718-0008279','1','hours'),
	('hoisting','SLIP ASSY 7 5/8x7 FOR DEN-CON  FLUSH CASING SPIDER 1400','spider_elevator','7.63','500',null,null,null,'DEN-CON',null,'13841-2',null,null,null,'from 4','1','hours'),
	('make_up','ASSEMBLY  DOVETAIL ADAPTER  15 X 7 5/8','tong_backup_jaw_set','7.63',null,null,null,null,'MCCOY',null,null,'BUDT15-07625A',null,'BUDT15-07625A','10702070-200918-0139641','2','hours'),
	('make_up','7 5/8 Jaw assembly 58.671.00','tong_jaw_set','7.63',null,'50000',null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('gripping','E/175T Spider Body  complete but less Slip Assy','pneumatic_tubing_spider','7.63','175',null,null,null,'JSPM','2018-06-26','180601',null,'39884K',null,'10707090-240818-0010101','2','hours'),
	('gripping','BAASH-ROSS TYPE C safety_clamp COMPLETE W/11 SEGMENTS & WRENCH','safety_clamp','7.63',null,null,null,null,'AOT','2006-08-15','46050',null,'63483',null,'10707090-020616-0005418','2','hours'),
	('make_up','Wraparound dies for clincher 14  14x7 5/8 - 4 1/2','tong_jaw_set','7.63',null,null,null,null,'MCCOY',null,null,'CLEBU1121','19792K',null,null,'2','hours'),
	('make_up','Wraparound dies for clincher 14  14x7 5/8 - 4 1/2','tong_jaw_set','7.63',null,null,null,null,'MCCOY',null,null,'CLEBU1121','19793K',null,null,'2','hours'),
	('make_up','JAW SET ASSEMBLY 14x7 5/8 ','tong_jaw_set','7.63',null,null,null,null,'MCCOY',null,null,'CJDT14H07625',null,'80017264',null,'2','hours'),
	('make_up','7.625 JAW DIE KIT KT7585','tong_jaw_set','7.63',null,null,null,null,'MCCOY',null,null,'1050-JDK-155-S',null,null,null,'2','hours'),
	('make_up','DIE CLINCHER 8.625 IN * 7.625 IN','tong_backup_jaw_set','7.63',null,null,null,null,'MCCOY',null,null,'BUC86257625',null,null,null,'2','hours'),
	('make_up','JAW ASSEMBLY 15x7 5/8 ','tong_backup_jaw_set','7.63',null,null,null,null,'MCCOY',null,null,'BUDT1507625A',null,'80017273',null,'4','hours'),
	('make_up','Assembly  7.25 JAW DIE KIT  KT8625  PN 1050-JDK-151-S','tong_jaw_set','7.25',null,'29000',null,null,'MCCOY',null,null,'1050-JDK-151-S','40727K',null,'10707090-031218-0014063','1','hours'),
	('make_up','8625-JDK-151 / ASSEMBLY  7.250 JAW DIE KIT  8625-35K','tong_jaw_set','7.25',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-151','32059K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86257250 / DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.250 IN OD','tong_backup_jaw_die','7.25',null,'29000',null,null,'MCCOY',null,null,'BUC86257250','32074K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86257250 / DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.250 IN OD','tong_backup_jaw_die','7.25',null,'29000',null,null,'MCCOY',null,null,'BUC86257250','33368K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86257250 / DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.250 IN OD','tong_backup_jaw_die','7.25',null,'29000',null,null,'MCCOY',null,null,'BUC86257250','33367K',null,'10707090-290817-0011751','1','hours'),
	('make_up','ASSEMBLY  JAW  DT  14 X 7','tong_jaw_set','7',null,null,null,null,'MCCOY',null,null,'CJDT14H07000',null,'CJDT14H07000','10702070-200918-0139641','1','hours'),
	('other','02-E0553 / thread_protector  PRO-TECH  NON-INFLATABLE  7 A','thread_protector','7',null,null,null,null,'MCCOY',null,null,'02-E0553','31666K',null,'10707090-240717-0009837','1','hours'),
	('other','02-E0553 / thread_protector  PRO-TECH  NON-INFLATABLE  7 A','thread_protector','7',null,null,null,null,'MCCOY',null,null,'02-E0553','31667K',null,'10707090-240717-0009837','1','hours'),
	('other','02-E0553 / thread_protector  PRO-TECH  NON-INFLATABLE  7 A','thread_protector','7',null,null,null,null,'MCCOY',null,null,'02-E0553','31668K',null,'10707090-240717-0009837','1','hours'),
	('make_up','7.00 JAW DIE KIT KT7585  PN 1050-JDK-150-S ','tong_jaw_set','7',null,'29000',null,null,'MCCOY',null,null,'1050-JDK-150-S ','40732K',null,'10707090-031218-0014063','1','hours'),
	('make_up','7.00 JAW DIE KIT KT7585  PN 1050-JDK-150-S ','tong_jaw_set','7',null,'29000',null,null,'MCCOY',null,null,'1050-JDK-150-S ','40733K',null,'10707090-031218-0014063','1','hours'),
	('make_up','Jaw set of master tong 7','tong_jaw_set','7',null,'50000',null,null,'WELONG',null,null,null,null,null,'10702070-031018-0147220','1','hours'),
	('make_up','Jaw set of backup tong 7','tong_backup_jaw_set','7',null,'50000',null,null,'WELONG',null,null,null,null,null,'10702070-031018-0147220','1','hours'),
	('make_up','Jaws for casing tong 7  set ','tong_jaw_set','7',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS7','10702070-031018-0147220','1','hours'),
	('make_up','Jaws for backup tong 7   set ','tong_backup_jaw_set','7',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS7B','10702070-031018-0147220','1','hours'),
	('gripping','E/175 7x7 Slip Assy','pneumatic_tubing_spider','7','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 5.1/2X5.1/2','10707090-240818-0010101','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.000 IN OD','tong_backup_jaw_die','7',null,'29000',null,null,'MCCOY',null,null,null,'33782K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.000 IN OD','tong_backup_jaw_die','7',null,'29000',null,null,'MCCOY',null,null,null,'33783K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.000 IN OD ','tong_backup_jaw_die','7',null,'29000',null,null,'MCCOY',null,null,null,'33795K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.000 IN OD ','tong_backup_jaw_die','7',null,'29000',null,null,'MCCOY',null,null,null,'33784K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.000 IN OD ','tong_backup_jaw_die','7',null,'29000',null,null,'MCCOY',null,null,null,'33785K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 7.000 IN OD ','tong_backup_jaw_die','7',null,'29000',null,null,'MCCOY',null,null,null,'33786K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-150 / 7 JAW DIE KIT KT8625HT ','tong_jaw_set','7',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-150','31987K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-150 / 7 JAW DIE KIT KT8625HT ','tong_jaw_set','7',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-150','31988K',null,'10707090-290817-0011751','1','hours'),
	('make_up','7 Jaw assembly 58.674.00','tong_jaw_set','7',null,'50000',null,null,'JSPM','2019-04-25','190402',null,null,null,null,'1','hours'),
	('gripping','CMS manual_slips 7','manual_slips','7',null,null,null,null,'JSPM','2018-06-17','180530',null,'40156K',null,'10707090-130818-0009531','1','hours'),
	('gripping','CMS manual_slips 7','manual_slips','7',null,null,null,null,'JSPM','2018-06-17','180531',null,'40157K',null,'10707090-130818-0009531','1','hours'),
	('hoisting','SJ elevator 7','single_joint_elevator','7','5',null,null,null,'JSPM','2018-06-17','180502',null,'40154K',null,'10707090-130818-0009531','3','hours'),
	('hoisting','TOP GUIDE 7','SE_guides','7','500',null,null,null,'DEN-CON',null,'18419-4',null,null,null,'from 4','1','hours'),
	('circulation','7” Water Bushing  5 ½” FH Box X 29# VA Superior Pin','casing_swage','7','413','14660','11210',null,'IRI','2017-06-23','170624',null,'29751K',null,'10707090-250717-0009880','1','hours'),
	('circulation','7” Water Bushing  5 ½” FH Box X 29# VA Superior Pin','casing_swage','7','413','14660','11210',null,'IRI','2017-06-23','170623',null,'29750K',null,'10707090-250717-0009880','1','hours'),
	('make_up','ASSEMBLY ADAPTER DIE DOVETAIL FABRICATED 15.000 IN X 7.000 IN','tong_backup_jaw_set','7',null,null,null,null,'MCCOY',null,null,'BUDT15-07000A',null,'BUDT15-07000A','10702070-200918-0139641','2','hours'),
	('make_up','7 Jaw assembly 58.674.00','tong_jaw_set','7',null,'50000',null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('hoisting','SJ elevator 7','single_joint_elevator','7','5',null,null,null,'JSPM','2018-06-17','180501',null,'40153K',null,'10707090-130818-0009531','2','hours'),
	('hoisting','side_door_elevator 7 250t','side_door_elevator','7','250',null,null,null,'JSPM',null,null,null,'40149K',null,'10707090-130818-0009531','2','hours'),
	('hoisting','side_door_elevator 7 250t','side_door_elevator','7','250',null,null,null,'JSPM',null,null,null,'40150K',null,'10707090-130818-0009531','2','hours'),
	('hoisting','SIDEDOOR ELEVATOR - 7 ID','side_door_elevator','7','350',null,null,null,'TIOT',null,null,null,'50446JA',null,'from 4','2','hours'),
	('hoisting','SLIP SET 7 FOR HYC ELEVATOR','slip_type_elevator','7','200',null,null,null,'BVM',null,null,null,'60902HA',null,null,'2','hours'),
	('make_up','JAW SET ASSEMBLY 14x7  ','tong_jaw_set','7',null,null,null,null,'MCCOY',null,null,'CJDT14H07000',null,'80017265',null,'2','hours'),
	('make_up','7.00 JAW DIE KIT KT7585','tong_jaw_set','7',null,null,null,null,'MCCOY',null,null,'1050-JDK-150-S',null,null,null,'2','hours'),
	('make_up','DIE CLINCHER 8.625 IN * 7.000 IN','tong_backup_jaw_set','7',null,null,null,null,'MCCOY',null,null,'BUC86257000',null,null,null,'2','hours'),
	('other','stabing guide 7','stabbing_guide','7',null,null,null,null,'JSPM','2018-06-17',null,null,'40166K',null,'10707090-130818-0009531','2','hours'),
	('make_up','JAW ASSEMBLY 15x7 ','tong_backup_jaw_set','7',null,null,null,null,'MCCOY',null,null,'BUDT1507000A ',null,'80017274',null,'4','hours'),
	('gripping','CMS manual_slips 6 5/8','manual_slips','6.63',null,null,null,null,'JSPM','2018-06-08','180534',null,'39883K',null,'10707090-240818-0010101',null,'hours'),
	('make_up','ASSEMBLY  JAW  DT  14 X 6 5/8 ','tong_jaw_set','6.63',null,null,null,null,'MCCOY',null,null,'CJDT14H06625',null,'CJDT14H06625','10707090-260618-0007407','1','hours'),
	('make_up','6.625 JAW DIE KIT KT 8625  PN 1050-JDK-145-S','tong_jaw_set','6.63',null,'29000',null,null,'MCCOY',null,null,'1050-JDK-145-S','40730K',null,'10707090-031218-0014063','1','hours'),
	('make_up','6.625 JAW DIE KIT KT 8625  PN 1050-JDK-145-S ','tong_jaw_set','6.63',null,'29000',null,null,'MCCOY',null,null,'1050-JDK-145-S','40731K',null,'10707090-031218-0014063','1','hours'),
	('make_up','Jaws for casing tong 6 5/8  set','tong_jaw_set','6.63',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS658','10702070-031018-0147220','1','hours'),
	('make_up','Jaws for backup tong 6 5/8   set ','tong_backup_jaw_set','6.63',null,'50000',null,null,'WELONG',null,null,null,null,'JAWS658B','10702070-031018-0147220','1','hours'),
	('gripping','E/175 7x6.5/8 Inserts 4 pcs/set ','pneumatic_tubing_spider','6.63','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 7X6.5/8 ','10707090-240818-0010101','1','hours'),
	('gripping','E/175 7x6.5/8 Inserts 4 pcs/set ','pneumatic_tubing_spider','6.63','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 7X6.5/8 ','10707090-240818-0010101','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 6.625 IN OD','tong_backup_jaw_die','6.63',null,'29000',null,null,'MCCOY',null,null,null,'33776K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 6.625 IN OD ','tong_backup_jaw_die','6.63',null,'29000',null,null,'MCCOY',null,null,null,'33777K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 6.625 IN OD ','tong_backup_jaw_die','6.63',null,'29000',null,null,'MCCOY',null,null,null,'33778K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 6.625 IN OD ','tong_backup_jaw_die','6.63',null,'29000',null,null,'MCCOY',null,null,null,'33779K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 6.625 IN OD ','tong_backup_jaw_die','6.63',null,'29000',null,null,'MCCOY',null,null,null,'33780K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 6.625 IN OD','tong_backup_jaw_die','6.63',null,'29000',null,null,'MCCOY',null,null,null,'33781K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-145 / 6.625 JAW DIE KITKT8625 HT ','tong_jaw_set','6.63',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-145','31985K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-145 / 6.625 JAW DIE KITKT8625 HT','tong_jaw_set','6.63',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-145','31986K',null,'10707090-290817-0011751','1','hours'),
	('make_up','6 5/8 Jaw assembly 58.674.00','tong_jaw_set','6.63',null,'50000',null,null,'JSPM','2019-04-25','190401',null,null,null,null,'1','hours'),
	('gripping','safety_clamp 6 5/8','safety_clamp','6.63',null,null,null,null,'JSPM','2018-06-26','180610',null,'39863K',null,'10707090-240818-0010101','1','hours'),
	('make_up','ASSEMBLY  DOVETAIL ADAPTER  15 X 6 5/8','tong_backup_jaw_set','6.63',null,null,null,null,'MCCOY',null,null,'BUDT15-06625A',null,'BUDT15-06625A','10702070-200918-0139641','2','hours'),
	('make_up','6 5/8 Jaw assembly 58.674.00','tong_jaw_set','6.63',null,'50000',null,null,'JSPM',null,null,null,null,null,'10707090-130818-0009531','2','hours'),
	('hoisting','side_door_elevator 6 5/8 250t SLX 250','side_door_elevator','6.63','250',null,null,null,'JSPM','2018-06-26','180606',null,'39885K',null,'10707090-240818-0010101','2','hours'),
	('hoisting','side_door_elevator 6 5/8 250t SLX 250','side_door_elevator','6.63','250',null,null,null,'JSPM','2018-06-26','180607',null,'39886K',null,'10707090-240818-0010101','2','hours'),
	('gripping','CMS manual_slips 6 5/8','manual_slips','6.63',null,null,null,null,'JSPM','2018-06-08','180535',null,'39882K',null,'10707090-240818-0010101','2','hours'),
	('hoisting','SJ elevator 6 5/8','single_joint_elevator','6.63','5',null,null,null,'JSPM','2018-06-26','180603',null,'39890K',null,'10707090-240818-0010101','2','hours'),
	('hoisting','SJL ELEVATOR 6-5/8  CASING','single_joint_elevator','6.63','5',null,null,null,null,null,null,null,'81950HA',null,null,'2','hours'),
	('gripping','safety_clamp 5 1/2','safety_clamp','6.63',null,null,null,null,'JSPM','2018-06-26','180609',null,'39864K',null,'10707090-240818-0010101','2','hours'),
	('make_up','6.625 JAW DIE KIT KT7585','tong_jaw_set','6.63',null,null,null,null,'MCCOY',null,null,'1050-JDK-145-S',null,null,null,'2','hours'),
	('make_up','DIE CLINCHER 8.625 IN * 6.625 IN','tong_backup_jaw_set','6.63',null,null,null,null,'MCCOY',null,null,'BUC86256625',null,null,null,'2','hours'),
	('other','stabbing_guide 6 5/8','stabbing_guide','6.63',null,null,null,null,null,null,null,null,null,null,null,'2','hours'),
	('other','thread_protector 6 5/8','thread_protector','6.63',null,null,null,null,'JSPM','2018-06-26',null,null,'39874K',null,'10707090-160718-0008279','2','hours'),
	('other','API drift 6 5/8 #24ppf casing','drift','6.63',null,null,null,null,null,null,'TRS022003',null,null,null,null,'2','meters'),
	('other','API drift 6 5/8 #24ppf casing','drift','6.63',null,null,null,null,null,null,null,null,null,null,null,'2','meters'),
	('other','API drift 6 5/8 #24ppf casing','drift','6.63',null,null,null,null,null,null,null,null,null,null,null,'2','meters'),
	('other','Pneuatic thread_protector Klepo 6 5/8 Cas','thread_protector','6.63',null,null,null,null,null,null,null,null,null,null,'from 4','2','hours'),
	('other','Pneuatic thread_protector Klepo 6 5/8 Cas','thread_protector','6.63',null,null,null,null,null,null,null,null,null,null,'from 4','2','hours'),
	('gripping','manual_slips CMS-XL 11 segments','manual_slips','6.63',null,null,null,null,null,null,'68033',null,null,null,null,'2','hours'),
	('make_up','8625-JDK-142 / 6.5 JAW DIE KIT KT8625 HT ','tong_jaw_set','6.5',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-142','32058K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86256500 / DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 6.500 IN OD','tong_backup_jaw_die','6.5',null,'29000',null,null,'MCCOY',null,null,'BUC86256500 ','32071K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86256500 / DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 6.500 IN OD','tong_backup_jaw_die','6.5',null,'29000',null,null,'MCCOY',null,null,'BUC86256500 ','32072K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86256500 / DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 6.500 IN OD','tong_backup_jaw_die','6.5',null,'29000',null,null,'MCCOY',null,null,'BUC86256500 ','32073K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86255875 / DIE  WRAP AROUND  FINE TOOTH  8 5/8 X 5.987','tong_backup_jaw_die','6',null,'29000',null,null,'MCCOY',null,null,'BUC86255875','32068K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86255875 / DIE  WRAP AROUND  FINE TOOTH  8 5/8 X 5.987','tong_backup_jaw_die','6',null,'29000',null,null,'MCCOY',null,null,'BUC86255875','32069K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86255875 / DIE  WRAP AROUND  FINE TOOTH  8 5/8 X 5.987','tong_backup_jaw_die','6',null,'29000',null,null,'MCCOY',null,null,'BUC86255875','32070K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-141 / ASSEMBLY  5.875 JAW DIE KIT  8625-35K ','tong_jaw_set','5.88',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-141','32057K',null,'10707090-290817-0011751','1','hours'),
	('make_up','Assembly  5-7/8 JAW DIE KIT  KT8625  PN 1050-JDK-1421-S ','tong_jaw_set','5.88',null,'29000',null,null,'MCCOY',null,null,'1050-JDK-1421-S ','40725K',null,'10707090-031218-0014063','1','hours'),
	('gripping','E/175 7x5.7/8 Inserts ','pneumatic_tubing_spider','5.88','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 7X5.7/8','10707090-240818-0010101','1','hours'),
	('make_up','5.75 JAW DIE KIT KT7585  PN 1050-JDK-142-S ','tong_jaw_set','5.75',null,'29000',null,null,'MCCOY',null,null,'1050-JDK-142-S ','40726K',null,'10707090-031218-0014063','1','hours'),
	('hoisting','Elevator  Center Latch  TypeGG 350 Ton 18 deg. for 5-1/2 IEU Having API FH Tool Joint ','center_latch_elevator','5.5','350',null,null,null,'BVM','2017-03-30','31690-S',null,'28938K',null,'10707090-190517-0005987','5','hours'),
	('hoisting','350-TON GG VARCO BJ BOTHOMAS TOOLSLENECK ELEVATOR F/5-1/2 DRILL PIPE','center_latch_elevator','5.5','350',null,null,null,'KEYSTONE ENERGY TOOLS','2012-04-11','76178',null,'76178',null,'10707090-310516-0005285','5','hours'),
	('hoisting','500-TON HGG VARCO {BJ} CENTER LATCH BOTHOMAS TOOLSLENECK ELEVATOR F/ 5-1/2 DRILL PIPE','center_latch_elevator','5.5','500',null,null,null,'AOT',null,'45553',null,'62653',null,'10707090-020616-0005418','5','hours'),
	('hoisting','350-TON GG VARCO BJ BOTHOMAS TOOLSLENECK ELEVATOR F/ 5-1/2 DRILL PIPE','center_latch_elevator','5.5','350',null,null,null,'KEYSTONE ENERGY TOOLS','2014-03-12','76179',null,'76179',null,'THOMAS TOOLS NO CCD','5','hours'),
	('hoisting','Elevator  Center Latch  Type AA for 5-1/2 Casing 350 Ton  Square Shoulder ','center_latch_elevator','5.5','350',null,null,null,'CANAM','2017-03-30','38348',null,'28940K',null,'10707090-190517-0005987',null,'hours'),
	('make_up','DIE CLINCHER 8.625 IN X 5.500 IN ','tong_backup_jaw_die','5.5',null,'29000',null,null,'MCCOY',null,null,null,'33770K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE CLINCHER 8.625 IN X 5.500 IN ','tong_backup_jaw_die','5.5',null,'29000',null,null,'MCCOY',null,null,null,'33771K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE CLINCHER 8.625 IN X 5.500 IN','tong_backup_jaw_die','5.5',null,'29000',null,null,'MCCOY',null,null,null,'33772K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE CLINCHER 8.625 IN X 5.500 IN','tong_backup_jaw_die','5.5',null,'29000',null,null,'MCCOY',null,null,null,'33773K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE CLINCHER 8.625 IN X 5.500 IN','tong_backup_jaw_die','5.5',null,'29000',null,null,'MCCOY',null,null,null,'33774K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE CLINCHER 8.625 IN X 5.500 IN ','tong_backup_jaw_die','5.5',null,'29000',null,null,'MCCOY',null,null,null,'33775K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-140/ 5.5 JAW DIE KIT KT8625 HT ','tong_jaw_set','5.5',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-140','31983K',null,'10707090-290817-0011751','1','hours'),
	('make_up','5.50 JAW DIE KIT KT 7585  PN 1050-JDK-140-S ','tong_jaw_set','5.5',null,'29000',null,null,'MCCOY',null,null,'1050-JDK-140-S ','40728K',null,'10707090-031218-0014063','1','hours'),
	('make_up','5.50 JAW DIE KIT KT 7585  PN 1050-JDK-140-S ','tong_jaw_set','5.5',null,'29000',null,null,'MCCOY',null,null,'1050-JDK-140-S ','40729K',null,'10707090-031218-0014063','1','hours'),
	('gripping','8 5/8 100 API Spider','bowl','8.63','100',null,null,null,'AOT','2010-10-22','101353',null,'61684HA',null,null,'2','hours'),
	('gripping','E/175 5.1/2x5.1/2 Slip Assy ','pneumatic_tubing_spider','5.5','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 5.1/2X5.1/2','10707090-240818-0010101','1','hours'),
	('gripping','E/175 5.1/2x5.1/2 Inserts 4 pcs/set','pneumatic_tubing_spider','5.5','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 5.1/2X5.1/2 IN ','10707090-240818-0010101','1','hours'),
	('make_up','8625-JDK-140/ 5.5 JAW DIE KIT KT8625 HT ','tong_jaw_set','5.5',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-140','31984K',null,'10707090-290817-0011751','1','hours'),
	('other','thread_protector 5 1/2','thread_protector','5.5',null,null,null,null,'MCCOY',null,null,null,null,null,null,'1','hours'),
	('other','thread_protector 5 1/2','thread_protector','5.5',null,null,null,null,'MCCOY',null,null,null,null,null,null,'1','hours'),
	('other','thread_protector 5 1/2','thread_protector','5.5',null,null,null,null,'MCCOY',null,null,null,null,null,null,'1','hours'),
	('hoisting','SJ elevator 5 1/2','single_joint_elevator','5.5','5',null,null,null,'JSPM','2018-06-26','180602',null,'39891K',null,'10707090-240818-0010101','1','hours'),
	('hoisting','TYPE SMX 150T SD DR ELEVATOR 5-1/2','side_door_elevator','5.5','150',null,null,null,'NOV','2012-11-06','NL0146790',null,'28925K','50006430Y132','10707090-050517-0005232','1','hours'),
	('hoisting','Slips for MYC elevator 5 1/2  set','slip_type_elevator','5.5','200',null,null,null,'BVM',null,'150108',null,null,null,null,'1','hours'),
	('gripping',' 5-1/2 ROTARY SLIP RATED FOR 75D-TONS  AOT TYPE RSDU-LONG COMPLETE w/INSERTS ','manual_slips','5.5',null,null,null,null,'AOT','2001-11-21','20448',null,'56928',null,'10707090-020616-0005418','1','hours'),
	('gripping','ROTARY SLIP DU 5.500 LG W/ FLEX HANDLESS','manual_slips','5.5',null,null,null,null,'DRECO MIDDLE EAST',null,'229620-1',null,'16776K','NPN/01','10707090-010316-0001798','1','hours'),
	('gripping','5-1/2 ROTARY SLIP  AOT TYPE DU-LONG COMPLETE W/ 5-1/2 INSERTS','manual_slips','5.5',null,null,null,null,'FORUM ENERGY','2013-09-04','211443-1',null,'85914',null,'10707090-310516-0005285','1','hours'),
	('gripping','SDXL ROTARY SLIP FOR 5-1/2 X 5-1/2','manual_slips','5.5',null,null,null,null,'BVM','2013-01-30','26544-3',null,'55483J','15519','10216020-040313-0004435','1','hours'),
	('hoisting','side_door_elevator 5 1/2 250t SLX 250','side_door_elevator','5.5','250',null,null,null,'JSPM','2018-06-26','180609',null,'39887K',null,'10707090-240818-0010101','2','hours'),
	('hoisting','Elevator  C/L Type TA 100 Ton for 5-1/2 Casing','center_latch_elevator','5.5','100',null,null,null,'BVM','2010-10-12',null,null,'43767H',null,'from 4','2','hours'),
	('make_up','5.50 JAW DIE KIT KT7585','tong_jaw_set','5.5',null,null,null,null,'MCCOY',null,null,'1050-JDK-140-S',null,null,null,'2','hours'),
	('make_up','5.50 JAW DIE KIT KT7585','tong_jaw_set','5.5',null,null,null,null,'MCCOY',null,null,'1050-JDK-140-S',null,null,null,'2','hours'),
	('make_up','DIE CLINCHER 8.625 IN * 5.500 IN','tong_backup_jaw_set','5.5',null,null,null,null,'MCCOY',null,null,'BUC86255500',null,null,null,'2','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 5.000 IN','tong_backup_jaw_die','5',null,'29000',null,null,'MCCOY',null,null,null,'33389K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 5.000 IN ','tong_backup_jaw_die','5',null,'29000',null,null,'MCCOY',null,null,null,'33390K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 5.000 IN ','tong_backup_jaw_die','5',null,'29000',null,null,'MCCOY',null,null,null,'33766K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 5.000 IN ','tong_backup_jaw_die','5',null,'29000',null,null,'MCCOY',null,null,null,'33767K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 5.000 IN OD ','tong_backup_jaw_die','5',null,'29000',null,null,'MCCOY',null,null,null,'33768K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 5.000 IN OD ','tong_backup_jaw_die','5',null,'29000',null,null,'MCCOY',null,null,null,'33769K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-135/ ASSEMBLY  5.000 JAW DIE KIT  8625-35K ','tong_jaw_set','5',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-135','31981K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-135/ ASSEMBLY  5.000 JAW DIE KIT  8625-35K ','tong_jaw_set','5',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-135','31982K',null,'10707090-290817-0011751','1','hours'),
	('gripping','E/175 5.1/2x5 Inserts 4 pcs/set','pneumatic_tubing_spider','5','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 5.1/2X5','10707090-240818-0010101','1','hours'),
	('hoisting','TA elevator TA/150 ton for 5” Drill pipe  Drill pipe elevator TA 5/150T IEU','center_latch_elevator','5','150',null,null,null,'JIANGSU RUTONG',null,'60515',null,'31664K',null,'10707090-210717-0009704','1','hours'),
	('gripping','Drill Pipe Slip Type SDML 5 x 5  SDML 5×5','manual_slips','5',null,null,null,null,'JIANGSU RUTONG','2018-05-10','60511',null,'38483K',null,'10707090-160718-0008279','1','hours'),
	('gripping','5 SDML W/5 INSERTS','manual_slips','5',null,null,null,null,'NOV','2016-05-17','15569-50',null,'19782K','15569-50','10707090-180616-0006281','1','hours'),
	('make_up','5.00 JAW DIE KIT KT7585','tong_jaw_set','5',null,null,null,null,'MCCOY',null,null,'1050-JDK-135',null,null,null,'2','hours'),
	('make_up','DIE CLINCHER 8.625 IN * 5.000 IN','tong_backup_jaw_set','5',null,null,null,null,'MCCOY',null,null,'BUC86255000',null,null,null,'2','hours'),
	('make_up','8625-JDK-133 / ASSEMBLY  4.875 JAW DIE KIT  8625-35K ','tong_jaw_set','4.88',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-133','32056K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86254875 / DIE CLINCHER 8.625 IN X 4.875 IN','tong_backup_jaw_die','4.88',null,'29000',null,null,'MCCOY',null,null,'BUC86254875','32063K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86254875 / DIE CLINCHER 8.625 IN X 4.875 IN ','tong_backup_jaw_die','4.88',null,'29000',null,null,'MCCOY',null,null,'BUC86254875','32066K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86254875 / DIE CLINCHER 8.625 IN X 4.875 IN','tong_backup_jaw_die','4.88',null,'29000',null,null,'MCCOY',null,null,'BUC86254875','32067K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-132 / ASSEMBLY  4.750 JAW DIE KIT  8625-35K ','tong_jaw_set','4.75',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-132','32055K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86254750 / DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 4.750 IN OD','tong_backup_jaw_die','4.75',null,'29000',null,null,'MCCOY',null,null,'BUC86254750','32060K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86254750 / DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 4.750 IN OD','tong_backup_jaw_die','4.75',null,'29000',null,null,'MCCOY',null,null,'BUC86254750','32061K',null,'10707090-290817-0011751','1','hours'),
	('make_up','BUC86254750 / DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 4.750 IN OD','tong_backup_jaw_die','4.75',null,'29000',null,null,'MCCOY',null,null,'BUC86254750','32062K',null,'10707090-290817-0011751','1','hours'),
	('gripping','safety_clamp 4','safety_clamp','4.63',null,null,null,null,'JSPM','2018-06-26','180607',null,'39866K',null,'10707090-240818-0010101','2','hours'),
	('gripping','safety_clamp 4 1/2','safety_clamp','4.5',null,null,null,null,'JSPM','2018-06-26','180608',null,'39865K',null,'10707090-240818-0010101',null,'hours'),
	('gripping','E/175 5.1/2x4.1/2 Inserts 4 pcs/set','pneumatic_tubing_spider','4.5','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 5.1/2X4.1/2 ','10707090-240818-0010101','1','hours'),
	('make_up','DIE CLINCHER 8.625 IN X 4.500 IN ','tong_backup_jaw_die','4.5',null,'29000',null,null,'MCCOY',null,null,null,'33396K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE CLINCHER 8.625 IN X 4.500 IN','tong_backup_jaw_die','4.5',null,'29000',null,null,'MCCOY',null,null,null,'33384K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE CLINCHER 8.625 IN X 4.500 IN','tong_backup_jaw_die','4.5',null,'29000',null,null,'MCCOY',null,null,null,'33385K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE CLINCHER 8.625 IN X 4.500 IN ','tong_backup_jaw_die','4.5',null,'29000',null,null,'MCCOY',null,null,null,'33386K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE CLINCHER 8.625 IN X 4.500 IN','tong_backup_jaw_die','4.5',null,'29000',null,null,'MCCOY',null,null,null,'33387K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE CLINCHER 8.625 IN X 4.500 IN ','tong_backup_jaw_die','4.5',null,'29000',null,null,'MCCOY',null,null,null,'33388K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-130 /4.50 JAW DIE KIT KT8625 HT ','tong_jaw_set','4.5',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-130','31979K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-130 /4.50 JAW DIE KIT KT8625 HT ','tong_jaw_set','4.5',null,'29000',null,null,'MCCOY',null,null,'8625-JDK-130','31980K',null,'10707090-290817-0011751','1','hours'),
	('hoisting','side_door_elevator 4 1/2 250t','side_door_elevator','4.5','250',null,null,null,'JSPM','2018-06-26','180608',null,'39888K',null,'10707090-240818-0010101','1','hours'),
	('hoisting','SJ elevator 4 1/2','single_joint_elevator','4.5','5',null,null,null,'JSPM','2018-06-26','180604',null,'39892K',null,'10707090-240818-0010101','1','hours'),
	('hoisting','Slips for MYC elevator 4 1/2  set','slip_type_elevator','4.5','200',null,null,null,'BVM',null,'30214',null,null,null,null,'1','hours'),
	('hoisting','side_door_elevator 4 1/2 250t','side_door_elevator','4.5','250',null,null,null,'JSPM','2018-06-26',null,null,'39889K',null,'10707090-240818-0010101','2','hours'),
	('gripping','BAASH-ROSS TYPE T safety_clamp COMPLETE W/ 6 SEGMENTS & WRENCH','safety_clamp','4.5',null,null,null,null,'FORUM','2011-03-16','106296',null,'78185',null,'10707090-020616-0005418','2','hours'),
	('make_up','4.50 JAW DIE KIT KT7585','tong_jaw_set','4.5',null,null,null,null,'MCCOY',null,null,'1050-JDK-130',null,null,null,'2','hours'),
	('make_up','DIE CLINCHER 8.625 IN * 4.500 IN','tong_backup_jaw_set','4.5',null,null,null,null,'MCCOY',null,null,'BUC86254500',null,null,null,'2','hours'),
	('other','stabbing_guide 4 1/2','stabbing_guide','4.5',null,null,null,null,'JSPM','2018-06-26',null,null,'39869K',null,'10707090-160718-0008279','2','hours'),
	('other','thread_protector 4 1/2','thread_protector','4.5',null,null,null,null,'JSPM','2018-06-26',null,null,'39875K',null,'10707090-160718-0008279','2','hours'),
	('other','thread_protector 4 1/2','thread_protector','4.5',null,null,null,null,'JSPM','2018-06-26',null,null,'39876K',null,'10707090-160718-0008279','2','hours'),
	('other','thread_protector 4 1/2','thread_protector','4.5',null,null,null,null,'JSPM','2018-06-26',null,null,'39877K',null,'10707090-160718-0008279','2','hours'),
	('make_up','Tongs Jaws complete with inserts  for HD8625 tong  to run 4” tubing','tong_jaw_set','4',null,null,null,null,'MCCOY',null,null,'8625-JDK-120',null,'8625-JDK-120','10707090-070918-0010624','1','hours'),
	('make_up','Tongs Jaws complete with inserts  for HD8625 tong  to run 4” tubing','tong_jaw_set','4',null,null,null,null,'MCCOY',null,null,'8625-JDK-120',null,'8625-JDK-120','10707090-070918-0010624','1','hours'),
	('make_up','Clincher style Backup tongs dies to run 4” tubing','tong_backup_jaw_set','4',null,null,null,null,'MCCOY',null,null,'BUC86254000',null,'BUC86254000','10707090-070918-0010624','1','hours'),
	('make_up','Clincher style Backup tongs dies to run 4” tubing','tong_backup_jaw_set','4',null,null,null,null,'MCCOY',null,null,'BUC86254000',null,'BUC86254000','10707090-070918-0010624','1','hours'),
	('gripping','E/175 5.1/2x4 Inserts 4 pcs/set ','pneumatic_tubing_spider','4','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 5.1/2X4 ','10707090-240818-0010101','1','hours'),
	('hoisting','side_door_elevator SLX 4 - 100','side_door_elevator','4','100',null,null,null,'WELONG','2018-07-04','4181047',null,'40059K',null,'10702070-031018-0147220','1','hours'),
	('hoisting','side_door_elevator SLX 4 - 100','side_door_elevator','4','100',null,null,null,'WELONG','2018-07-04','4181048',null,'40060K',null,'10702070-031018-0147220','1','hours'),
	('hoisting','SJ elevator 4','single_joint_elevator','4','5',null,null,null,'JSPM','2018-06-26','180606',null,'39859K',null,'10707090-240818-0010101','2','hours'),
	('make_up','4.00 JAW DIE KIT KT7585','tong_jaw_set','4',null,null,null,null,'MCCOY',null,null,'1050-JDK-120',null,null,null,'2','hours'),
	('make_up','DIE CLINCHER 8.625 IN * 4.000 IN','tong_backup_jaw_set','4',null,null,null,null,'MCCOY',null,null,'BUC86254000',null,null,null,'2','hours'),
	('other','stabbing_guide 4','stabbing_guide','4',null,null,null,null,'JSPM','2018-06-26',null,null,'39870K',null,'10707090-160718-0008279','2','hours'),
	('other','stabbing_guide 4','stabbing_guide','4',null,null,null,null,'JSPM','2018-06-26',null,null,'39871K',null,'10707090-160718-0008279','2','hours'),
	('other','thread_protector 4','thread_protector','4',null,null,null,null,'JSPM','2018-06-26',null,null,'39878K',null,'10707090-160718-0008279','2','hours'),
	('other','thread_protector 4','thread_protector','4',null,null,null,null,'JSPM','2018-06-26',null,null,'39879K',null,'10707090-160718-0008279','2','hours'),
	('other','thread_protector 4','thread_protector','4',null,null,null,null,'JSPM','2018-06-26',null,null,'39880K',null,'10707090-160718-0008279','2','hours'),
	('hoisting','250-TON MGG BOTHOMAS TOOLSLENECK ELEVATOR F/ 3-1/2 DRILL PIPE','center_latch_elevator','3.5','250',null,null,null,'AOT','2006-09-01','39685',null,'62052',null,'THOMAS TOOLS NO CCD','5','hours'),
	('other','02-E0572 / thread_protector  PRO-TECH  NON-INFLATABLE  3-1/2','thread_protector','3.5',null,null,null,null,'MCCOY',null,null,'02-E0572','31669K',null,'10707090-240717-0009837','1','hours'),
	('other','02-E0572 / thread_protector  PRO-TECH  NON-INFLATABLE  3-1/2','thread_protector','3.5',null,null,null,null,'MCCOY',null,null,'02-E0572','31670K',null,'10707090-240717-0009837','1','hours'),
	('gripping','E/175 3.1/2x3.1/2 Slip Assy ','pneumatic_tubing_spider','3.5','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 3.1/2X3.1/2 ','10707090-240818-0010101','1','hours'),
	('gripping','E/175 3.1/2x3.1/2 Slip Assy ','pneumatic_tubing_spider','3.5','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 3.1/2X3.1/2 ','10707090-240818-0010101','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 3.500 IN OD','tong_backup_jaw_die','3.5',null,'21000',null,null,'MCCOY',null,null,null,'33378K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 3.500 IN OD','tong_backup_jaw_die','3.5',null,'21000',null,null,'MCCOY',null,null,null,'33379K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 3.500 IN OD','tong_backup_jaw_die','3.5',null,'21000',null,null,'MCCOY',null,null,null,'33380K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 3.500 IN OD','tong_backup_jaw_die','3.5',null,'21000',null,null,'MCCOY',null,null,null,'33381K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 3.500 IN OD','tong_backup_jaw_die','3.5',null,'21000',null,null,'MCCOY',null,null,null,'33382K',null,'10707090-290817-0011751','1','hours'),
	('make_up','DIE  WRAP AROUND  FINE TOOTH  8.625 IN X 3.500 IN OD ','tong_backup_jaw_die','3.5',null,'21000',null,null,'MCCOY',null,null,null,'33383K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-115/3.50 JAW DIE KIT KT8625 HT ','tong_jaw_set','3.5',null,'21000',null,null,'MCCOY',null,null,'8625-JDK-115','31977K',null,'10707090-290817-0011751','1','hours'),
	('make_up','8625-JDK-115/3.50 JAW DIE KIT KT8625 HT ','tong_jaw_set','3.5',null,'21000',null,null,'MCCOY',null,null,'8625-JDK-115','31978K',null,'10707090-290817-0011751','1','hours'),
	('hoisting','SJ elevator 3 1/2','single_joint_elevator','3.5','5',null,null,null,'JSPM','2018-06-26','180605',null,'39860K',null,'10707090-240818-0010101','2','hours'),
	('hoisting','TMA-100 TONELEV.FOR 3-1/2  C/W CERT  50006310Y162','center_latch_elevator','3.5','100',null,null,null,'NOV',null,null,null,'82046JA','50006310Y162','from 4','2','hours'),
	('hoisting','ELEVATOR  CENTERLATCH - 3-1/2 ID','center_latch_elevator','3.5','100',null,null,null,'BVM',null,null,null,'55455JA',null,'from 4','2','hours'),
	('make_up','3-1/2 JAW DIE KIT FOR KT8625/ 3-1/2 Набор челюстей для KT8625','tong_jaw_set','3.5',null,null,null,null,'MCCOY',null,null,null,null,'1050-JDK-115','from 4','2','hours'),
	('gripping','Drill pipe slips type SDML 3.1/2×3.1/2  SDML 3.1/2×3.1/2  PN000103003','manual_slips','3.5',null,null,null,null,'JIANGSU RUTONG','2017-06-19','70312',null,'29754K',null,'10707090-210717-0009704','2','hours'),
	('gripping','4-1/2 ROTARY SLIP  B.R. TYPE DU-LONG COMPLETE W/ 3-1/2 INSERTS','manual_slips','3.5',null,null,null,null,'AOT','2013-10-23','212678',null,'86062',null,'10707090-020616-0005418','2','hours'),
	('hoisting','Elevator  C/L Type RA 125 Ton for 3-1/2 NUE tubing Square Shouldered to ','center_latch_elevator','3.5','125',null,null,null,'BVM','2010-10-12',null,null,'43724H',null,null,'2','hours'),
	('make_up','3.50 JAW DIE KIT KT7585','tong_jaw_set','3.5',null,null,null,null,'MCCOY',null,null,'1050-JDK-115',null,null,null,'2','hours'),
	('make_up','DIE CLINCHER 8.625 IN * 3.500 IN','tong_backup_jaw_set','3.5',null,null,null,null,'MCCOY',null,null,'BUC86253500',null,null,null,'2','hours'),
	('other','stabbing_guide 3 1/2','stabbing_guide','3.5',null,null,null,null,'JSPM','2018-06-26',null,null,'39872K',null,'10707090-160718-0008279','2','hours'),
	('other','API drift 3 1/2 #15/5ppf DP','drift','3.5',null,null,null,null,null,null,null,null,'29336K',null,null,'2','meters'),
	('other','API drift 3 1/2 #15/5ppf DP','drift','3.5',null,null,null,null,null,null,null,null,'29337K',null,null,'2','meters'),
	('other','API drift  88 9 х 6 45 72 82 х 1067','drift','3.5',null,null,null,null,null,null,'TRS022006',null,null,null,null,'2','meters'),
	('gripping','SDML ROTARY SLIP FOR 3-1/2 X 3-1/2','manual_slips','3.5',null,null,null,null,'BVM',null,'29427-1A или 29426-S2',null,'55463JA','15523','10216020-040313-0004435','2','hours'),
	('gripping','safety_clamp 2 7/8','safety_clamp','3.25',null,null,null,null,'JSPM','2018-06-26','180612',null,'39867K',null,'10707090-240818-0010101','1','hours'),
	('make_up','Tongs Jaws complete with inserts  for HD8625 tong  to run 2 7/8” tubing','tong_jaw_set','2.88',null,null,null,null,'MCCOY',null,null,'8625-JDK-110',null,'8625-JDK-110','10707090-070918-0010624','1','hours'),
	('make_up','Tongs Jaws complete with inserts  for HD8625 tong  to run 2 7/8” tubing','tong_jaw_set','2.88',null,null,null,null,'MCCOY',null,null,'8625-JDK-110',null,'8625-JDK-110','10707090-070918-0010624','1','hours'),
	('make_up','Clincher style Backup tongs dies to run 2 7/8” tubing','tong_backup_jaw_set','2.88',null,null,null,null,'MCCOY',null,null,'BUC86252875',null,'BUC86252875','10707090-070918-0010624','1','hours'),
	('make_up','Clincher style Backup tongs dies to run 2 7/8” tubing','tong_backup_jaw_set','2.88',null,null,null,null,'MCCOY',null,null,'BUC86252875',null,'BUC86252875','10707090-070918-0010624','1','hours'),
	('gripping','E/175 3.1/2x2.7/8 Inserts 4 pcs/set ','pneumatic_tubing_spider','2.88','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 3.1/2X2.7/8','10707090-240818-0010101','1','hours'),
	('gripping','E/175 3.1/2x2.7/8 Inserts 4 pcs/set ','pneumatic_tubing_spider','2.88','175',null,null,null,'JSPM','2018-06-26',null,null,null,'E/175 3.1/2X2.7/8','10707090-240818-0010101','1','hours'),
	('hoisting','TMA-100 TON ELEV F/2-7/8 PLAIN TUBING  C/W CERT','center_latch_elevator','2.88','100',null,null,null,'NOV','2016-05-18','NL17123376',null,'19020K',null,'10707090-060616-0005559','2','hours'),
	('hoisting','center_latch_elevator 2 7/8 DD 2 7/8 - 150','center_latch_elevator','2.88','150',null,null,null,'WELONG','2018-07-04','4181040',null,'40058K',null,'10702070-031018-0147220','2','hours'),
	('hoisting','SJ elevator 2 7/8','single_joint_elevator','2.88','5',null,null,null,'JSPM','2018-06-26','180601',null,'39861K',null,'10707090-240818-0010101','2','hours'),
	('make_up','2.875 JAW DIE KIT KT7585','tong_jaw_set','2.88',null,null,null,null,'MCCOY',null,null,'1050-JDK-110',null,null,null,'2','hours'),
	('make_up','DIE CLINCHER 8.625 IN * 2.875 IN','tong_backup_jaw_set','2.88',null,null,null,null,'MCCOY',null,null,'BUC86252875',null,null,null,'2','hours'),
	('other','stabbing_guide 2 7/8','stabbing_guide','2.88',null,null,null,null,'JSPM','2018-06-26',null,null,'39873K',null,'10707090-160718-0008279','2','hours'),
	('other','thread_protector 2 7/8','thread_protector','2.88',null,null,null,null,'JSPM','2018-06-26',null,null,'39881K',null,'10707090-160718-0008279','2','hours'),
	('other','API drift 73 02 х 5 51 59 62 х 1067','drift','2.88',null,null,null,null,null,null,'TRS022005',null,null,null,null,'2','meters'),
	('other','API drift 73 02 х 7 01 56 62 х 1067','drift','2.88',null,null,null,null,null,null,'TRS022004',null,null,null,null,'6','meters'),
	('make_up','2.375 JAW DIE KIT KT7585','tong_jaw_set','2.38',null,null,null,null,'MCCOY',null,null,'1050-JDK-105',null,null,null,'2','hours'),
	('make_up','DIE CLINCHER 8.625 IN * 2.375 IN','tong_backup_jaw_set','2.38',null,null,null,null,'MCCOY',null,null,'BUC86252375',null,null,null,'2','hours'),
	('other', '20ft container', 'container', null,null,null,null,null,null,null,'PTLU7770042',null,null,null,null,'2','hours'),
	('other', '20ft container', 'container', null,null,null,null,null,null,null,'TCLU3737875',null,null,null,null,'2','hours');
	;

INSERT into shipments 	(origin_id,	destination_id,	shipment_date) values
						(1,				2,			'2020-03-18'),
						(1,				2,			'2020-03-20'),
						(1,				2,			'2020-03-20'),
						(1,				2,			'2020-03-27'),
						(1,				2,			'2020-03-31'),
						(1,				2,			'2020-04-24'),
						(1,				2,			'2020-06-25'),		
						(1,				2,			'2020-08-26'),
						(1,				3,			'2020-09-24'),
						(1,				4,			'2020-06-17');		

INSERT INTO shipments_assets VALUES (1,629),(1,85),(1,56),(1,86),(1,87),(1,141),(1,142),(1,230),(1,229),(1,333),(1,328),(1,143),(1,144),(1,228),(1,227),(1,331),(1,332),(1,367),(1,362),(1,368),(1,146),(1,145),(1,232),(1,280),(1,334),(1,231),(1,337),(1,329),(1,147),(1,148),(1,234),(1,235),(1,199),(1,287),(1,288),(1,480),(1,467),(1,29),(1,137),(1,138),(1,349),(1,350),(1,351),(1,149),(1,243),(1,242),(1,348),(1,349),(1,346),(1,238),(1,239),(1,240),(1,65),(1,76),(1,66),(1,137),(1,138),(2,138),(2,24),(2,22),(2,19),(2,23),(2,3),(2,188),(2,189),(3,630),(3,466),(3,619),(3,599),(3,618),(3,603),(3,67),(3,597),(3,598),(3,562),(3,470),(3,395),(3,465),(3,468),(3,620),(3,601),(3,68),(3,28),(3,585),(3,586),(3,624),(3,474),(3,27),(3,64),(3,361),(3,602),(3,506),(3,610);

INSERT into jobs_tubulars 	(job_id,	tubular_id,	meterage,	qty) values
							(1,			1,			121,		11);

INSERT into	jobs_hands 	(job_id,	hands_GIN,	is_supervisor,	shift) values
						(1,			04573788,	true,			'days'),
						(1,			4463097,	false,			'days'),
						(1,			6005062,	false,			'days');

INSERT INTO jobs_assets VALUES (1,367,8),(1,362,8),(1,142,9),(1,147,4),(1,149,1),(1,66,9),(1,138,8),(1,146,8);

delimiter //
drop procedure if exists show_asset// -- вывод информации о конкретной единице оборудования по номеру
create procedure show_asset (in FMS varchar(255))
begin
	select 'ID' as Параметр, id as Значение from assets a where FMS_sn =FMS
	union
	SELECT 'FMS номер' as Параметр, FMS_sn as Значение from assets a2 where FMS_sn=FMS
	union
	SELECT 'Заводской серийный номер' as Параметр, OEM_sn as Значение from assets a2 where FMS_sn=FMS
	union
	SELECT 'Описание' as Параметр, description as Значение from assets a2 where FMS_sn=FMS
	union
	SELECT 'Текущее местоположение' as Параметр, (select name from locations where id = (select location_id from assets a2 where FMS_sn =FMS)) as Значение 
 	union
	SELECT 
		'Дата последнего перемещения' as Параметр,
		date((select shipment_date from shipments where id = 
			(select shipment_id from shipments_assets where asset_id =
				(select id from assets where FMS_sn =FMS)) order by shipment_date desc limit 1)) as Значение 
	union
 	SELECT 
 		CONCAT_WS(', ','Текущая наработка / Накопленная наработка',(select utilization_unit from assets a2 where FMS_sn=FMS)) as Параметр, 
 		CONCAT_WS(' / ',
 			(select utilization_current from assets a2 where FMS_sn=FMS),
 			(select utilization_accumulated from assets a2 where FMS_sn=FMS)
 			) as Значение from assets a2 
	union
	SELECT 
		'Дата последнего применения на работе' as Параметр,
		date((select end_date from jobs where id = 
			(select job_id from jobs_assets where asset_id =
				(select id from assets where FMS_sn =FMS)) order by end_date desc limit 1)) as Значение; 
end //
delimiter ;

CALL show_asset('38468K'); -- примеры вызова процедуры
CALL show_asset('19297J');
 
drop view if exists base_assets; -- представление о оборудовании находящемся на основной базе на данный момент
create view base_assets as select id, `type` , description, FMS_sn, OEM_sn from assets where location_id = 1;
select * from base_assets;

drop view if exists complete_active_inventory; -- полный перечень оборудования на всех активных локациях
create view complete_active_inventory as select
	a.id, `type` , description, FMS_sn, OEM_sn, utilization_unit, utilization_accumulated, l.name as Локация from assets a
	left join locations l on a.location_id = l.id 
	where l.is_active = 1
	order by `type`;
select * from complete_active_inventory;

select `type`, Локация, count(*) as 'Количество, шт' from complete_active_inventory group by `type`, Локация order by `type`; -- запрос на количество разных типов (группировка)