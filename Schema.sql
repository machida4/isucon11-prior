CREATE TABLE `reservations`
(
  `id` varchar(255) NOT NULL,
  `schedule_id` varchar(255) NOT NULL,
  `user_id` varchar(255) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `schedules`
(
  `id` varchar(255) NOT NULL,
  `title` varchar(255) NOT NULL DEFAULT '',
  `capacity` int unsigned NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `users`
(
  `id` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL DEFAULT '',
  `nickname` varchar(120) NOT NULL DEFAULT '',
  `staff` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`)
);

