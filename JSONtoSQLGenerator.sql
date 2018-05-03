/*
This code takes a JSON input string and automatically generates
SQL Server CREATE TABLE and INSERT INTO statements to make it easier
to convert serialized data into tables.

It is not perfect, but should provide a decent starting point when starting
to work with new JSON schemas.
*/

DECLARE @JsonData nvarchar(max) = '
{
	"id" : 1,
	"IsActive":true,
	"people" : ["Jim","Joan","John","Jeff"],
	"places" : [{"State":"Connecticut", "Capitol":"Hartford"},{"State":"Ohio","Capitol":"Columbus","MajorCities":["Cleveland","Cincinnati"]}],
	"created_at":"2018-04-18T21:25:48Z"
}';
DECLARE @RootTableName nvarchar(4000) = N'AppInstance';

WITH jsonRoot AS (
	SELECT 0 as parentLevel, 0 AS level, [type],
	@RootTableName COLLATE Latin1_General_BIN2 AS TableName,
	[key] COLLATE Latin1_General_BIN2 as ColumnName
	,  [value]
	FROM OPENJSON(@JsonData, '$')
	UNION ALL
	SELECT jsonRoot.level as parentLevel, jsonRoot.level+1, d.[type],
	CASE WHEN jsonRoot.type IN (4) THEN CONVERT(nvarchar(4000),jsonRoot.ColumnName) ELSE CONVERT(nvarchar(4000),jsonRoot.ColumnName) COLLATE Latin1_General_BIN2 END,
	CASE WHEN jsonRoot.type IN (4) THEN CONVERT(nvarchar(4000),jsonRoot.ColumnName) ELSE d.[key] END
	,   d.[value]
	FROM jsonRoot
	CROSS APPLY OPENJSON(jsonRoot.[value], '$') d
	WHERE jsonRoot.[type] IN (4,5) 

	
)
SELECT * FROM jsonRoot
WHERE [type] in (1,2,3) 
order by parentLevel, level
