/*====================================================================================================================================================
Author:  Oden, Shawn 
Created: 10/05/2017 
Desc:    This will build out a calendar table to use for various date calculations. Over the years, I've become a huge fan of date dimensions and 
         calendar tables. They make it significantly easier to perform common date calculations on your data. 
         
         Thank you to Aaron Bertrand for the example used to build out the bulk of this date dimension.
         https://www.mssqltips.com/sqlservertip/4054/creating-a-date-dimension-or-calendar-table-in-sql-server/ 

Notes:   This is primarily set up for Microsoft T-SQL. Because this uses a DATE datatype (and a couple of other things), it is designed for SQL 2008 
         or higher. With some minor modifications (especially CONVERT to CAST), it should be able to be ported to other flavors of SQL. It currently 
         uses mostly computed columns to generate the different reference points for the given date, with several other fields updated in the process. 

         To use this, you'll need to provide @StartDate in the form of YYYYMMDD as the day you want your dimension to start from, and @NumberOfYears 
         as an integer of how many years you need your dates to run to. My example goes from 1/1/1950 to 12/31/2049.

         This includes the columns that I currently use. There are many others that can be useful and should possibly be added. Feel free to add and 
         subtract as needed.

         The output columns are:

         DateKey             int  PK      This is an integer that is made up of the date. It provides a unique key to link on, if needed. yyyymmdd
         theDate             date         This is for the individual date in the dimension.
         theDay              tinyint      This is the number of the day. (1-31)
         DaySuffix           char(2)      This is the 2-character suffix of the day (ie st, nd, rd, th, etc)
         WeekdayNum          tinyint      This is the number that the day falls in the week. (1-7) (1=Sun,2=Mon,3=Tue,4=Wed,5=Thu,6=Fri,7=Sat) 
                                          NOTE: This will be affected by the DATEFIRST setting.
         WeekDayName         varchar(10)  This is the familiar name of the day of the week. (ie Sunday, Monday, etc)
         IsWeekend           bit          This is a flag for a weekend day. This will be affected by the DATEFIRST setting.
         IsHoliday           bit          This is a flag for a US Federal Holiday day. This is set with special rules below for each holiday. This will 
                                          possibly differ for your company, and valid holidays should be updated. It does not include Easter Sunday.
         HolidayText         varchar(64)  This is a description of which holiday this is.
         IsDayOff            bit          This is a flag for a day off work. This will likely differ for your company. It currently works by flagging 
                                          the Monday before a Saturday holiday and the Friday after a Sunday holiday.
         DOWInMonth          tinyint      This is a count of the number of times a day falls in the calendar month. (1-5)
         theDayOfYear        smallint     This is the number of the day for the calendar year. (1-366)
         WeekOfMonth         tinyint      This is the number that the week occurs in the calendar month. (1-5)
         WeekOfYear          tinyint      This is the number that the week occurs in the calendar year. (1-52)
         ISOWeekOfYear       tinyint      This is the ISO standard number that the week occurs in the calendar year. (1-52)
         theMonth            tinyint      This is the number of the month. (1=January, 2=February, .... 12=December)
         theMonthName        varchar(10)  This is the familiar name of the month. (ie January, February, etc)
         FirstDayOfMonth     date         This is the first day of the current month.
         LastDayOfMonth      date         This is the last day of the current month.
         theYear             int          This is the calendar year.
         theFYYear           int          This is the Fiscal Year, determined below. This calendar currently does not follow the standard Jan 1 
                                          Fiscal year. It is likely that you will have to change the FY setup below.
         theFYQuarter        tinyint      This is the Fiscal Quarter, determined below. This calendar currently does not follow the standard 
                                          Jan 1 Fiscal year. It is likely that you will have to change the FY setup below. (1-4)
         FYQuarterName       varchar(6)   This is a friendly name for the Fiscal Quarter. (ie First, Second, Third, Fourth) 
         FirstDayOfFYQuarter date         This is the first day of the current Fiscal Quarter. See note above about quarter setup.
         LastDayOfFYQuarter  date         This is the last day of the current Fiscal Quarter. See note above about quarter setup.

         theMilFormat        varchar(16)  This is the date formatted as follows: dd mon yy
         MMYYYY              char(6)      This is the date formatted as follows: mmyyyy
         MonthYear           char(7)      This is the date formatted as follows: Monyyyy
         yyyymmdd	         char(8)	      This is the date formatted as follows: yyyymmdd
         mm_dd_yy	         char(10)	      This is the date formatted as follows: mm/dd/yyyy
         ------ NOTE: If other formats are commonly needed, they should be added. 

====================================================================================================================================================*/ 

