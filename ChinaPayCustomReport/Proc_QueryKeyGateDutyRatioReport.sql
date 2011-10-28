if OBJECT_ID(N'Proc_QueryKeyGateDutyRatioReport', N'P') is not null
begin
	drop procedure Proc_QueryKeyGateDutyRatioReport;
end
go

create procedure Proc_QueryKeyGateDutyRatioReport
	@StartDate datetime = '2011-09-01',
	@PeriodUnit nchar(4) = N'��',
	@MeasureCategory nchar(10) = N'�ɹ����',
	@ReportCategory nchar(10) = N'����',
	@topnum int = 15
as
begin

DECLARE @CurrStartDate datetime; 
DECLARE @CurrEndDate datetime; 
IF (@PeriodUnit = N'��') 
BEGIN
	SET @CurrStartDate = @StartDate;
	SET @CurrEndDate = DATEADD(week, 1, @StartDate); 
END 
ELSE IF (@PeriodUnit = N'��') 
BEGIN
	SET @CurrStartDate = @StartDate;
	SET @CurrEndDate = DATEADD(MONTH, 1, @StartDate); 
END 
ELSE IF (@PeriodUnit = N'����') 
BEGIN
	SET @CurrStartDate = @StartDate;
	SET @CurrEndDate = DATEADD(QUARTER, 1, @StartDate); 
END 
ELSE IF (@PeriodUnit = N'����') 
BEGIN
	SET @CurrStartDate = @StartDate;
	SET @CurrEndDate = DATEADD(QUARTER, 2, @StartDate); 
END 
ELSE IF (@PeriodUnit = N'��') 
BEGIN
	SET @CurrStartDate = @StartDate;
	SET @CurrEndDate = DATEADD(YEAR, 1, @StartDate); 
END
 
--1. Get this period trade count/amount 
SELECT 
	GateNo, 
	MerchantNo, 
    sum(SucceedTransCount) SumSucceedCount, 
    sum(SucceedTransAmount) SumSucceedAmount
INTO 
	#CurrTrans
FROM 
	FactDailyTrans
WHERE 
	DailyTransDate >= @CurrStartDate 
	AND 
    DailyTransDate < @CurrEndDate
GROUP BY 
	GateNo, 
	MerchantNo; 
     
--4.1 Get Sum Value 
CREATE TABLE #SumValue
(
	GateNo char(4) NOT NULL, 
	CurrSumValue bigint NOT NULL
); 
IF @MeasureCategory = N'�ɹ����' 
BEGIN
	INSERT INTO #SumValue
	(
		GateNo, 
		CurrSumValue
	)
	SELECT 
		CurrTrans.GateNo GateNo, 
		sum(isnull(CurrTrans.SumSucceedAmount, 0)) CurrSumValue
	FROM 
		#CurrTrans CurrTrans
	GROUP BY 
		GateNo 
END 
ELSE 
BEGIN
	INSERT INTO #SumValue
	(
		GateNo, 
		CurrSumValue
	)
	SELECT 
		CurrTrans.GateNo GateNo, 
		sum(isnull(CurrTrans.SumSucceedCount, 0)) CurrSumValue
	FROM 
		#CurrTrans CurrTrans
	GROUP BY 
		GateNo 
END

--4.2 Add Dimension information to final result
if @ReportCategory = N'��ϸ'
begin
	SELECT TOP (CONVERT(int, @topnum)) 
		(DimGate.BankName + DimGate.GateNo) AS GateNo, 
		SumValue.CurrSumValue
	INTO 
		#TopGate
	FROM 
		#SumValue SumValue 
		INNER JOIN
		DimGate 
		ON 
			SumValue.GateNo = DimGate.GateNo
	ORDER BY 
		SumValue.CurrSumValue DESC;

	 --4.3 Add N'����' record
	SELECT 
		GateNo,
		CurrSumValue
	FROM 
		#TopGate
	UNION ALL
	SELECT 
		N'����' AS GateNo,
		(SELECT isnull(SUM(CurrSumValue), 0) FROM #SumValue) - (SELECT ISNULL(sum(CurrSumValue), 0) FROM #TopGate) AS CurrSumValue;
		
	DROP TABLE #TopGate;
end
else if @ReportCategory = N'����'
begin
	SELECT TOP (CONVERT(int, @topnum)) 
		DimGate.BankName AS GateNo, 
		SUM(SumValue.CurrSumValue) CurrSumValue
	INTO 
		#TopBank
	FROM 
		#SumValue SumValue 
		INNER JOIN
		DimGate 
		ON 
			SumValue.GateNo = DimGate.GateNo
	group by
		DimGate.BankName
	ORDER BY 
		CurrSumValue DESC;

	--4.3 Add N'����' record 
	SELECT 
		GateNo,
		CurrSumValue
	FROM 
		#TopBank
	UNION ALL
	SELECT 
		N'����' AS GateNo,
		(SELECT isnull(SUM(CurrSumValue), 0) FROM #SumValue) - (SELECT ISNULL(sum(CurrSumValue), 0) FROM #TopBank) AS CurrSumValue;
		
	DROP TABLE #TopBank;
end

--5 Clear all temp tables
DROP TABLE #SumValue; 
DROP TABLE #CurrTrans;

End