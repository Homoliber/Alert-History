# Alert-History
GRID Tile:
Sample Query for retrieving alert details, use the DateAdd value (-30), priority and severity to change it according to your needs.

DECLARE @From DATETIME =DateAdd(Day,-30,GetDate()), @To DATETIME = GetDate()
exec Microsoft_SystemCenter_DataWarehouse_Report_Library_AlertReportDataGet_V2 @LanguageCode=N'ENU',
@StartDate=@From,
@EndDate=@To,
@Severity=N'<Data><Value>2</Value></Data>',
@Priority=N'<Data><Value>0</Value><Value>1</Value><Value>2</Value></Data>',
@ObjectList=N'<Data><Objects><Object Use="Containment">{{id}}</Object></Objects></Data>',
@SiteName=NULL,
@myUID={{id}}

SCALAR Tile:
Sample query to retrieve the count of alerts, change the dateadd, severity and priority to reflect your needs. 

DECLARE @From DATETIME =DateAdd(Day,-30,GetDate()), @To DATETIME = GetDate()
exec Microsoft_SystemCenter_DataWarehouse_Report_Library_AlertReportDataGet_V3 @LanguageCode=N'ENU',
@StartDate=@From,
@EndDate=@To,
@Severity=N'<Data><Value>2</Value></Data>',
@Priority=N'<Data><Value>0</Value><Value>1</Value><Value>2</Value></Data>',
@ObjectList=N'<Data><Objects><Object Use="Containment">{{id}}</Object></Objects></Data>',
@SiteName=NULL,
@myUID={{id}}

