USE [OperationsManagerDW]
GO
/****** Object:  StoredProcedure [dbo].[Microsoft_SystemCenter_DataWarehouse_Report_Library_AlertReportDataGet_V2]    Script Date: 23/10/2017 14:30:13 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREAPROCEDURE [dbo].[Microsoft_SystemCenter_DataWarehouse_Report_Library_AlertReportDataGet_V2]
	@StartDate DATETIME,
	@EndDate DATETIME,
	@ObjectList XML,
	@Severity XML,
	@Priority XML,
	@SiteName NVARCHAR(256),
    @LanguageCode VARCHAR(3) = 'ENU',
	@myUID uniqueidentifier = NULL
AS
BEGIN 
  SET NOCOUNT ON
/*
Modified : 12/10/2017 by Van Heghe Eddy (SQL Dba)
Call to: 
  EXECUTE @ExecError = [Microsoft_SystemCenter_DataWarehouse_Report_Library_ReportObjectListParse_V2]
  set in request of Jasper : 12/10/2017
  This because the original ID provided is not sufficient, needed a guid!
  this for other reports functionality
  rem: also the resultset has been altered
*/
  DECLARE @Error int
  DECLARE @ExecError int

  CREATE TABLE #ObjectList (ManagedEntityRowId int)

  SET @Error = @@ERROR
  IF @Error <> 0 GOTO QuitError

  CREATE TABLE #SeverityList (Severity tinyint)

  SET @Error = @@ERROR
  IF @Error <> 0 GOTO QuitError

  CREATE TABLE #PriorityList (Priority tinyint)

  SET @Error = @@ERROR
  IF @Error <> 0 GOTO QuitError

  CREATE TABLE #TempAlert
  (
	AlertName nvarchar(256) COLLATE database_default,
	Severity tinyint,
	Priority tinyint,
	ManagedEntityRowId int,
	LastRaisedTime datetime,
	FirstRaisedTime datetime,
    AlertDescription nvarchar(max) COLLATE database_default,
	RepeatCount int,
	SiteName nvarchar(256) COLLATE database_default, 
	AlertProblemGuid uniqueidentifier
  )	

  SET @Error = @@ERROR
  IF @Error <> 0 GOTO QuitError

  INSERT INTO #ObjectList (ManagedEntityRowId)
  EXECUTE @ExecError = [Microsoft_SystemCenter_DataWarehouse_Report_Library_ReportObjectListParse_V2]
    @ObjectList = @ObjectList,
    @StartDate = @StartDate,
    @EndDate = @EndDate,
	@myUID=@myUID

  SET @Error = @@ERROR
  IF @Error <> 0 OR @ExecError <> 0 GOTO QuitError

  INSERT INTO #SeverityList (Severity)
  SELECT SeverityList.Severity.value('.','tinyint')
  FROM @Severity.nodes('/Data/Value') AS SeverityList(Severity)

  SET @Error = @@ERROR
  IF @Error <> 0 GOTO QuitError

  INSERT INTO #PriorityList (Priority)
  SELECT PriorityList.Priority.value('.','tinyint') AS Priority
  FROM @Priority.nodes('/Data/Value') AS PriorityList(Priority)

  SET @Error = @@ERROR
  IF @Error <> 0 GOTO QuitError

  INSERT INTO #TempAlert
	SELECT 
		Alert.vAlert.AlertName,Alert.vAlert.Severity,Alert.vAlert.Priority,Alert.vAlert.ManagedEntityRowId,
		MAX(Alert.vAlert.RaisedDateTime) AS LastRaisedTime,
		MIN(Alert.vAlert.RaisedDateTime) AS FirstRaisedTime,
        MIN(Alert.vAlert.AlertDescription) AS AlertDescription,
		COUNT(*) AS RepeatCount,
		Alert.vAlert.SiteName, 
		Alert.vAlert.AlertProblemGuid
	FROM 
		Alert.vAlert
        INNER JOIN #ObjectList ON #ObjectList.ManagedEntityRowId = Alert.vAlert.ManagedEntityRowId
        INNER JOIN #SeverityList ON #SeverityList.Severity = Alert.vAlert.Severity
        INNER JOIN #PriorityList ON #PriorityList.Priority = Alert.vAlert.Priority
	WHERE 
		Alert.vAlert.RaisedDateTime >= @StartDate AND
		Alert.vAlert.RaisedDateTime < @EndDate AND 
		Alert.vAlert.MonitorAlertInd = '1' AND
		(@SiteName IS NULL OR Alert.vAlert.SiteName = @SiteName)
	GROUP BY
		Alert.vAlert.AlertName,Alert.vAlert.Severity,Alert.vAlert.Priority,Alert.vAlert.ManagedEntityRowId,
		Alert.vAlert.SiteName, Alert.vAlert.AlertProblemGuid

  SET @Error = @@ERROR
  IF @Error <> 0 GOTO QuitError

/* ------------------------------ */

SELECT 
	TempAlert.AlertName, TempAlert.Severity,TempAlert.Priority, TempAlert.ManagedEntityRowId,
	cast (CONVERT(VARCHAR(20), TempAlert.LastRaisedTime, 13) as varchar) as LastRaisedTime, cast (CONVERT(VARCHAR(20), TempAlert.FirstRaisedTime, 13) as varchar) as FirstRaisedTime,
    TempAlert.AlertDescription,	TempAlert.RepeatCount,
	TempAlert.SiteName, TempAlert.AlertProblemGuid,

	vManagedEntity.ManagedEntityDefaultName,vManagedEntity.ManagedEntityGuid,
	vManagedEntity.Path, 
    ISNULL(vDisplayString.Name,vManagedEntityType.ManagedEntityTypeDefaultName)AS DisplayName,
	vManagementGroup.ManagementGroupDefaultName,vManagementGroup.ManagementGroupGuid,
	vManagedEntityTypeImage.Image
	, SUM(RepeatCount) OVER(PARTITION BY 1) AS [TotalRepeatCount]    --<-- added 12/10/17 by request : Jasper van Damme
FROM
	#TempAlert AS TempAlert INNER JOIN
    vManagedEntity ON TempAlert.ManagedEntityRowId = vManagedEntity.ManagedEntityRowId INNER JOIN 
    vManagedEntityType ON vManagedEntityType.ManagedEntityTypeRowId = vManagedEntity.ManagedEntityTypeRowId INNER JOIN
    vManagementGroup ON vManagementGroup.ManagementGroupRowId = vManagedEntity.ManagementGroupRowId LEFT OUTER JOIN
	vManagedEntityTypeImage ON vManagedEntityTypeImage.ManagedEntityTypeRowId = vManagedEntity.ManagedEntityTypeRowId AND
    vManagedEntityTypeImage.ImageCategory ='u16x16Icon' LEFT OUTER JOIN 
    vDisplayString ON vManagedEntityType.ManagedEntityTypeGuid = vDisplayString.ElementGuid AND 
	vDisplayString.LanguageCode = @LanguageCode



  SET @Error = @@ERROR

QuitError:
  DROP TABLE #ObjectList
  DROP TABLE #SeverityList
  DROP TABLE #PriorityList
  DROP TABLE #TempAlert
  RETURN @Error
END