/****************************************************************************************************************/

USE myDatabase
GO

/****************************************************************************************************************/

/* Prevent set or regional settings from interfering with interpretation of dates / literals. */
SET DATEFIRST 7; /* Sunday (default) */ /* If you change this, it will change a lot of calculations. */
SET DATEFORMAT mdy;
SET LANGUAGE US_ENGLISH;
GO

/* Use this to determine your needed date range. */
DECLARE @StartDate    DATE = '19500101'
    , @NumberOfYears  INT = 100; 
DECLARE @CutoffDate   DATE = DATEADD(year, @NumberOfYears, @StartDate);

/****************************************************************************************************************/
/* #dim is just a holding table for intermediate calculations. */

IF OBJECT_ID('tempdb..#dim') IS NOT NULL
  DROP TABLE #dim

CREATE TABLE #dim (
      theDate           date        PRIMARY KEY

    , theDay            AS DATEPART(day, theDate)           --int
    , theDayOfWeek      AS DATEPART(weekday, theDate)       --int
    , theDayOfWeekName  AS CONVERT(varchar(10), DATENAME(weekday, theDate)) --nvarchar
    , isHoliday         bit         NOT NULL    DEFAULT 0   /* Added later */
    , holidayText       varchar(64) NULL                    /* Added later */
    , isDayOff          bit         NOT NULL    DEFAULT 0   /* Added later */

    , theWeek           AS DATEPART(week, theDate)          --int 
    , theISOweek        AS DATEPART(iso_week, theDate)      --int

    , theMonth          AS DATEPART(month, theDate)         --int
    , theMonthName      AS DATENAME(month, theDate)         --nvarchar
    , firstOfMonth      AS CONVERT(date, DATEADD(month, DATEDIFF(month, 0, theDate), 0))  -- Used for other calcs
    , lastOfMonth       AS CONVERT(date, DATEADD(day, -1, DATEADD(month, DATEDIFF(month,0,theDate)+1, 0)))

    , theYear           AS DATEPART(year, theDate)          --int

    , theFYYear         int         NULL                    /* Added later */
    , theFYQuarter      tinyint     NULL                    /* Added later */

    , theMilFormat      AS CONVERT(varchar(16), theDate, 6) /* dd mon yy */
    , yyyymmdd          AS CONVERT(char(8), theDate, 112)   /* yyyymmdd */
    , mm_dd_yy          AS CONVERT(char(10), theDate, 101)  /* mm/dd/yyyy */
);

/****************************************************************************************************************/
/* Use the catalog views to generate as many rows as we need. */

INSERT INTO #dim ( theDate ) 
SELECT d
FROM (
    SELECT d = DATEADD(day, rn - 1, @StartDate)
    FROM 
    (
        SELECT TOP (DATEDIFF(day, @StartDate, @CutoffDate)) 
            rn = ROW_NUMBER() OVER (ORDER BY s1.object_id)
        FROM sys.all_objects AS s1
        CROSS JOIN sys.all_objects AS s2
        ORDER BY s1.object_id
    ) AS x
) AS y;


SELECT * FROM #dim

/****************************************************************************************************************/
/* Update the FY Quarter information in the #dim table. */

/* 
    Fiscal Year Definition
    Q1  10/31  1/31  /* Oddball */
    Q2,  2/1   4/30
    Q3,  5/1   7/31
    Q4,  8/1  10/30  /* Oddball */
*/

