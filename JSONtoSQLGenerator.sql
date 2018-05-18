/*
This code takes a JSON input string and automatically generates
SQL Server CREATE TABLE statements to make it easier
to convert serialized data into a database schema.

It is not perfect, but should provide a decent starting point when starting
to work with new JSON files.

A blog post with more information can be found at https://bertwagner.com/2018/05/22/converting-json-to-sql-server-create-table-statements/
*/
SET NOCOUNT ON;

DECLARE 
	@JsonData nvarchar(max) = '
		{
			"Id" : 1,
			"IsActive":true,
			"Ratio": 1.25,
			"ActivityArray":[true,false,true],
			"People" : ["Jim","Joan","John","Jeff"],
			"Places" : [{"State":"Connecticut", "Capitol":"Hartford", "IsExpensive":true},{"State":"Ohio","Capitol":"Columbus","MajorCities":["Cleveland","Cincinnati"]}],
			"Thing" : { "Type":"Foo", "Value" : "Bar" },
			"Created_At":"2018-04-18T21:25:48Z"
		}',
	@RootTableName nvarchar(4000) = N'AppInstance',
	@Schema nvarchar(128) = N'dbo',
	@DefaultStringPadding smallint = 20;

DROP TABLE IF EXISTS ##parsedJson;
WITH jsonRoot AS (
	SELECT 
		0 as parentLevel, 
		CONVERT(nvarchar(4000),NULL) COLLATE Latin1_General_BIN2 as parentTableName, 
		0 AS [level], 
		[type] ,
		@RootTableName COLLATE Latin1_General_BIN2 AS TableName,
		[key] COLLATE Latin1_General_BIN2 as ColumnName,
		[value],
		ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS ColumnSequence
	FROM 
		OPENJSON(@JsonData, '$')
	UNION ALL
	SELECT 
		jsonRoot.[level] as parentLevel, 
		CONVERT(nvarchar(4000),jsonRoot.TableName) COLLATE Latin1_General_BIN2, 
		jsonRoot.[level]+1, 
		d.[type],
		CASE WHEN jsonRoot.[type] IN (4,5) THEN CONVERT(nvarchar(4000),jsonRoot.ColumnName) ELSE jsonRoot.TableName END COLLATE Latin1_General_BIN2,
		CASE WHEN jsonRoot.[type] IN (4) THEN jsonRoot.ColumnName ELSE d.[key] END,
		d.[value],
		ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS ColumnSequence
	FROM 
		jsonRoot
		CROSS APPLY OPENJSON(jsonRoot.[value], '$') d
	WHERE 
		jsonRoot.[type] IN (4,5) 
), IdRows AS (
	SELECT 
		-2 as parentLevel,
		null as parentTableName,
		-1 as [level],
		null as [type],
		TableName as Tablename,
		TableName+'Id' as columnName, 
		null as [value],
		0 as columnsequence
	FROM 
		(SELECT DISTINCT tablename FROM jsonRoot) j
), FKRows AS (
	SELECT 
		DISTINCT -1 as parentLevel,
		null as parentTableName,
		-1 as [level],
		null as [type],
		TableName as Tablename,
		parentTableName+'Id' as columnName, 
		null as [value],
		0 as columnsequence
	FROM 
		(SELECT DISTINCT tableName,parentTableName FROM jsonRoot) j
	WHERE 
		parentTableName is not null
)
SELECT 
	*,
	CASE [type]
		WHEN 1 THEN 
			CASE WHEN TRY_CONVERT(datetime2, [value], 127) IS NULL THEN 'nvarchar' ELSE 'datetime2' END
		WHEN 2 THEN 
			CASE WHEN TRY_CONVERT(int, [value]) IS NULL THEN 'float' ELSE 'int' END
		WHEN 3 THEN 
			'bit'
		END COLLATE Latin1_General_BIN2 AS DataType,
	CASE [type]
		WHEN 1 THEN 
			CASE WHEN TRY_CONVERT(datetime2, [value], 127) IS NULL THEN MAX(LEN([value])) OVER (PARTITION BY TableName, ColumnName) + @DefaultStringPadding ELSE NULL END
		WHEN 2 THEN 
			NULL
		WHEN 3 THEN 
			NULL
		END AS DataTypePrecision
INTO ##parsedJson
FROM jsonRoot
WHERE 
	[type] in (1,2,3)
UNION ALL SELECT IdRows.parentLevel, IdRows.parentTableName, IdRows.[level], IdRows.[type], IdRows.TableName, IdRows.ColumnName, IdRows.[value], -10 AS ColumnSequence, 'int IDENTITY(1,1) PRIMARY KEY' as datatype, null as datatypeprecision FROM IdRows 
UNION ALL SELECT FKRows.parentLevel, FKRows.parentTableName, FKRows.[level], FKRows.[type], FKRows.TableName, FKRows.ColumnName, FKRows.[value], -9 AS ColumnSequence, 'int' as datatype, null as datatypeprecision FROM FKRows 

-- For debugging:
-- SELECT * FROM ##parsedJson ORDER BY ParentLevel, level, tablename, columnsequence

DECLARE @CreateStatements nvarchar(max);

SELECT
	@CreateStatements = COALESCE(@CreateStatements + CHAR(13) + CHAR(13), '') + 
	'CREATE TABLE ' + @Schema + '.' + TableName + CHAR(13) + '(' + CHAR(13) +
		STRING_AGG( ColumnName + ' ' + DataType + ISNULL('('+CAST(DataTypePrecision AS nvarchar(20))+')','') +  CASE WHEN DataType like '%PRIMARY KEY%' THEN '' ELSE ' NULL' END, ','+CHAR(13)) WITHIN GROUP (ORDER BY ColumnSequence) 
	+ CHAR(13)+')'
FROM
	(SELECT DISTINCT 
		j.TableName, 
		j.ColumnName,
		MAX(j.ColumnSequence) AS ColumnSequence, 
		j.DataType, 
		j.DataTypePrecision, 
		j.[level] 
	FROM 
		##parsedJson j
		CROSS APPLY (SELECT TOP 1 ParentTableName + 'Id' AS ColumnName FROM ##parsedJson p WHERE j.TableName = p.TableName ) p
	GROUP BY
		j.TableName, j.ColumnName,p.ColumnName, j.DataType, j.DataTypePrecision, j.[level] 
	) j
GROUP BY
	TableName


PRINT @CreateStatements;


