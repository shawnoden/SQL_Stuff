USE [myDB]
GO

/****** Object:  UserDefinedFunction [dbo].[fn_GetDateInterval_YMD]    Script Date: 06/30/2017 09:41:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/****************************************************************************************
Author:		    Oden, Shawn
Create date:    2017-06-30
Description:	Returns the interval in years, months, days of a given date.
    PARSENAME >>> [ Servername.Databasename.Ownername.Objectname ] The numbering works from right to left 
    so Objectname = 1, Ownername = 2, Databasename = 3 and Servername = 4.
    See https://stackoverflow.com/questions/57599/how-to-calculate-age-in-t-sql-with-years-months-and-days 
    To use:
        SELECT PARSENAME(dbo.fn_GetDateInterval_YMD(inDate),3) AS years
            , PARSENAME(dbo.fn_GetDateInterval_YMD(inDate),2) AS months
            , PARSENAME(dbo.fn_GetDateInterval_YMD(inDate),1) AS days

    --== TEST CASES ==--
    ; WITH #t AS (
        SELECT '2012-02-29' AS theStart, '2013-02-28' AS theEnd UNION ALL
        SELECT '2012-02-29' AS theStart, '2016-02-28' AS theEnd UNION ALL
        SELECT '2012-02-29' AS theStart, '2016-03-31' AS theEnd UNION ALL
        SELECT '2012-01-30' AS theStart, '2016-02-29' AS theEnd UNION ALL
        SELECT '2012-01-30' AS theStart, '2016-03-01' AS theEnd UNION ALL
        SELECT '2011-12-30' AS theStart, '2016-02-29' AS theEnd UNION ALL
        SELECT '1990-01-01' AS theStart, '2017-01-01' AS theEnd UNION ALL
        SELECT '2017-01-01' AS theStart, '2017-07-01' AS theEnd 
    )
    , i AS ( SELECT theStart, theEnd, dbo.fn_GetDateInterval_YMD(theStart, theEnd) AS interval FROM #t )
    SELECT theStart
        , theEnd
        , interval
        , PARSENAME(dbo.fn_GetDateInterval_YMD(theStart, theEnd),3) AS years
        , PARSENAME(dbo.fn_GetDateInterval_YMD(theStart, theEnd),2) AS months
        , PARSENAME(dbo.fn_GetDateInterval_YMD(theStart, theEnd),1) AS days
    FROM i

****************************************************************************************/

CREATE FUNCTION [dbo].[fn_GetDateInterval_YMD] (   
      @date1 date
    , @date2 date
)

RETURNS varchar(10) 

AS
BEGIN

DECLARE
      @date1_int    int     = CONVERT(varchar(8),@date1, 112)   /* ISO FORMAT - yyyyMMdd */
    , @date2_int    int     = CONVERT(varchar(8),@date2, 112)   /* ISO FORMAT - yyyyMMdd */
    , @date2_days   int     = DAY( DATEADD( day, -1, LEFT( CONVERT(varchar(8), DATEADD(month,1,@date1),112), 6 )+'01' ) )
;
DECLARE 
      @years    int = (@date2_int - @date1_int)/10000 
        /* This subtracts the ISO dates to get a divisible integer to calc years. ie 20170131 - 20000201 = 169930 / 10000 = 16.993 == 16 full years */
    , @months   int = ( 1200 + ( ( MONTH(@date2) - MONTH(@date1) ) * 100 ) + ( DAY(@date2) - DAY(@date1) ) ) /100 % 12 
        /* This does math magic to come up with the number of full months since x. +1 for MOD. */        
    , @days     int = ( SIGN(DAY(@date2)-DAY(@date1))+1 ) / 2 * ( DAY(@date2)-DAY(@date1) ) 
                    + ( SIGN(DAY(@date1)-DAY(@date2))+1 ) / 2 * ( @date2_days - DAY(@date1) + DAY(@date2) ) 
        /*  
            More math magic. 
            SIGN() - https://docs.microsoft.com/en-us/sql/t-sql/functions/sign-transact-sql == Returns -1,0,1 for sign of eval'd value.
            
            If the # of days of @date2 is bigger than the days of @date1, then diff the two days else add the days of @date2 and the distance from @date1 to the end of the @date1 month 
        */
;

/* Final return value */
RETURN CONVERT(varchar(3),@years) + '.' + CONVERT(varchar(2),@months) + '.' + CONVERT(varchar(2),@days) ;

END
GO
