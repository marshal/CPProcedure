--[Modified] At 20120308 By Ҷ��:�޸ĵ��õ��Ӵ洢��������ͳһ��λ
--[Modified] At 20120528 By ������:��ϵ��õ��Ӵ洢��������Ӧ�޸�
if OBJECT_ID(N'Proc_QueryIndustryProfitCalc',N'P') is not null
begin
	drop procedure Proc_QueryIndustryProfitCalc;
end
go

create procedure Proc_QueryIndustryProfitCalc
	@StartDate datetime = '2011-10-01',
	@PeriodUnit nChar(3) = N'��',
	@EndDate datetime = '2011-10-31'
as
begin


--1 Check Input
if(@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or (@PeriodUnit = N'�Զ���' and @EndDate is null))
begin
	raiserror(N'Input params be empty in Proc_QueryIndustryProfitCalc',16,1);
end


--2.Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;

if(@PeriodUnit = N'��')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(WEEK,1,@StartDate);
end
else if(@PeriodUnit = N'��')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(MONTH,1,@StartDate);
end
else if(@PeriodUnit = N'����')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER,1,@StartDate);
end
else if(@PeriodUnit = N'����')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER,2,@StartDate);
end
else if(@PeriodUnit = N'��')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(YEAR,1,@StartDate);
end
else if(@PeriodUnit = N'�Զ���')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(DAY,1,@EndDate);
end


--2. Get Period Data

--2.1 Get CurrentData
create table #Curr
(
	GateNo char(4) not null,
	MerchantNo char(20) not null,
	FeeEndDate datetime not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4),
	FeeAmt decimal(15,2) not null,
	InstuFeeAmt decimal(15,2) not null
);

insert into 
	#Curr 
exec
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate;
	

--3.Fetch SumAmt by All MerchantNo
With FeeCalcResult as
(
	select
		MerchantNo,
		SUM(TransSumCount) TransSumCount,
		SUM(TransSumAmount) TransSumAmount,
		SUM(FeeAmt) FeeAmt,
		SUM(Cost) Cost,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		#Curr
	group by
		MerchantNo
)
--4.Get IndustryName and MerchantName of all MerchantNo
select
	ISNULL(Sales.IndustryName,N'δ������ҵ�̻�') IndustryName,
	FeeCalcResult.MerchantNo,
	MerInfo.MerchantName,
	FeeCalcResult.TransSumCount,
	FeeCalcResult.TransSumAmount/100.0 as TransSumAmount,
	FeeCalcResult.FeeAmt/100.0 as FeeAmt,
	FeeCalcResult.Cost/100.0 as Cost,
	FeeCalcResult.InstuFeeAmt/100.0 as InstuFeeAmt
from	
	FeeCalcResult
	left join
	Table_SalesDeptConfiguration Sales
	on
		FeeCalcResult.MerchantNo = Sales.MerchantNo
	left join
	Table_MerInfo MerInfo
	on
		FeeCalcResult.MerchantNo = MerInfo.MerchantNo
order by
	Sales.IndustryName,
	FeeCalcResult.MerchantNo;

--5. Drop Temporary Tables
drop table #Curr;

end