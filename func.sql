<some code then comment> # mysql function
DELIMITER $$
CREATE FUNCTION hello_world()
  RETURNS text
  LANGUAGE sql
BEGIN
  # sample query
  SELECT name from test where `lastname` = "singh";
  RETURN 'Hello World';
END;
$$
DELIMITER ;

DELIMITER // 
CREATE PROCEDURE GetAllProducts() 
BEGIN 
SELECT * FROM products; 
END // 
DELIMITER ; 