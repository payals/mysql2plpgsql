#test
delimiter //

CREATE PROCEDURE simpleproc (OUT param1 INT)
BEGIN
   SELECT COUNT(*) INTO param1 FROM t;
END//

#ignore
<some code then comment> # mysql function
DELIMITER $func$
CREATE FUNCTION hello_world()
  RETURNS text
  LANGUAGE sql
BEGIN
  # sample query
  SELECT name from test where `lastname` = "singh";
  RETURN 'Hello World';
END;
$func$
DELIMITER ;

DELIMITER // 
CREATE PROCEDURE GetAllProducts() 
BEGIN 
SELECT * FROM products; 
END // 
DELIMITER ; 

#test
delimiter //

CREATE PROCEDURE simpleproc (OUT param1 INT)
BEGIN
   SELECT COUNT(*) INTO param1 FROM t;
END//

# comment!!

delimiter //
CREATE procedure world_record_count ()
begin
select 'country', count(*) from country;
select 'city', count(*) from city;
select 'CountryLanguage', count(*) from CountryLanguage;
end;
//