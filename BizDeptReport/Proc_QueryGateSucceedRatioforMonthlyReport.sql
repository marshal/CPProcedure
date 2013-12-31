--[Modified] By ������ 2013-02-04 Description��create Proc_QueryGateSucceedRatioforMonthlyReport
if OBJECT_ID(N'Proc_QueryGateSucceedRatioforMonthlyReport', N'P') is not null
begin
	drop procedure Proc_QueryGateSucceedRatioforMonthlyReport;
end
go

create procedure Proc_QueryGateSucceedRatioforMonthlyReport
	@StartDate datetime = '2011-08-30',
	@PeriodUnit nchar(4)= N'�Զ���',
	@EndDate datetime = '2011-9-30',
	@ReportCategory nchar(4) = N'����'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N''  or (@PeriodUnit = N'�Զ���' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryGateSucceedRatioforMonthlyReport', 16, 1);
end

--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
declare @PrevStartDate datetime;
declare @PrevEndDate datetime;
declare @LastYearStartDate datetime;
declare @LastYearEndDate datetime;

if(@PeriodUnit = N'��')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(week, 1, @StartDate);
    set @PrevStartDate = DATEADD(week, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'��')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(MONTH, 1, @StartDate);
    set @PrevStartDate = DATEADD(MONTH, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'����')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 1, @StartDate);
    set @PrevStartDate = DATEADD(QUARTER, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'����')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 2, @StartDate);
    set @PrevStartDate = DATEADD(QUARTER, -2, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'��')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(YEAR, 1, @StartDate);
    set @PrevStartDate = DATEADD(YEAR, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'�Զ���')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DateAdd(day,1,@EndDate);
    set @PrevStartDate = DATEADD(DAY, -1*datediff(day,@CurrStartDate,@CurrEndDate), @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end

--3. Get Current SucceedCount
select
	GateNo,
	SUM(SucceedTransCount) as CurrSucceedCount,
	SUM(DailyTransCount) as CurrTotalCount,
	SUM(DailyTransCount - SucceedTransCount) as CurrFailedCount
into
	#CurrCount	
from
	FactDailyTrans
where
	DailyTransDate >= @CurrStartDate
	and
	DailyTransDate < @CurrEndDate
group by
	GateNo;
	
--4. Get Previous SucceedCount
select
	GateNo,
	SUM(SucceedTransCount) as PrevSucceedCount,
	SUM(DailyTransCount) as PrevTotalCount,
	SUM(DailyTransCount - SucceedTransCount) as PrevFailedCount
into
	#PrevCount
from
	FactDailyTrans
where
	DailyTransDate >= @PrevStartDate
	and
	DailyTransDate < @PrevEndDate
group by
	GateNo;
	
--5. Get LastYear SucceedCount
select
	GateNo,
	SUM(SucceedTransCount) as LastYearSucceedCount,
	SUM(DailyTransCount) as LastYearTotalCount,
	SUM(DailyTransCount - SucceedTransCount) as LastYearFailedCount
into
	#LastYearCount
from
	FactDailyTrans
where
	DailyTransDate >= @LastYearStartDate
	and
	DailyTransDate < @LastYearEndDate
group by
	GateNo;

--6. Get Total SucceedCount
select
	(select ISNULL(BankName,N'����') from Table_GateCategory where GateNo = GateRoute.GateNo) BankName,
	GateRoute.GateNo,
	ISNULL(CurrCount.CurrSucceedCount, 0) CurrSucceedCount,
	ISNULL(CurrCount.CurrTotalCount, 0) CurrTotalCount,
	ISNULL(CurrCount.CurrFailedCount, 0) CurrFailedCount,
	ISNULL(PrevCount.PrevSucceedCount, 0) PrevSucceedCount,
	ISNULL(PrevCount.PrevTotalCount, 0) PrevTotalCount,
	ISNULL(PrevCount.PrevFailedCount, 0) PrevFailedCount,
	ISNULL(LastYearCount.LastYearSucceedCount, 0) LastYearSucceedCount,
	ISNULL(LastYearCount.LastYearTotalCount, 0) LastYearTotalCount,
	ISNULL(LastYearCount.LastYearFailedCount, 0) LastYearFailedCount
into
	#TotalCount
from
	Table_GateRoute GateRoute
	left join
	Table_GateCategory GateCategory
	on
		GateRoute.GateNo = GateCategory.GateNo 
	left join
	#CurrCount CurrCount
	on
		GateRoute.GateNo = CurrCount.GateNo
	left join
	#PrevCount PrevCount
	on
		GateRoute.GateNo = PrevCount.GateNo
	left join
	#LastYearCount LastYearCount
	on
		GateRoute.GateNo = LastYearCount.GateNo
where
	len(GateRoute.GateNo) = 4 ;
		
--7. Get TotalRatio
select
	ISNULL(BankName,N'����') BankName,
	GateNo,
	CurrSucceedCount,
	CurrTotalCount,
	CurrFailedCount,
	
	PrevSucceedCount,
	PrevTotalCount,
	PrevFailedCount,
	
	LastYearSucceedCount,
	LastYearTotalCount,
	LastYearFailedCount,
	case when CurrTotalCount = 0
		then null
		else CONVERT(decimal, CurrSucceedCount) / CurrTotalCount
	end as CurrSucceedRatio,
	case when CurrTotalCount = 0
		then null
		else CONVERT(decimal, CurrFailedCount) / CurrTotalCount
	end as CurrFailedRatio,
	case when PrevTotalCount = 0
		then null
		else CONVERT(decimal, PrevSucceedCount) / PrevTotalCount
	end as PrevSucceedRatio,
	case when PrevTotalCount = 0
		then null
		else CONVERT(decimal, PrevFailedCount) / PrevTotalCount
	end as PrevFailedRatio,
	case when LastYearTotalCount = 0
		then null
		else CONVERT(decimal, LastYearSucceedCount) / LastYearTotalCount
	end as LastYearSucceedRatio,
	case when LastYearTotalCount = 0
		then null
		else CONVERT(decimal, LastYearFailedCount) / LastYearTotalCount
	end as LastYearFailedRatio
into
	#TotalRatio
from
	#TotalCount;

--8. Get Result
if (@ReportCategory = N'��ϸ')
begin 
	select
		BankName,
		GateNo,
		CurrSucceedCount,
		CurrTotalCount,
		CurrFailedCount,
		
		PrevSucceedCount,
		PrevTotalCount,
		PrevFailedCount,
		
		LastYearSucceedCount,
		LastYearTotalCount,
		LastYearFailedCount,
		
		CurrSucceedRatio,
		CurrFailedRatio,
		
		PrevSucceedRatio,
		PrevFailedRatio,
		
		LastYearSucceedRatio,
		LastYearFailedRatio,
		
		CurrSucceedRatio - PrevSucceedRatio as SucceedSeqIncrease,
		CurrFailedRatio - PrevFailedRatio as FailedSeqIncrease,
		
		CurrSucceedRatio - LastYearSucceedRatio as SucceedYOYIncrease,
		CurrFailedRatio - LastYearFailedRatio as FailedYOYIncrease
	from
		#TotalRatio
	order by
		GateNo;	
end
else if (@ReportCategory = N'����')
begin
	select
		BankName,
		SUM(CurrSucceedCount) CurrSucceedCount,
		SUM(CurrTotalCount) CurrTotalCount,
		SUM(CurrFailedCount) CurrFailedCount,
		
		SUM(PrevSucceedCount) PrevSucceedCount,
		SUM(PrevTotalCount) PrevTotalCount,
		SUM(PrevFailedCount) PrevFailedCount,
		
		SUM(LastYearSucceedCount) LastYearSucceedCount,
		SUM(LastYearTotalCount) LastYearTotalCount,
		SUM(LastYearFailedCount) LastYearFailedCount,
		
		case when SUM(CurrTotalCount) = 0
			then null
			else CONVERT(decimal, SUM(CurrSucceedCount)) / SUM(CurrTotalCount)
		end as CurrSucceedRatio,
		case when SUM(CurrTotalCount) = 0
			then null
			else CONVERT(decimal, SUM(CurrFailedCount)) / SUM(CurrTotalCount)
		end as CurrFailedRatio,
		case when SUM(PrevTotalCount) = 0
			then null
			else CONVERT(decimal, SUM(PrevSucceedCount)) / SUM(PrevTotalCount)
		end as PrevSucceedRatio,
		case when SUM(PrevTotalCount) = 0
			then null
			else CONVERT(decimal, SUM(PrevFailedCount)) / SUM(PrevTotalCount)
		end as PrevFailedRatio,
		case when SUM(LastYearTotalCount) = 0
			then null
			else CONVERT(decimal, SUM(LastYearSucceedCount)) / SUM(LastYearTotalCount)
		end as LastYearSucceedRatio,
		case when SUM(LastYearTotalCount) = 0
			then null
			else CONVERT(decimal, SUM(LastYearFailedCount)) / SUM(LastYearTotalCount)
		end as LastYearFailedRatio	
	INTO
		#TempTotalRatio
	from
		#TotalRatio
	group by 
		BankName;
	
	select
		BankName,
		'0' as GateNo,
		CurrSucceedCount,
		CurrTotalCount,
		CurrFailedCount,
		
		PrevSucceedCount,
		PrevTotalCount,
		PrevFailedCount,
		
		LastYearSucceedCount,
		LastYearTotalCount,
		LastYearFailedCount,
		
		CurrSucceedRatio,
		CurrFailedRatio,
		
		PrevSucceedRatio,
		PrevFailedRatio,
		
		LastYearSucceedRatio,
		LastYearFailedRatio,
		
		CurrSucceedRatio - PrevSucceedRatio as SucceedSeqIncrease,
		CurrFailedRatio - PrevFailedRatio as FailedSeqIncrease,

		
		CurrSucceedRatio - LastYearSucceedRatio as SucceedYOYIncrease,
		CurrFailedRatio - LastYearFailedRatio as FailedYOYIncrease
	from
		#TempTotalRatio;			
end
--9. Clear temp table
drop table #TotalRatio;
drop table #TotalCount;
drop table #LastYearCount;
drop table #PrevCount;
drop table #CurrCount;

end 