CREATE PROCEDURE [dbo].[Microsoft_SystemCenter_DataWarehouse_Report_Library_ReportObjectListParse_V2]
	@StartDate DATETIME,
	@EndDate DATETIME,
	@ObjectList XML,
	@ContainmentLevelCount INT = 0,
	@ContainmentStartLevel INT = 0,
	@myUID uniqueidentifier = NULL
AS
BEGIN
  SET NOCOUNT ON

  DECLARE @Error int
  DECLARE @ExecError int
  DECLARE @RowCount int


  /* Adjusted Code for Jasper
     Deliver a GUID instead of integer value as in the original "@objectlist" procedure
  
  */


   DECLARE  @ManagedEntityRowId INT
		 , @ManagedEntityGuid UNIQUEIDENTIFIER
         , @ManagedEntityGuid2 NVARCHAR(255)

   SELECT @ManagedEntityGuid2 = ObjectList.ManagedEntityRowId.value('.', 'nvarchar(255)') 
    FROM @ObjectList.nodes('/Data/Objects/Object') AS ObjectList(ManagedEntityRowId)


	--PRINT @ManagedEntityGuid2
	DECLARE @Escape CHAR(1) = 0x27
	--SELECT @Escape
	--PRINT @Escape
	SELECT @ManagedEntityGuid2 = REPLACE(REPLACE(@ManagedEntityGuid2,'"',''),@Escape,'')
	SET @ManagedEntityGuid=@myUID
	--SELECT @ManagedEntityGuid = CAST(@ManagedEntityGuid2 AS UNIQUEIDENTIFIER)
	
	--PRINT @ManagedEntityGuid2
	--PRINT @ManagedEntityGuid

   --SELECT @ManagedEntityGuid
   ---get the @ManagedEntityRowId based on the delivered Guid

   SELECT TOP 1 @ManagedEntityRowId =  [ManagedEntityRowId] FROM [OpsMgrDW].[dbo].[ManagedEntity] WHERE [ManagedEntityGuid] = @ManagedEntityGuid
   SELECT @ManagedEntityRowId

  CREATE TABLE #ObjectList (ManagedEntityRowId int)

  SET @Error = @@ERROR
  IF @Error <> 0 GOTO QuitError

  CREATE TABLE #ContainmentObjectList (
    ManagedEntityRowId  int,
    [Level]             int
  )

  SET @Error = @@ERROR
  IF @Error <> 0 GOTO QuitError

  CREATE TABLE #RelationshipType (
    RelationshipTypeRowId int,
    [Level]               int
  )

  SET @Error = @@ERROR
  IF @Error <> 0 GOTO QuitError

  --INSERT INTO #ObjectList (ManagedEntityRowId)
  --SELECT ObjectList.ManagedEntityRowId.value('.', 'int')
  --FROM @ObjectList.nodes('/Data/Objects/Object') AS ObjectList(ManagedEntityRowId)
  --WHERE ISNULL(ObjectList.ManagedEntityRowId.value('@Use', 'nvarchar(255)'), 'Self') = 'Self'

  INSERT INTO  #ObjectList (ManagedEntityRowId)
  SELECT @ManagedEntityRowId


  SET @Error = @@ERROR
  IF @Error <> 0 GOTO QuitError

  --INSERT INTO #ContainmentObjectList (ManagedEntityRowId, [Level])
  --SELECT ObjectList.ManagedEntityRowId.value('.', 'int'), 0
  --FROM @ObjectList.nodes('/Data/Objects/Object') AS ObjectList(ManagedEntityRowId)
  --WHERE ISNULL(ObjectList.ManagedEntityRowId.value('@Use', 'nvarchar(255)'), 'Self') = 'Containment'

  INSERT INTO #ContainmentObjectList (ManagedEntityRowId, [Level])
  SELECT @ManagedEntityRowId,0


  --SELECT * FROM #ContainmentObjectList


  SELECT @Error = @@ERROR, @RowCount = @@ROWCOUNT
  IF @Error <> 0 GOTO QuitError

  IF @RowCount > 0
  BEGIN
    --PRINT 'ik ben hier'
    DECLARE @ContainmentRelationshipTypeRowId int
    SELECT @ContainmentRelationshipTypeRowId = RelationshipTypeRowId FROM vRelationshipType WHERE RelationshipTypeSystemName = 'System.Containment'

    SET @Error = @@ERROR
    IF @Error <> 0 GOTO QuitError
    
    INSERT #RelationshipType(RelationshipTypeRowId, [Level])
    SELECT RelationshipTypeRowId, [Level]
    FROM dbo.RelationshipDerivedTypeHierarchy(@ContainmentRelationshipTypeRowId, 0)

    SET @Error = @@ERROR
    IF @Error <> 0 GOTO QuitError

    DECLARE @CurrentLevel INT
    SET @CurrentLevel = 1

    WHILE (((@ContainmentLevelCount >= @CurrentLevel) OR (@ContainmentLevelCount = 0)) AND (@RowCount > 0))
    BEGIN
      INSERT INTO #ContainmentObjectList (ManagedEntityRowId, [Level])
      SELECT DISTINCT r.TargetManagedEntityRowId, @CurrentLevel
      FROM Relationship r
           JOIN RelationshipManagementGroup rmg ON (r.RelationshipRowId = rmg.RelationshipRowId)
           JOIN #RelationshipType rt ON (r.RelationshipTypeRowId = rt.RelationshipTypeRowId)
           JOIN #ContainmentObjectList me ON (me.ManagedEntityRowId = r.SourceManagedEntityRowId) AND (me.[Level] = @CurrentLevel - 1)
      WHERE (rmg.FromDateTime <= @EndDate) AND (ISNULL(rmg.ToDateTime, '99991231') >= @StartDate)

      SELECT @Error = @@ERROR, @RowCount = @@ROWCOUNT
      SET @CurrentLevel = @CurrentLevel + 1

      IF @Error <> 0 OR @ExecError <> 0 GOTO QuitError
    END
  END

/* ------------------------------ */

  SELECT ManagedEntityRowId
  FROM #ObjectList

  UNION

  SELECT ManagedEntityRowId
  FROM #ContainmentObjectList
  WHERE [Level] >= @ContainmentStartLevel

  SET @Error = @@ERROR

QuitError:
  DROP TABLE #ObjectList
  DROP TABLE #ContainmentObjectList
  DROP TABLE #RelationshipType

  RETURN @Error
END