/* NOTE: The below is a very non-standard FY setup. Q1 Starts 10/31 and ends 1/31, so technically, it is 3 months + 1 day. Which makes Q4 = 3m-1d. */
UPDATE #dim
SET theFYQuarter = 
    CASE 
        WHEN MONTH(theDate) = 10 AND DAY(theDate) = 31 THEN 1
        WHEN MONTH(theDate) IN (11,12,1) THEN 1
        WHEN MONTH(theDate) IN (2,3,4) THEN 2
        WHEN MONTH(theDate) IN (5,6,7) THEN 3
        WHEN MONTH(theDate) IN (8,9,10) THEN 4
        ELSE NULL
    END
  , theFYYear =     
    CASE 
        WHEN MONTH(theDate) = 10 AND DAY(theDate) = 31  THEN theYear+1  
        WHEN MONTH(theDate) IN (11,12) THEN theYear+1  
        ELSE theYear
    END
;    
/****************************************************************************************************************/
/* Update Holiday Info Here */

/* New Year's Day - 1/1 */ /* FEDERAL */
UPDATE #dim
SET isHoliday = 1
    , holidayText = 'New Years'' Day' 
WHERE theMonth = 1 
    AND theDay = 1 
;

/* Martin Luther King Jr. Day -- third Monday of January */ /* FEDERAL */
; WITH cte_MLK AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY theYear, theMonth ORDER BY theDay) AS monthOccur 
    FROM #dim d2 
    WHERE d2.theMonth = 1 
        AND d2.theDayOfWeek = 2
)
UPDATE cte_MLK
SET isHoliday = 1
    , HolidayText = 'Martin Luther King Jr. Day'
WHERE monthOccur=3
;

/* Presidents' Day -- third Monday of February */ /* FEDERAL */
; WITH cte_P AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY theYear, theMonth ORDER BY theDay) AS monthOccur 
    FROM #dim d2 
    WHERE d2.theMonth = 2
        AND d2.theDayOfWeek = 2
)
UPDATE cte_P
SET isHoliday = 1
    , HolidayText = 'Presidents'' Day'
WHERE monthOccur=3
;

/* Memorial Day -- last Monday of May */ /* FEDERAL */
; WITH cte_M AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY theYear, theMonth ORDER BY theDay DESC) AS monthOccur 
    FROM #dim d2 
    WHERE d2.theMonth = 5
        AND d2.theDayOfWeek = 2
)
UPDATE cte_M
SET isHoliday = 1
    , HolidayText = 'Memorial Day'
WHERE monthOccur=1 /* Last occurrance */
;

/* Independence Day - 7/4 */ /* FEDERAL */
UPDATE #dim
SET isHoliday = 1
    , holidayText = 'Independence Day' 
WHERE theMonth = 7 
    AND theDay = 4 
;

/* Labor Day -- first Monday of September */ /* FEDERAL */
; WITH cte_L AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY theYear, theMonth ORDER BY theDay) AS monthOccur 
    FROM #dim d2 
    WHERE d2.theMonth = 9
        AND d2.theDayOfWeek = 2
)
UPDATE cte_L
SET isHoliday = 1
    , HolidayText = 'Labor Day'
WHERE monthOccur=1 
;

/* Columbus Day -- most regions -- second Monday of October */ /* FEDERAL */
; WITH cte_C AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY theYear, theMonth ORDER BY theDay) AS monthOccur 
    FROM #dim d2 
    WHERE d2.theMonth = 9
        AND d2.theDayOfWeek = 2
)
UPDATE cte_C
SET isHoliday = 1
    , HolidayText = 'Columbus Day'
WHERE monthOccur=2
;

/* Veterans Day - 11/11 */ /* FEDERAL */
UPDATE #dim
SET isHoliday = 1
    , holidayText = 'Veterans Day' 
WHERE theMonth = 11 
    AND theDay = 11 
;

/* Thanksgiving Day -- fourth Thursday of November */ /* FEDERAL */
; WITH cte_T AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY theYear, theMonth ORDER BY theDay) AS monthOccur 
    FROM #dim d2 
    WHERE d2.theMonth = 11
        AND d2.theDayOfWeek = 5
)
UPDATE cte_T
SET isHoliday = 1
    , HolidayText = 'Thanksgiving Day'
