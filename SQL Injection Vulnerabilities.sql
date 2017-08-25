-- This file tries to find stored procedures and functions that *may* be vulnerable to SQL injection attacks.

-- It works by searching your database for occurences of "+" signs followed by "@", indicating that SQL parameters
-- might be getting concatenated to a dynamic SQL string.  It also checks for the existence of 'EXEC' to see if any
-- strings are being executed.

-- Not every result returned will be susceptible to SQL injection, however they should all be examined to see if they are vulnerable.

-- More information can be found at my blog post: https://blog.bertwagner.com/what-every-sql-user-needs-to-know-about-sql-injection-db914fb39668

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT
    ROUTINE_CATALOG,
    ROUTINE_SCHEMA,
    ROUTINE_NAME,
    ROUTINE_TYPE,
    ROUTINE_DEFINITION
FROM
    INFORMATION_SCHEMA.ROUTINES
WHERE
	REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ROUTINE_DEFINITION,CHAR(0),''),CHAR(9),''),CHAR(10),''),CHAR(11),''),CHAR(12),''),CHAR(13),''),CHAR(14),''),CHAR(160),''),' ','')
		LIKE '%+@%'
	AND	
	( -- Only if executes a dynamic string
		ROUTINE_DEFINITION LIKE '%EXEC(%'
		OR ROUTINE_DEFINITION LIKE '%EXECUTE%'
		OR ROUTINE_DEFINITION LIKE '%sp_executesql%'
	)
 
