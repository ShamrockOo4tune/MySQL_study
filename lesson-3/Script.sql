drop database if exists snet2008;
CREATE database snet2008;
use snet2008;

drop table if exists users;
CREATE table users(
    id serial primary key, -- serial = bigint unsigned not null auto_increment unique
    email varchar(150) unique,
    pass varchar(100),
    name varchar(50) not null, 
    surname varchar(50),
    phone varchar(20),
    gender char(1),
    birthday date,
    hometown varchar(100),
    photo_id bigint unsigned,
    created_at datetime default now(),
    key(phone),
    key(name, surname)
);

drop table if exists settings;
create table settings(
    user_id serial primary key,
    can_see enum('all', 'friends_of_friends', 'friends'),
    can_comment enum('all', 'friends_of_friends', 'friends', 'nobody'),
    can_message enum('all', 'friends_of_friends', 'friends'),
    foreign key (user_id) references users(id)
);

drop table if exists messages;
CREATE table messages(
    id serial primary key,
    from_user_id bigint unsigned not null,
    to_user_id bigint unsigned not null,
    body text,
    is_read bool default 0,
    created_at datetime default current_timestamp,
    foreign key (from_user_id) references users(id),
    foreign key (to_user_id) references users(id)
);
    
drop table if exists friend_requests;
create table friend_requests(
	initiator_user_id bigint unsigned not null,
	target_user_id  bigint unsigned not null,
	status ENUM('requested', 'approved', 'unfriended', 'declined') default 'requested',
	requested_at datetime default now(),
	confirmed_at datetime, -- TODO выставлять время на UPDATE
	primary key (initiator_user_id, target_user_id),
	foreign key (initiator_user_id) references users(id),
	foreign key (target_user_id) references users(id),
	index(initiator_user_id),
	index(target_user_id)
);

drop table if exists communities;
create table communities(
	id serial,
	name varchar(255) not null,
	primary key (id),
	index(name)
);

drop table if exists users_communities;
create table users_communities(
	user_id bigint unsigned not null,
	community_id bigint unsigned not null,
	is_admin bool default 0,
	primary key (user_id, community_id),
	foreign key (user_id) references users(id),
	foreign key (community_id) references communities(id)
);

drop table if exists posts;
create table posts(
	id serial primary key,
	user_id bigint unsigned not null,
	body text,
	created_at datetime default current_timestamp,
	updated_at datetime,
	foreign key (user_id) references users(id),
	index(user_id)
);

drop table if exists comments;
create table comments(
	id serial primary key,
	user_id bigint unsigned not null,
	post_id bigint unsigned not null,
	body text, 
	created_at datetime default current_timestamp,
	foreign key (user_id) references users(id),
	foreign key (post_id) references posts(id),

	-- dlya realizacii drevovidnoy strukturi kommentariev tak mozhno?:
	parent_comment_id bigint unsigned default null -- null - znachit ne yavlaetsa kommentom na drugoi komment 
);

drop table if exists photos;
create table photos(
	id serial primary key,
	user_id bigint unsigned not null,
	description varchar(255),
	created_at datetime default current_timestamp,
	foreign key (user_id) references users(id),
	index(user_id)
);

DROP  table if exists photos_likes;
create table photos_likes(
    user_id bigint unsigned not null, -- tot kto stavit 'like'
    foreign key (user_id) references users(id),
    target_media_id bigint unsigned not null,
    foreign key (target_media_id) references photos(id),
    primary key (user_id, target_media_id)
);

DROP  table if exists posts_likes;
create table posts_likes(
    user_id bigint unsigned not null, -- tot kto stavit 'like'
    foreign key (user_id) references users(id),
    target_post_id bigint unsigned not null,
    foreign key (target_post_id) references posts(id),
    primary key (user_id, target_post_id)
);

DROP  table if exists users_likes;
create table users_likes(
    user_id bigint unsigned not null, -- tot kto stavit 'like'
    foreign key (user_id) references users(id),
    target_user_id bigint unsigned not null, -- tot komu stavitsa 'like'
    foreign key (target_user_id) references users(id),
    primary key (user_id, target_user_id)
);    



    
    