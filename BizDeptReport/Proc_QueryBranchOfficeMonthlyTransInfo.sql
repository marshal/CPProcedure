if OBJECT_ID(N'Proc_QueryBranchOfficeMonthlyTransInfo',N'P') is not null
begin
	drop procedure Proc_QueryBranchOfficeMonthlyTransInfo;
end
go

Create Procedure Proc_QueryBranchOfficeMonthlyTransInfo
	@StartDate datetime = '2011-07-14',
	@PeriodUnit nChar(3) = N'��',
	@BranchOfficeName nChar(15) = N'�����������޹�˾���շֹ�˾'
as 
begin

--1. Check Input
if (@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or ISNULL(@BranchOfficeName,N'') = N'')
begin
	raiserror(N'Input params cannot be empty in Proc_QueryBranchOfficeMonthlyTransInfo',16,1);
end


--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
declare @ThisYearStartDate datetime;
declare @ThisYearEndDate datetime;

if(@PeriodUnit = N'��')
begin
	set @CurrStartDate = left(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(MONTH,1,@CurrStartDate);
end
else if(@PeriodUnit = N'����')
begin
	set @CurrStartDate = left(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(QUARTER,1,@CurrStartDate);
end
else if(@PeriodUnit = N'����')
begin
	set @CurrStartDate = left(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(QUARTER,2,@CurrStartDate);
end

set @ThisYearStartDate = CONVERT(char(4),YEAR(@CurrStartDate)) + '-01-01';
set @ThisYearEndDate = @CurrEndDate;


--3. Get ThisYear Data
select
	MerchantNo,
	TransAmount,
	CPDate as TransDate 
into
	#OraTransSum
from
	Table_OraTransSum
where
	CPDate >= @ThisYearStartDate
	and
	CPDate < @ThisYearEndDate;
	
select 
	MerchantNo,
	SucceedTransAmount as TransAmount,
	DailyTransDate as TransDate
into
	#FactDailyTrans
from
	FactDailyTrans
where
	DailyTransDate >= @ThisYearStartDate
	and
	DailyTransDate < @ThisYearEndDate;
	
select 
	MerchantNo,
	SucceedTransAmount as TransAmount,
	TransDate
into 
	#EmallTransSum
from	
	Table_EmallTransSum
where 
	TransDate >= @ThisYearStartDate
	and
	TransDate < @ThisYearEndDate
	and
	BranchOffice = @BranchOfficeName;
	
--4. Union all data
select
	MerchantNo,
	TransAmount,
	TransDate
into 
	#AllMerTrans	
from
	#OraTransSum	
union all
select 
	MerchantNo,
	TransAmount,
	TransDate
from
	#FactDailyTrans;	

		
--5. Get table MerWithBranchOffice
select
	SalesDeptConfiguration.MerchantNo
into
	#MerWithBranchOffice
from
	Table_BranchOfficeNameMapping BranchOfficeNameMapping 
	inner join
	Table_SalesDeptConfiguration SalesDeptConfiguration
	on
		BranchOfficeNameMapping.OrigBranchOffice = SalesDeptConfiguration.BranchOffice
where

--6. Get AllMerTransWithBo
select
	AllMerTrans.MerchantNo,
	AllMerTrans.TransAmount,
	AllMerTrans.TransDate
into
	#AllMerTransWithBo
from
	#AllMerTrans AllMerTrans
	inner join
	#MerWithBranchOffice MerWithBranchOffice
	on
		AllMerTrans.MerchantNo = MerWithBranchOffice.MerchantNo
union all
select
	MerchantNo,
	TransAmount,
	TransDate
from
	#EmallTransSum;

--7.1 Create temp time period table