WHERE monthOccur=4
;

/* Christmas Day - 12/25 */ /* FEDERAL */
UPDATE #dim
SET isHoliday = 1
    , holidayText = 'Christmas Day' 
WHERE theMonth = 12 
    AND theDay = 25 
;

/* If you have company specific holidays, update them here. */


/* COMMON HOLIDAYS   * indicates a Federal Holiday
* Jan 1 New Year's Day -- 1/1
* Jan 17 Martin Luther King Jr. Day -- third Monday of January
  Feb 14 Valentine's Day  -- 2/14
* Feb 21 Presidents' Day  -- third Monday of February
  Apr 10 Easter Sunday  -- ?????
  Apr 13 Thomas Jefferson's Birthday  -- April 13 
  May 8 Mother's Day  -- second Sunday of May
* May 30 Memorial Day  --  last Monday of May
  Jun 19 Father's Day -- third Sunday of June
* Jul 4 Independence Day  -- 7/4
* Sep 5 Labor Day -- first Monday of September 
* Oct 10 Columbus Day (Most regions) -- second Monday of October
  Oct 31 Halloween  -- 10/31
* Nov 11 Veterans Day -- 11/11
* Nov 24 Thanksgiving Day -- fourth Thursday of November
  Dec 24 Christmas Eve --12/24
* Dec 25 Christmas Day -- 12/25
  Dec 31 New Year's Eve -- 12/31
*/

/****************************************************************************************************************/

/* After holidays are set, what workdays are off based on those holidays. */
/* LEAD/LAG are SQL 2012 = Much more efficient than JOIN. */
--SELECT *
--    , LEAD(isHoliday) OVER (ORDER BY theDate) AS SatHoliday
--FROM #dim
--WHERE theDayOfWeek = 2
--    AND isHoliday = 0

/* Get Monday off. */
/* < SQL 2012 */
; WITH CTE_monOff AS (
    SELECT d1.theDate, d1.isDayOff
    FROM #dim d1
    INNER JOIN #dim d2 ON d1.theDate = DATEADD(day,1,d2.theDate)
    WHERE d1.theDayOfWeek = 2
        AND d1.isHoliday = 0
        AND d2.isHoliday = 1
)
UPDATE CTE_monOff
SET CTE_monOff.isDayOff = 1
;

/* Get Friday off. */
/* < SQL 2012 */
; WITH CTE_friOff AS (
    SELECT d1.theDate, d1.isDayOff
    FROM #dim d1
    INNER JOIN #dim d2 ON d1.theDate = DATEADD(day,-1,d2.theDate)
    WHERE d1.theDayOfWeek = 6
        AND d1.isHoliday = 0
        AND d2.isHoliday = 1
)
UPDATE CTE_friOff
SET CTE_friOff.isDayOff = 1
;

/****************************************************************************************************************/
/* Now create the final ref table for the dates. */

CREATE TABLE dbo.refDateDimension
(
      DateKey             int         NOT NULL PRIMARY KEY
    , theDate             date        NOT NULL

    , theDay              tinyint     NOT NULL  
    , DaySuffix           char(2)     NOT NULL
    , WeekdayNum          tinyint     NOT NULL
    , WeekDayName         varchar(10) NOT NULL
    , IsWeekend           bit         NOT NULL
    , IsHoliday           bit         NOT NULL
    , HolidayText         varchar(64) SPARSE NULL
    , IsDayOff            bit         NOT NULL
    , DOWInMonth          tinyint     NOT NULL
    , theDayOfYear        smallint    NOT NULL
    
    , WeekOfMonth         tinyint     NOT NULL
    , WeekOfYear          tinyint     NOT NULL
    , ISOWeekOfYear       tinyint     NOT NULL
    
    , theMonth            tinyint     NOT NULL
    , theMonthName        varchar(10) NOT NULL
    , FirstDayOfMonth     date        NOT NULL
    , LastDayOfMonth      date        NOT NULL

    , theYear             int         NOT NULL
    
    , theFYYear           int         NOT NULL
    , theFYQuarter        tinyint     NOT NULL
    , FYQuarterName       varchar(6)  NOT NULL
    , FirstDayOfFYQuarter date        NOT NULL
    , LastDayOfFYQuarter  date        NOT NULL

    , theMilFormat        varchar(16) NOT NULL   /* dd mon yy */
    , MMYYYY              char(6)     NOT NULL   /* mmyyyy */
    , MonthYear           char(7)     NOT NULL   /* MonYYYY */
    , yyyymmdd            char(8)     NOT NULL   /* yyyymmdd */
    , mm_dd_yy            char(10)    NOT NULL   /* mm/dd/yyyy */
);
GO

