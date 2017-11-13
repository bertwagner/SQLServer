-- https://github.com/bertwagner/SQLServer/blob/master/SQL%20Injection%20Vulnerabilities.sql

-- How to search your database for SQL Injection vulnerabilities
-- It's very difficult to find with 100% accuracy vulnerabilities, but we can do our best
-- Searches stored procedures, udfs, views for parameter plus + sign for concatenation as well as exec or usp_exec
-- check for things that don't use quotename

-- Why is finding vulnerabilities important?  Because at the end of the day, if data is lost or leaked, you are the one to blame.  
-- Doesn’t matter that the developers did a bad job with validation – your db is supposed to be secure.
-- This will NOT find all instances of sql injection vulnerabilities (eg. adhoc queries, COALESCE(@ParmValue, or ISNULL(@ParmValue...)

USE [<DatabaseName>];
GO

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT
	o.type_desc AS ObjectType,
	DB_NAME(o.parent_object_id) AS DatabaseName,
	s.name as SchemaName,
	o.name as ObjectName,
	r.Definition
FROM
	sys.sql_modules r
	INNER JOIN sys.objects o
		ON r.object_id = o.object_id
	INNER JOIN sys.schemas s
		ON o.schema_id = s.schema_id
WHERE
	-- Remove white space from query texts
	REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
		r.Definition,CHAR(0),''),CHAR(9),''),CHAR(10),''),CHAR(11),''),
		CHAR(12),''),CHAR(13),''),CHAR(14),''),CHAR(160),''),' ','')
	LIKE '%+@%'
	AND	
	( -- Only if executes a dynamic string
		r.Definition LIKE '%EXEC(%'
		OR r.Definition LIKE '%EXECUTE%'
		OR r.Definition LIKE '%sp_executesql%'
	);


-- Search for parameters that look like they could hvae injection values in them

WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')

SELECT
   stmt.value('(@StatementText)[1]', 'varchar(max)') AS [Query],
   query_plan AS [QueryPlan],
   stmt.value('(.//ColumnReference/@ParameterCompiledValue)[1]', 'varchar(1000)') AS [ParameterValue] 
FROM 
	sys.dm_exec_cached_plans AS cp
	CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
	CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS batch(stmt)
WHERE
	-- if single quotes exist in a parameter
	stmt.value('(.//ColumnReference/@ParameterCompiledValue)[1]', 'varchar(1000)') like '%''%'
	OR stmt.value('(.//ColumnReference/@ParameterCompiledValue)[1]', 'varchar(1000)') like '%sys.objects%'
	OR stmt.value('(.//ColumnReference/@ParameterCompiledValue)[1]', 'varchar(1000)') like '%[0-9]=[0-9]%'
