USE [functions]
GO
/****** Object:  UserDefinedFunction [dbo].[FORMAT_PHONE_ONLY_NUMBERS]    Script Date: 10/21/2014 3:02:17 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*==================================================================================================
Author:		Oden, Shawn
Created:	10/21/2014
Desc:		This function strips all non-numeric characters from a string and returns a number string. 
			Valid input is any string, but final output will be a 10 or 7 character string.
			This function is only valid for US FORMAT phone numbers, and if a US code of 1 is used, it 
			will be stripped from the number. 
			
			@IncludeAreaCode = 0 will strip the area code section of the number. 

Notes:		PHONE NUMBER VALIDATION IS AN EXERCISE IN FUTILITY!!! ANYTHING can be entered by the 
			user. The best we can hope for is consistent data entry. Format is dealt with before it 
			reaches the export. Plus, '1 (800) CALLBOB' is _technically_ a valid phone number, even
			though it can't be entered in this specific case. This function would fail miserably for 
			this number. This function is simply used for a mostly-regular formatting of input that 
			will be stripped down for a specific client. Anything out of the norm will have 
			non-numerics stripped and the leftover numerics will return. This isn't ideal for a 
			generally reusable function without more checking. I don't like it, but it covers this 
			current, specific use cases. If invalid text is entered, the function will send bad data 
			on the export. If I need to reuse this function, I'll refactor it to be more versatile.
==================================================================================================*/

ALTER FUNCTION [dbo].[FORMAT_PHONE_ONLY_NUMBERS]
(
	@PhoneIn varchar(20)
	, @IncludeAreaCode bit = 0
)
RETURNS varchar(10)
AS
BEGIN

	DECLARE @DitchValues varchar(10) = '%[^0-9]%' /* Anything non-numeric */
	DECLARE @RetNum varchar(20) = @PhoneIn

	/* Remove non-numeric characters from string. */
	WHILE PATINDEX(@DitchValues,@RetNum) > 0
	BEGIN
		SET @RetNum = STUFF(@RetNum, PATINDEX(@DitchValues,@RetNum),1,'')
	END

	/* Strip leading '1' character. */
	IF LEN(@RetNum) = 11 AND LEFT(@RetNum,1) = '1'
	BEGIN
		SET @RetNum = RIGHT(@RetNum,10)
	END

	/* Strip area code digits. */
	IF LEN(@RetNum) = 10 AND @IncludeAreaCode = 0
	BEGIN
		SET @RetNum = RIGHT(@RetNum,7)
	END

	RETURN @RetNum

END



/* TEST TEST TEST TEST TEST

; WITH testData_AC (phonenum, validValue, description) AS (
	SELECT '1,234,567-8902', '2345678902', 'With area code.'
	UNION ALL
	SELECT '1.234.567.8902', '2345678902', 'With area code.'
	UNION ALL
	SELECT '1 234 567 8902', '2345678902', 'With area code.'
	UNION ALL
	SELECT '1 (234) 567-8902', '2345678902', 'With area code.'
	UNION ALL
	SELECT '(234) 567-8902', '2345678902', 'With area code.'
	UNION ALL
	SELECT '234 567 8902', '2345678902', 'With area code.'
	UNION ALL
	SELECT '2345678902', '2345678902', 'With area code.'
	UNION ALL
	SELECT 'asdf123g456hjkl', '123456', 'With area code.'
	UNION ALL
	SELECT '234-5678', '2345678', 'With area code.'
	UNION ALL
	SELECT '234asdf', '234', 'With area code.'
	UNION ALL
	SELECT 'abcd', '', 'With area code.'
	UNION ALL
	SELECT 'abcd' + CHAR(13)+CHAR(10), '', 'With area code.'
	UNION ALL
	SELECT '      123456      ', '123456', 'With area code.'
	UNION ALL
	SELECT '   a   123456   b   ', '123456', 'With area code.'
) 
SELECT phonenum AS InputData 
	, validValue
	, fn.dbo.FORMAT_PHONE_ONLY_NUMBERS(phonenum,1) AS FormatedPhoneNum
	, CASE WHEN fn.dbo.FORMAT_PHONE_ONLY_NUMBERS(phonenum,1) = validValue THEN 'Y' ELSE 'N' END AS FunctionWorks
FROM testData_AC

; WITH testData_NoAC (phonenum, validValue, description) AS (
	SELECT '1,234,567-8902', '5678902', 'No area code.'
	UNION ALL
	SELECT '1.234.567.8902', '5678902', 'No area code.'
	UNION ALL
	SELECT '1 234 567 8902', '5678902', 'No area code.'
	UNION ALL
	SELECT '1 (234) 567-8902', '5678902', 'No area code.'
	UNION ALL
	SELECT '(234) 567-8902', '5678902', 'No area code.'
	UNION ALL
	SELECT '234 567 8902', '5678902', 'No area code.'
	UNION ALL
	SELECT '2345678902', '5678902', 'No area code.'
	UNION ALL
	SELECT 'asdf123g456hjkl', '123456', 'No area code.'
	UNION ALL
	SELECT '234-5678', '2345678', 'No area code.'
	UNION ALL
	SELECT '234asdf', '234', 'No area code.'
	UNION ALL
	SELECT 'abcd', '', 'No area code.'
	UNION ALL
	SELECT 'abcd' + CHAR(13)+CHAR(10), '', 'No area code.'
	UNION ALL
	SELECT '      123456      ', '123456', 'No area code.'
	UNION ALL
	SELECT '   a   123456   b   ', '123456', 'No area code.'
)
SELECT phonenum AS InputData 
	, validValue
	, fn.dbo.FORMAT_PHONE_ONLY_NUMBERS(phonenum,0) AS FormatedPhoneNum
	, CASE WHEN fn.dbo.FORMAT_PHONE_ONLY_NUMBERS(phonenum,0) = validValue THEN 'Y' ELSE 'N' END AS FunctionWorks
FROM testData_NoAC


TEST TEST TEST TEST TEST */
