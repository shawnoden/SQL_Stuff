USE [dbName]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_SplitStringAtSpecifiedCharacter]    Script Date: 4/8/2014 8:24:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
SPO 04/08/2014	This function will split a string at the specified character. It will return the string either before 
			or after the SplitOnCharacter depending on the ReturnAfterCharacter flag. Default is to return before the 
			SplitOnCharacter. As of right now, it will only return the from the first occurance of the split character.
			This function will not return the split character. It was originally designed to remove the cents from a 
			dollar value (Salary). 
			
			This is a very basic split function. Am I missing any test cases? This needs more error trapping. I need to test 
			more for using a space as the @SplitOnCharacter. I can also modify this to include a list of characters to 
			split on, but that's not needed right now. This function currently trims leading and trailing space of the 
			return value (unless the @SplitOnCharacter is not found). Should probably stay consistent.
*/

ALTER FUNCTION dbo.fn_SplitStringAtSpecifiedCharacter(
    @InputVariable VARCHAR(1000)
    , @SplitOnCharacter VARCHAR(5)
    , @ReturnAfterCharacter bit = 0
) RETURNS VARCHAR(1000)
AS 
BEGIN

	/* Should add more error trapping later. For now, neither @SplitOnCharacter nor @InputVariable should be NULL. */
	BEGIN
		IF @InputVariable IS NULL OR @SplitOnCharacter IS NULL 
			RETURN @InputVariable
	END

	DECLARE @ReturnString VARCHAR(1000)
	DECLARE @SplitPosition INT
	DECLARE @LenInputVariable INT = LEN(@InputVariable)

	/* Find the first occurrence of the @SplitOnCharacter. */
	SET @SplitPosition = CHARINDEX(ISNULL(@SplitOnCharacter,''),ISNULL(@InputVariable,''))

	SET @ReturnString = 
		CASE
			/* @SplitOnCharacter not found in @InputVariable. RETURN original @InputVariable. */ 
			WHEN @SplitPosition <= 0
				THEN @InputVariable 

			/* @SplitOnCharacter is only character in @InputVariable. */ 
			WHEN @SplitPosition = 1 AND @LenInputVariable = 1 
				THEN NULL

			/* @SplitOnCharacter is last character in @InputVariable. */
			WHEN @SplitPosition = @LenInputVariable  AND @LenInputVariable > 1 
				THEN
					CASE 
						WHEN @ReturnAfterCharacter = 1 THEN NULL /* There's nothing to return after the @InputVariable. */
						ELSE LEFT( @InputVariable,@LenInputVariable-1 ) /* RETURN whatever is to the left of @SplitOnCharacter. */
					END

			/* @SplitOnCharacter is first character in @InputVariable. */ 
			WHEN @SplitPosition = 1 AND @LenInputVariable > 1 
				THEN
					CASE 
						WHEN @ReturnAfterCharacter = 1 THEN SUBSTRING(@InputVariable,2,@LenInputVariable) /* Return everything except first character. */
						ELSE NULL /* Nothing to return before @SplitOnCharacter. */
					END
			
			/* @SplitOnCharacter is in @InputVariable. Normal split. */
			ELSE 
				CASE 
					WHEN @ReturnAfterCharacter = 1 THEN SUBSTRING(@InputVariable,@SplitPosition+1,@LenInputVariable) 
					ELSE LEFT( @InputVariable,@SplitPosition-1 )
				END
				
		END 

	/* TRIM leading and trailing space. NOTE: To stay consistent, I should eliminate this. */
	SET @ReturnString = LTRIM(RTRIM(@ReturnString))
	
	RETURN @ReturnString
END

/* SUBSTRING(@InputVariable,1,(CASE WHEN CHARINDEX(@SplitOnCharacter,@InputVariable) = 0 THEN len(@InputVariable) ELSE CHARINDEX(@SplitOnCharacter,@InputVariable)-1 END))) */

