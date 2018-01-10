#NOTE: Before submitting, run in Linux and check for dashes and capitalization

/*******************Create Tables************************/
drop database if exists s0goff01_CECSProject;
CREATE database s0goff01_CECSProject;
use s0goff01_CECSProject;

CREATE TABLE IF NOT EXISTS `s0goff01_CECSProject`.`customer` (
  `cust_id` INT NOT NULL,
  `name` VARCHAR(45) NULL,
  `street` VARCHAR(45) NULL,
  `city` VARCHAR(45) NULL,
  `zip` INT NULL,
  `status` VARCHAR(45) NULL,
  PRIMARY KEY (`cust_id`)
  );

CREATE TABLE IF NOT EXISTS `s0goff01_CECSProject`.`room` (
  `type` VARCHAR(45) NOT NULL,
  `occupancy` INT NOT NULL,
  `number_beds` INT NULL,
  `type_beds` VARCHAR(45) NULL,
  `price` INT UNSIGNED NULL,
  PRIMARY KEY (`type`)
  );

CREATE TABLE IF NOT EXISTS `s0goff01_CECSProject`.`hotel` (
  `hotelid` INT NOT NULL,
  `number` INT NULL,
  `street` VARCHAR(45) NULL,
  `city` VARCHAR(45) NULL,
  `zip` INT NULL,
  `manager_name` VARCHAR(45) NULL,
  `number_rooms` INT NULL,
  `pool?` TINYINT NULL,
  `bar?` TINYINT NULL,
  `restaurant?` TINYINT NULL,
  PRIMARY KEY (`hotelid`)
  );

CREATE TABLE IF NOT EXISTS `s0goff01_CECSProject`.`has` (
  `hotelid` INT NOT NULL,
  `room_type` VARCHAR(45) NOT NULL,
  `number` INT NOT NULL,
  PRIMARY KEY (`hotelid`, `room_type`, `number`),
  FOREIGN KEY (`hotelid`) REFERENCES `s0goff01_CECSProject`.`hotel` (`hotelid`),
  FOREIGN KEY (`room_type`) REFERENCES `s0goff01_CECSProject`.`room` (`type`)
  );

CREATE TABLE IF NOT EXISTS `s0goff01_CECSProject`.`reservation` (
  `hotelid` INT NOT NULL, #NOTE: change back to NOT NULL?
  `cust_id` INT NOT NULL,
  `room_type` VARCHAR(45) NOT NULL,
  `begin_date` DATE NOT NULL,
  `end_date` DATE NOT NULL,
  `credit_card_number` VARCHAR(45) NOT NULL,
  `exp_date` DATE NOT NULL,
  PRIMARY KEY (`credit_card_number`),
  FOREIGN KEY (`hotelid`) REFERENCES `hotel` (`hotelid`),
  FOREIGN KEY (`cust_id`) REFERENCES `s0goff01_CECSProject`.`customer` (`cust_id`),
  FOREIGN KEY (`room_type`) REFERENCES `s0goff01_CECSProject`.`room` (`type`)
  );

CREATE TABLE IF NOT EXISTS `s0goff01_CECSProject`.`alert` (
  `hotelid` INT NOT NULL,
  `room_type` VARCHAR(45) NOT NULL,
  `manager_name` VARCHAR(45) NULL,
  PRIMARY KEY (`hotelid`, `room_type`),
  FOREIGN KEY (`hotelid`) REFERENCES `s0goff01_CECSProject`.`hotel` (`hotelid`),
  FOREIGN KEY (`room_type`) REFERENCES `s0goff01_CECSProject`.`room` (`type`)
  );
  
  CREATE TABLE IF NOT EXISTS `s0goff01_CECSProject`.`revenue` (
  `hotelid` INT NOT NULL,
  `total` INT NOT NULL,
  PRIMARY KEY (`hotelid`),
  FOREIGN KEY (`hotelid`) REFERENCES `s0goff01_CECSProject`.`hotel` (`hotelid`)
  );
  
  CREATE TABLE IF NOT EXISTS `s0goff01_CECSProject`.`temp` (
  `primkey` INT NOT NULL auto_increment,
  `intval` INT NULL,
  `charval` VARCHAR(45) NULL,
  PRIMARY KEY (`primkey`)
  );

/*******************Triggers************************/

DELIMITER $$
CREATE TRIGGER check_occupancy
    BEFORE INSERT ON s0goff01_cecsProject.room
    FOR EACH ROW 
BEGIN
    IF (new.occupancy > 5) 
		THEN SET new.occupancy = NULL;
	ELSEIF (new.occupancy < 1)
		THEN SET new.occupancy = NULL;
	END IF;
END$$


CREATE TRIGGER check_type
    BEFORE INSERT ON room
    FOR EACH ROW 
BEGIN
    IF (new.type != 'regular' && new.type != 'extra' && new.type != 'suite' && new.type != 'business' && new.type != 'luxury' && new.type != 'family') 
		THEN SET new.type = NULL;
	END IF;
END$$


CREATE TRIGGER check_type_beds
    BEFORE INSERT ON s0goff01_cecsProject.room
    FOR EACH ROW 
BEGIN
    IF (new.type_beds != 'full' && new.type_beds != 'queen' && new.type_beds != 'king') 
		THEN SET new.type_beds = NULL;
	END IF;
END$$


CREATE TRIGGER check_num_beds
	BEFORE INSERT ON s0goff01_cecsProject.room
    FOR EACH ROW 
BEGIN
    IF (new.number_beds > 3) 
		THEN SET new.occupancy = NULL;
	ELSEIF (new.number_beds < 1)
		THEN SET new.occupancy = NULL;
	END IF;
END$$


