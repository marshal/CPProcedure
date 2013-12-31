--Created By ������ 2013-12-17 ��������:���⽻�ײ��
--Input:StartDate��PeriodUnit��EndDate
--Output:�̻���,�̻�����,����,���ױ���,��ҽ��׽��,����ҽ��׽��,���ײ��
if OBJECT_ID(N'Proc_QueryOverseasMerTransDiffReport', N'P') is not null
begin
	drop procedure Proc_QueryOverseasMerTransDiffReport;
end
go

create procedure Proc_QueryOverseasMerTransDiffReport
	@StartDate datetime = '2013-11-01',
	@PeriodUnit nchar(4) = N'��',
	@EndDate datetime = '2013-12-01'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N''  or (@PeriodUnit = N'�Զ���' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryOverseasMerTransDiffReport', 16, 1);
end

--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;

if(@PeriodUnit = N'��')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(WEEK, 1, @StartDate);
end
else if(@PeriodUnit = N'��')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(MONTH, 1, @StartDate);
end
else if(@PeriodUnit = N'����')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 1, @StartDate);
end
else if(@PeriodUnit = N'����')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 2, @StartDate);
end
else if(@PeriodUnit = N'��')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(YEAR, 1, @StartDate);
end
else if(@PeriodUnit = N'�Զ���')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DateAdd(day,1,@EndDate);
end;

--3. Prepare All Data
With PayData as
(
	select
		Mer.MerchantNo,
		Mer.CuryCode,
		SUM(Trans.SucceedTransCount) TransCnt,
		SUM(Trans.SucceedTransAmount)/100.0 OriginTransAmt
	from
		FactDailyTrans Trans
		inner join
		Table_MerInfoExt Mer
		on
			Trans.MerchantNo = Mer.MerchantNo
	where
		Trans.DailyTransDate >= @CurrStartDate
		and
		Trans.DailyTransDate <  @CurrEndDate
	group by
		Mer.MerchantNo,
		Mer.CuryCode
),
CuryRate as
(
	select
		CuryCode,
		AVG(CuryRate) AVGCuryRate 
	from
		Table_CuryFullRate
	where
		CuryDate >= @CurrStartDate
		and
		CuryDate <  @CurrEndDate
	group by
		CuryCode
)
select
	MerInfo.MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = MerInfo.MerchantNo) MerchantName,
	MerInfo.CuryCode,
	ISNULL(PayData.TransCnt,0) TransCnt,
	ISNULL(PayData.OriginTransAmt,0) OriginTransAmt,
	ISNULL(PayData.OriginTransAmt,0) *  ISNULL(CuryRate.AVGCuryRate, 1.0) RMBTransAmt,
	ISNULL(PayData.OriginTransAmt,0) * (ISNULL(CuryRate.AVGCuryRate, 1.0)-1.0) TransDiff
from
	Table_MerInfoExt MerInfo
	left join
	PayData
	on
		MerInfo.MerchantNo = PayData.MerchantNo
	left join
	CuryRate 
	on
		MerInfo.CuryCode = CuryRate.CuryCode
order by
	TransDiff;

End