/* Insert data in the dimension table. */
INSERT dbo.refDateDimension WITH (TABLOCKX)
SELECT
      DateKey              = CONVERT(int, yyyymmdd)
    , theDate              = theDate

    , theDay               = CONVERT(tinyint, theDay)
    , DaySuffix            = CONVERT(char(2), 
                                CASE 
                                    WHEN theDay/10 = 1 THEN 'th' /* 10th-19th */
                                    ELSE 
                                        CASE theDay%10 
                                            WHEN '1' THEN 'st' 
                                            WHEN '2' THEN 'nd' 
                                            WHEN '3' THEN 'rd' 
                                            ELSE 'th' 
                                        END 
                                END )
    , WeekdayNum           = CONVERT(tinyint, theDayOfWeek)
    , WeekDayName          = CONVERT(varchar(10), theDayOfWeekName)
    , IsWeekend            = CONVERT(bit, CASE WHEN theDayOfWeek IN (1,7) THEN 1 ELSE 0 END)
    , IsHoliday            = IsHoliday
    , HolidayText          = HolidayText
    , IsDayOff             = IsDayOff
    , DOWInMonth           = CONVERT(tinyint, ROW_NUMBER() OVER (PARTITION BY FirstOfMonth, theDayOfWeek ORDER BY theDate))
    , theDayOfYear         = CONVERT(smallint, DATEPART(dayofyear, theDate))

    , WeekOfMonth          = CONVERT(tinyint, DENSE_RANK() OVER (PARTITION BY theYear, theMonth ORDER BY theWeek))
    , WeekOfYear           = CONVERT(tinyint, theWeek)
    , ISOWeekOfYear        = CONVERT(tinyint, theISOweek)

    , theMonth             = CONVERT(tinyint, theMonth)
    , theMonthName         = CONVERT(varchar(10), theMonthName)
    , FirstDayOfMonth      = FirstOfMonth
    , LastDayOfMonth       = LastOfMonth 

    , theYear              = theYear

    , theFYYear            = theFYYear
    , theFYQuarter         = theFYQuarter
    , FYQuarterName        = CONVERT(varchar(6)
                                , CASE theFYQuarter 
                                   WHEN 1 THEN 'First' 
                                   WHEN 2 THEN 'Second' 
                                   WHEN 3 THEN 'Third' 
                                   WHEN 4 THEN 'Fourth' 
                                END )
    , FirstDayOfFYQuarter  = MIN(theDate) OVER (PARTITION BY theYear, theFYQuarter)
    , LastDayOfFYQuarter   = MAX(theDate) OVER (PARTITION BY theYear, theFYQuarter)

    , DD_Mon_YY            = theMilFormat
    , MMYYYY               = CONVERT(char(6), LEFT(mm_dd_yy, 2)     + theYear)
    , MonthYear            = CONVERT(char(7), LEFT(theMonthName, 3) + theYear)
    , yyyymmdd             = yyyymmdd
    , mm_dd_yy             = mm_dd_yy
FROM #dim
OPTION (MAXDOP 1);

-- SELECT * FROM #dim WHERE theFYQuarter NOT IN (1,2,3,4)
-- SELECT * FROM refDateDimension

/* CLEANUP */
DROP TABLE #dim ;