CREATE TRIGGER check_status
    BEFORE INSERT ON s0goff01_cecsProject.customer
    FOR EACH ROW 
BEGIN
    IF (new.status != 'gold' && new.status != 'silver' && new.status != 'business') 
		THEN SET new.status = NULL;
	END IF;
END$$


CREATE TRIGGER check_availability
	BEFORE INSERT ON s0goff01_cecsProject.reservation
    FOR EACH ROW
BEGIN
	SET @total_rooms = (SELECT number FROM has WHERE has.hotelid = new.hotelid and room_type = new.room_type);
    SET @reserved_rooms = (SELECT count(*) #number of existing reservations that overlap with the potential new reservation
						   FROM has, reservation 
                           WHERE has.hotelid = new.hotelid and reservation.hotelid = new.hotelid and has.room_type= new.room_type and reservation.room_type= new.room_type 
							and new.begin_date <= reservation.end_date and new.end_date >= reservation.begin_date); 
    SET @available_rooms = @total_rooms - @reserved_rooms;
    
    INSERT INTO temp(intval, charval) VALUES(@total_rooms, 'total_rooms');
    INSERT INTO temp(intval, charval) VALUES(@reserved_rooms, 'reserved_rooms');
    
    IF(@available_rooms <= 0)
		THEN SET new.hotelid = NULL;
	ELSEIF(@available_rooms = 1)
		THEN SET @manager = (SELECT manager_name FROM hotel WHERE new.hotelid = hotel.hotelid);
        INSERT INTO alert(hotelid, room_type, manager_name) 
        VALUES(new.hotelid, new.room_type, @manager);
    END IF;
    
END$$


CREATE TRIGGER update_revenue
    BEFORE INSERT ON s0goff01_cecsProject.reservation
    FOR EACH ROW 
BEGIN
	DECLARE room_price INT;
    DECLARE num_days INT;
    DECLARE payment INT;
	SET room_price = (SELECT room.price FROM room, reservation WHERE room.type = reservation.room_type and room.type = new.room_type);
    SET num_days = datediff(new.end_date, new.begin_date);
	SET payment = room_price * num_days;
        
    UPDATE revenue
    SET total = total + payment
    WHERE revenue.hotelid = new.hotelid;
END$$


DELIMITER ;

/*******************Insertions************************/

INSERT INTO hotel #hotelid,number,street,city,zip,manager_name,number_rooms,pool?, bar?,restaurant?
VALUES 
(1, 1, 'hotel road', 'hotel city', 46835, 'Jason1', 6, true, true, true), 
(2, 2, 'hotel road', 'hotel city', 46835, 'Jason2', 6, true, true, true), 
(3, 3, 'hotel road', 'hotel city', 46835, 'Jason3', 6, true, true, true), 
(4, 4, 'hotel road', 'hotel city', 46835, 'Jason4', 6, true, true, true), 
(5, 5, 'hotel road', 'hotel city', 46835, 'Jason5', 6, true, true, true);

INSERT INTO room #type,occupancy,number_beds,type_beds,price.
VALUES 
('regular', 2, 1, 'full', 100), 
('extra', 4, 2, 'full', 100), 
('suite', 4, 2, 'queen', 100), 
('business', 1, 1, 'full', 100), 
('luxury', 2, 1, 'king', 100), 
('family', 5, 3, 'full', 100);

INSERT INTO has #hotelid,room_type,number
VALUES 
(1, 'regular', 2),
(2, 'regular', 2), 
(3, 'regular', 2), 
(4, 'regular', 2), 
(5, 'regular', 2),
(1, 'extra', 2),
(2, 'extra', 2), 
(3, 'extra', 2), 
(4, 'extra', 2), 
(5, 'extra', 2),
(1, 'suite', 2),
(2, 'suite', 2), 
(3, 'suite', 2), 
(4, 'suite', 2), 
(5, 'suite', 2),
(1, 'business', 2),
(2, 'business', 2), 
(3, 'business', 2), 
(4, 'business', 2), 
(5, 'business', 2),
(1, 'luxury', 2),
(2, 'luxury', 2), 
(3, 'luxury', 2), 
(4, 'luxury', 2), 
(5, 'luxury', 2),
(1, 'family', 2),
(2, 'family', 2), 
(3, 'family', 2), 
(4, 'family', 2), 
(5, 'family', 2);

INSERT INTO customer #cust_id,name,street,city,zip,status
VALUES 
(1, 'robert', 'custormer lane', 'customer city', '12345', 'gold'), 
(2, 'robby', 'custormer lane', 'customer city', '12345', 'silver'), 
(3, 'rob', 'custormer lane', 'customer city', '12345', 'business'), 
(4, 'bob', 'custormer lane', 'customer city', '12345', 'gold'), 
(5, 'bobby', 'custormer lane', 'customer city', '12345', 'silver');

INSERT INTO reservation #hotelid, cust_id, room_type, begin_date, end_date, credit_card_number, exp_date
VALUES 
(1, 1, 'family', '2017-05-02', '2017-05-06', '0000-0000-0000-0001', '2020-05-04'), 
(2, 2, 'luxury', '2017-05-02', '2017-05-06', '0000-0000-0000-0002', '2020-05-04'), 
(3, 3, 'business', '2017-05-02', '2017-05-06', '0000-0000-0000-0003', '2020-05-04'), 
(4, 4, 'extra', '2017-05-02', '2017-05-06', '0000-0000-0000-0004', '2020-05-04'),
(5, 5, 'regular', '2017-05-02', '2017-05-06', '0000-0000-0000-0005', '2020-05-04');

INSERT INTO revenue #hotelid,total
VALUES 
(1, 400), 
(2, 400), 
(3, 400), 
(4, 400),
(5, 400);