/* 
TESTING:

DROP TABLE #TestTable_SplitString

CREATE TABLE #TestTable_SplitString ( 
	InValue VARCHAR(50) NULL
	, SplitOn VARCHAR(10) NULL
	, SplitString_Before VARCHAR(1000) NULL
	, ShouldBe_Before VARCHAR(500) NULL
	, PassFail_Before VARCHAR(50) NULL
	, SplitString_After VARCHAR(1000) NULL
	, ShouldBe_After VARCHAR(500) NULL
	, PassFail_After VARCHAR(50) NULL
	)


INSERT INTO #TestTable_SplitString ( InValue, SplitOn, ShouldBe_Before, ShouldBe_After )
/* @SplitOnCharacter not found in @InputVariable. RETURN original @InputVariable. */ 
SELECT 
	'987,654' AS InValue
	, '.' AS SplitOn
	, '987,654' AS ShouldBe_Before
	, '987,654' AS ShouldBe_After
	
UNION ALL

/* @SplitOnCharacter is only character in @InputVariable. */ 
SELECT 
	'.' AS InValue
	, '.' AS SplitOn
	, NULL AS ShouldBe_Before
	, NULL AS ShouldBe_After

UNION ALL

/* @SplitOnCharacter is last character in @InputVariable. */
SELECT 
	'987,654.' AS InValue
	, '.' AS SplitOn
	, '987,654' AS ShouldBe_Before
	, NULL AS ShouldBe_After

UNION ALL

/* @SplitOnCharacter is first character in @InputVariable. */ 
SELECT 
	'.32' AS InValue
	, '.' AS SplitOn
	, NULL AS ShouldBe_Before
	, '32' AS ShouldBe_After

UNION ALL

/* @SplitOnCharacter is in @InputVariable. Normal split. */
SELECT 
	'987,654.32' AS InValue
	, '.' AS SplitOn
	, '987,654' AS ShouldBe_Before
	, '32' AS ShouldBe_After

UNION ALL

/* Everybody NULL */
SELECT 
	NULL AS InValue
	, NULL AS SplitOn
	, NULL AS ShouldBe_Before
	, NULL AS ShouldBe_After

UNION ALL

/* Multiple split characters. */
SELECT 
	'123|456|789' AS InValue
	, '|' AS SplitOn
	, '123' AS ShouldBe_Before
	, '456|789' AS ShouldBe_After


UPDATE #TestTable_SplitString
SET 
	SplitString_Before = dbName.dbo.fn_SplitStringAtSpecifiedCharacter(InValue,SplitOn,0)
	, PassFail_Before =  CASE WHEN ISNULL(dbName.dbo.fn_SplitStringAtSpecifiedCharacter(InValue,SplitOn,0),'NULLValue') = ISNULL(ShouldBe_Before,'NULLValue') THEN 'PASS' ELSE 'FAIL' END 
	, SplitString_After =  dbName.dbo.fn_SplitStringAtSpecifiedCharacter(InValue,SplitOn,1)
	, PassFail_After =  CASE WHEN ISNULL(dbName.dbo.fn_SplitStringAtSpecifiedCharacter(InValue,SplitOn,1),'NULLValue') = ISNULL(ShouldBe_After,'NULLValue') THEN 'PASS' ELSE 'FAIL' END 


SELECT * FROM #TestTable_SplitString


/* Test passing NULL Values into function. */
SELECT 
	  'NullInputVariable - Should pass back InputVariable.' AS TestType
	, dbName.dbo.fn_SplitStringAtSpecifiedCharacter(NULL,'.',0) AS Test1_ReturnValue
	, CASE WHEN ISNULL(dbName.dbo.fn_SplitStringAtSpecifiedCharacter(NULL,'.',0),'NULLValue') = 'NULLValue' THEN 'PASS' ELSE 'FAIL' END  AS PassFail
	, 'NullSplitOnCharacter - Should pass back InputVariable.' AS TestType
	, dbName.dbo.fn_SplitStringAtSpecifiedCharacter('123456.789',NULL,0) AS Test2_ReturnValue
	, CASE WHEN ISNULL(dbName.dbo.fn_SplitStringAtSpecifiedCharacter('123456.789',NULL,0),'NULLValue') = '123456.789' THEN 'PASS' ELSE 'FAIL' END  AS PassFail
	, 'NullReturnAfterCharacter - Should pass back split string before.' AS TestType
	, dbName.dbo.fn_SplitStringAtSpecifiedCharacter('123456.789','.',NULL) AS Test3_ReturnValue
	, CASE WHEN ISNULL(dbName.dbo.fn_SplitStringAtSpecifiedCharacter('123456.789','.',NULL),'NULLValue') = '123456' THEN 'PASS' ELSE 'FAIL' END  AS PassFail


*/


