--1. ʱ��α�
create table #DateRange
(
	sd date,
	ed date
);

insert into #DateRange
(
	sd,
	ed
)
values
(
	'2012-07-01',
	'2013-10-01'
);

--3. �´��ո�ƽ̨ #TraScreenSum
create table #TraCost
(
	MerchantNo char(15),
	ChannelNo char(6),
	TransType varchar(20),
	CPDate date,
	TotalCnt int,
	TotalAmt decimal(15, 2),
	SucceedCnt int,
	SucceedAmt decimal(15,2),
	CalFeeCnt int,
	CalFeeAmt decimal(15,2),
	CalCostCnt int,
	CalCostAmt decimal(15,2),
	FeeAmt decimal(15,2),
	CostAmt decimal(15,2)
);

if not exists(select 1 from #TraCost)
begin
	declare @sd0 date;
	declare @ed0 date;
	set @sd0 = (select sd from #DateRange);
	set @ed0 = (select ed from #DateRange);

	insert into #TraCost
	(
		MerchantNo,
		ChannelNo,
		TransType,
		CPDate,
		TotalCnt,
		TotalAmt,
		SucceedCnt,
		SucceedAmt,
		CalFeeCnt,
		CalFeeAmt,
		CalCostCnt,
		CalCostAmt,
		FeeAmt,
		CostAmt
	)
	exec Proc_CalTraCost
		@sd0,
		@ed0;
end;

select
	CPDate as TransDate,
	MerchantNo,
	ChannelNo as Gate,
	CalFeeAmt as TransAmt,
	CalFeeCnt as TransCnt,
	FeeAmt,
	CostAmt,
	N'Table_TraScreenSum' as Plat,
	case when
		TransType in ('100002', '100005')
	then
		N'����'
	when
		TransType in ('100001', '100004')
	then
		N'����'
	else
		N'��ȷ��'	
	end as Category,
	case when
		TransType in ('100002', '100005')
	then
		12
	when
		TransType in ('100001', '100004')
	then
		14
	else
		-1	
	end as Rn
into
	#TraScreenSum
from
	#TraCost;

--4. �ϴ��� #OraTransSum
create table #OraCost
(
	BankSettingID char(8),    
	MerchantNo char(20),    
	CPDate date,  
	TransCnt int,  
	TransAmt bigint,  
	CostAmt decimal(20,2)  
);

if not exists(select 1 from #OraCost)
begin
	declare @sd1 date;
	declare @ed1 date;
	set @sd1 = (select sd from #DateRange);
	set @ed1 = (select ed from #DateRange);

	insert into #OraCost
	(
		BankSettingID,    
		MerchantNo,    
		CPDate,  
		TransCnt,  
		TransAmt,  
		CostAmt
	)
	exec Proc_CalOraCost 
		@sd1, 
		@ed1, 
		null
end

select
	OraCost.BankSettingID as Gate,    
	OraCost.MerchantNo,    
	OraCost.CPDate as TransDate,  
	OraCost.TransCnt,  
	OraCost.TransAmt,
	isnull(OraCost.TransCnt * Additional.FeeValue, OraFee.FeeAmount) as FeeAmt,
	OraCost.CostAmt,
	N'Table_OraTransSum' as Plat,
	case when
		OraCost.MerchantNo = '606060290000016'
	then
		N'��ҵ����'
	when
		OraCost.MerchantNo not in ('606060290000016','606060290000015')
	then
		N'����'
	else
		N'�Ӵ����ų�'		
	end as Category,
	case when
		OraCost.MerchantNo = '606060290000016'
	then
		13
	when
		OraCost.MerchantNo not in ('606060290000016','606060290000015')
	then
		12
	else
		-2		
	end as Rn
into
	#OraTransSum
from
	#OraCost OraCost
	inner join
	Table_OraTransSum OraFee
	on
		OraCost.BankSettingID = OraFee.BankSettingID
		and
		OraCost.CPDate = OraFee.CPDate
		and
		OraCost.MerchantNo = OraFee.MerchantNo
	left join
	Table_OraAdditionalFeeRule Additional
	on
		OraCost.MerchantNo = Additional.MerchantNo;

--5. Upopֱ�� #UpopliqFeeLiqResult
create table #UpopDirect
(
	GateNo char(4),
	MerchantNo char(20),
	TransDate date,
	CdFlag char(2),
	TransAmt bigint,
	TransCnt int,
	FeeAmt bigint,
	CostAmt decimal(20,2)
);

if not exists(select 1 from #UpopDirect)
begin
	declare @sd2 date;
	declare @ed2 date;
	set @sd2 = (select sd from #DateRange);
	set @ed2 = (select ed from #DateRange);

	insert into #UpopDirect
	(
		GateNo,
		MerchantNo,
		TransDate,
		CdFlag,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt
	)
	exec Proc_CalUpopCost @sd2, @ed2;
end

select
	u.TransDate,
	u.GateNo as Gate,
	u.MerchantNo,
	u.TransCnt,
	u.TransAmt,
	u.FeeAmt,
	u.CostAmt,
	N'Table_UpopliqFeeLiqResult' as Plat,
	case when 
		u.MerchantNo = '802080290000015'
	then
		N'UPOP_������'
	when
		r.CpMerNo in (select MerchantNo from Table_InstuMerInfo where InstuNo = '999920130320153')
	then
		N'UPOP_UPUP-�ֻ�֧��'
	else
		N'UPOP_UPOP-ֱ��'
	end as Category,
	case when 
		u.MerchantNo = '802080290000015'
	then
		8
	when
		r.CpMerNo in (select MerchantNo from Table_InstuMerInfo where InstuNo = '999920130320153')
	then
		7
	else
		6
	end as Rn
into
	#UpopliqFeeLiqResult
from
	#UpopDirect u
	left join
	Table_CpUpopRelation r
	on
		u.MerchantNo = r.UpopMerNo;

--6. ֧����̨ #FeeCalcResult
--6.1 FeeCalcResult������
create table #FeeCalcResult
(
	GateNo char(4),
	MerchantNo Char(20),
	FeeEndDate date,
	TransCnt int,
	TransAmt decimal(20,2),
	CostAmt decimal(20,2),
	FeeAmt decimal(20,2),
	InstuFeeAmt decimal(20,2),
	Plat varchar(40) default('Table_FeeCalcResult'),
	Category nvarchar(40) default(N''),
	Rn int default(-3)
);

if not exists(select 1 from #FeeCalcResult)
begin
	declare @sd3 date;
	declare @ed3 date;
	set @sd3 = (select sd from #DateRange);
	set @ed3 = (select ed from #DateRange);

	insert into #FeeCalcResult
	(
		GateNo,
		MerchantNo,
		FeeEndDate,
		TransCnt,
		TransAmt,
		CostAmt,
		FeeAmt,
		InstuFeeAmt
	)
	exec Proc_CalPaymentCost @sd3,@ed3,null,'on'
end

--6.2 ����Category ����
update
	f
set
	f.Category = N'����',
	f.Rn = 14
from
	#FeeCalcResult f
where
	f.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'����')
	and
	f.Category = N'';

--6.3 ����Category ����������
update
	fcr
set
	fcr.Category = N'����������',
	fcr.Rn = 11
from
	#FeeCalcResult fcr
where
	fcr.GateNo in ('5901','5902')
	and
	fcr.Category = N'';

--6.4 ����Category B2B
update
	fcr
set
	fcr.Category = N'B2B',
	fcr.Rn = 10
from
	#FeeCalcResult fcr
where
	fcr.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'B2B')
	and
	fcr.Category = N'';

--6.5 ����Category Epos
update
	fcr
set
	fcr.Category = N'EPOS',
	fcr.Rn = 9
from
	#FeeCalcResult fcr
where
	fcr.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'EPOS')
	and
	fcr.Category = N'';

--6.6 ����Category UPOP����
update
	fcr
set
	fcr.Category = N'UPOP_UPOP-����',
	fcr.Rn = 5
from
	#FeeCalcResult fcr
where
	fcr.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'UPOP')
	and
	fcr.Category = N'';

--6.7 ����Category ����֧��
update
	fcr
set
	fcr.Category = N'B2C_����֧��',
	fcr.Rn = 4
from
	#FeeCalcResult fcr
where
	fcr.GateNo in ('5601','5602','5603')
	and
	fcr.Category = N'';
	

--6.7 ����Category Ԥ��Ȩ
update
	fcr
set
	fcr.Category = N'B2C_Ԥ��Ȩ',
	fcr.Rn = 3
from
	#FeeCalcResult fcr
where
	fcr.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'MOTO')
	and
	fcr.Category = N'';	

--6.8 ����Category B2C-����
update
	fcr
set
	fcr.Category = N'B2C_B2C-����',
	fcr.Rn = 2
from
	#FeeCalcResult fcr
where
	fcr.MerchantNo in (select MerchantNo from Table_MerInfoExt)
	and
	fcr.Category = N'';

--6.9 ����Category B2C-����
update
	fcr
set
	fcr.Category = N'B2C_B2C-����',
	fcr.Rn = 1
from
	#FeeCalcResult fcr
where
	fcr.Category = N'';
	
--7 FinalResult
With AllTrans as
(
	--select
	--	TransDate,
	--	MerchantNo,
	--	Gate,
	--	TransAmt,
	--	TransCnt,
	--	FeeAmt,
	--	CostAmt,
	--	Plat,
	--	Category,
	--	Rn
	--from
	--	#WestUnion
	--union all
	select
		TransDate,
		MerchantNo,
		Gate,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		Plat,
		Category,
		Rn
	from
		#TraScreenSum
	union all
	select
		TransDate,
		MerchantNo,
		Gate,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		Plat,
		Category,
		Rn
	from	
		#OraTransSum
	union all
	select
		TransDate,
		MerchantNo,
		Gate,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		Plat,
		Category,
		Rn
	from
		#UpopliqFeeLiqResult
	union all
	select
		FeeEndDate as TransDate,
		MerchantNo,
		GateNo as Gate,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt,
		Plat,
		Category,
		Rn
	from
		#FeeCalcResult
),
AllTransWithRange as
(
	select
		*,
		case when
			TransDate >= '2012-07-01'
			and
			TransDate < '2012-10-01'
		then
			N'LastYear'
		when
			TransDate >= '2013-04-01'
			and
			TransDate < '2013-07-01'
		then
			N'Previous'
		when
			TransDate >= '2013-07-01'
			and
			TransDate < '2013-10-01'
		then
			N'Current'
		else
			N'Other'
		end as DateRange			
	from
		AllTrans
	where
		(
			TransDate >= '2012-07-01'
			and
			TransDate < '2012-10-01'
		)
		or
		(
			TransDate >= '2013-04-01'
			and
			TransDate < '2013-10-01'
		)
)
select
	DateRange,
	Rn,
	Category,
	MerchantNo,
	Gate,
	SUM(TransAmt)/10000000000.0 as TransAmt,
	SUM(TransCnt)/10000.0 as TransCnt,
	SUM(FeeAmt)/1000000.0 as FeeAmt,
	SUM(CostAmt)/1000000.0 as CostAmt
into
	#TransByMerGate	
from
	AllTransWithRange
group by
	DateRange,
	Rn,
	Category,
	MerchantNo,
	Gate
order by
	DateRange,
	Rn;

select
	DateRange,
	Rn,
	Category,
	MerchantNo,
	SUM(TransAmt) as TransAmt,
	SUM(TransCnt) as TransCnt,
	SUM(FeeAmt) as FeeAmt,
	SUM(CostAmt) as CostAmt
into
	#TransByMer
from
	#TransByMerGate
group by
	DateRange,
	Rn,
	Category,
	MerchantNo;


--1.1 ��B2C-����֧�����롮B2C-���ڡ�������������Ҫ�̻�����
With CurrB2C_1 as
(	
	select
		Category,
		MerchantNo,
		TransAmt
	from
		#TransByMer
	where
		DateRange = 'Current'
		and
		Category in (N'B2C_����֧��',N'B2C_B2C-����')
),
PrevB2C_1 as
(
	select
		Category,
		MerchantNo,
		TransAmt
	from
		#TransByMer
	where
		DateRange = 'Previous'
		and
		Category in (N'B2C_����֧��',N'B2C_B2C-����')	
)
select
	isnull(c.Category, p.Category) as Category,
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(c.MerchantNo, p.MerchantNo)) as MerchantName,
	isnull(c.TransAmt,0) - isnull(p.TransAmt,0) as IncreaseAmt
from
	CurrB2C_1 c 
	full outer join
	PrevB2C_1 p
	on
		c.Category = p.Category
		and
		c.MerchantNo = p.MerchantNo
order by
	isnull(c.Category,p.Category),
	isnull(c.TransAmt, 0) - ISNULL(p.TransAmt,0) 
desc;

--1.2 ��B2C-���ڡ����ױ��������½���Ҫ�̻�����
With CurrB2C_1 as
(	
	select
		Category,
		MerchantNo,
		TransCnt
	from
		#TransByMer
	where
		DateRange = 'Current'
		and
		Category in (N'B2C_B2C-����')
),
PrevB2C_1 as
(
	select
		Category,
		MerchantNo,
		TransCnt
	from
		#TransByMer
	where
		DateRange = 'Previous'
		and
		Category in (N'B2C_B2C-����')	
)
select
	isnull(c.Category, p.Category) as Category,
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(c.MerchantNo, p.MerchantNo)) as MerchantName,
	isnull(c.TransCnt,0) - isnull(p.TransCnt,0) as IncreaseCnt
from
	CurrB2C_1 c 
	full outer join
	PrevB2C_1 p
	on
		c.Category = p.Category
		and
		c.MerchantNo = p.MerchantNo
order by
	isnull(c.Category,p.Category),
	isnull(c.TransCnt, 0) - ISNULL(p.TransCnt,0);
	
--1.3 ��B2C-���ڡ��롮B2C-����֧����ë����������
With CurrB2C_1 as
(	
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		#TransByMer
	where
		DateRange = 'Current'
		and
		Category in (N'B2C_����֧��',N'B2C_B2C-����')
),
PrevB2C_1 as
(
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		#TransByMer
	where
		DateRange = 'Previous'
		and
		Category in (N'B2C_����֧��',N'B2C_B2C-����')	
)
select
	isnull(c.Category, p.Category) as Category,
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(c.MerchantNo, p.MerchantNo)) as MerchantName,
	isnull(c.Profit,0) - isnull(p.Profit,0) as IncreaseProfit,
	isnull(c.FeeAmt,0) - isnull(p.FeeAmt,0) as IncreaseFee,
	ISNULL(c.CostAmt,0) - ISNULL(p.CostAmt,0) as IncreaseCost
from
	CurrB2C_1 c 
	full outer join
	PrevB2C_1 p
	on
		c.Category = p.Category
		and
		c.MerchantNo = p.MerchantNo
order by
	isnull(c.Category,p.Category),
	isnull(c.Profit, 0) - ISNULL(p.Profit,0) 
desc;

--1.4  ��B2C-���⡯ë���½�����
With CurrB2C_1 as
(	
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		#TransByMer
	where
		DateRange = 'Current'
		and
		Category in (N'B2C_B2C-����')
),
PrevB2C_1 as
(
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		#TransByMer
	where
		DateRange = 'Previous'
		and
		Category in (N'B2C_B2C-����')	
)
select
	isnull(c.Category, p.Category) as Category,
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(c.MerchantNo, p.MerchantNo)) as MerchantName,
	isnull(c.Profit,0) - isnull(p.Profit,0) as IncreaseProfit,
	isnull(c.FeeAmt,0) - isnull(p.FeeAmt,0) as IncreaseFee,
	ISNULL(c.CostAmt,0) - ISNULL(p.CostAmt,0) as IncreaseCost
from
	CurrB2C_1 c 
	full outer join
	PrevB2C_1 p
	on
		c.Category = p.Category
		and
		c.MerchantNo = p.MerchantNo
order by
	isnull(c.Category,p.Category),
	isnull(c.Profit, 0) - ISNULL(p.Profit,0) 
desc;

--2. UPOPҵ��3���Ȼ�����������
With CurrB2C_1 as
(	
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		#TransByMer
	where
		DateRange = 'Current'
		and
		Category in (N'UPOP_UPOP-����',N'UPOP_UPUP-�ֻ�֧��')
),
PrevB2C_1 as
(
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		#TransByMer
	where
		DateRange = 'Previous'
		and
		Category in (N'UPOP_UPOP-����',N'UPOP_UPUP-�ֻ�֧��')	
)
select
	isnull(c.Category, p.Category) as Category,
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(c.MerchantNo, p.MerchantNo)) as MerchantName,
	isnull(c.Profit,0) - isnull(p.Profit,0) as IncreaseProfit,
	isnull(c.FeeAmt,0) - isnull(p.FeeAmt,0) as IncreaseFee,
	ISNULL(c.CostAmt,0) - ISNULL(p.CostAmt,0) as IncreaseCost
from
	CurrB2C_1 c 
	full outer join
	PrevB2C_1 p
	on
		c.Category = p.Category
		and
		c.MerchantNo = p.MerchantNo
order by
	isnull(c.Category,p.Category),
	isnull(c.Profit, 0) - ISNULL(p.Profit,0) 
desc;

select * from Table_UpopliqMerInfo where MerchantNo in ('802310048990565','802310048990595')

--3.1 ������ҵ��������������44.62%
With CurrB2C_1 as
(	
	select
		Category,
		MerchantNo,
		TransAmt
	from
		#TransByMer
	where
		DateRange = 'Current'
		and
		Category in (N'EPOS')
),
PrevB2C_1 as
(
	select
		Category,
		MerchantNo,
		TransAmt
	from
		#TransByMer
	where
		DateRange = 'Previous'
		and
		Category in (N'EPOS')	
)
select
	isnull(c.Category, p.Category) as Category,
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(c.MerchantNo, p.MerchantNo)) as MerchantName,
	isnull(c.TransAmt,0) - isnull(p.TransAmt,0) as IncreaseAmt
from
	CurrB2C_1 c 
	full outer join
	PrevB2C_1 p
	on
		c.Category = p.Category
		and
		c.MerchantNo = p.MerchantNo
order by
	isnull(c.Category,p.Category),
	isnull(c.TransAmt, 0) - ISNULL(p.TransAmt,0) 
desc;

--3.2 ������ҵ��ë�������½�-3.74%
With CurrB2C as
(	
	select
		Category,
		MerchantNo,
		case when 
			MerchantNo = '808080201301936' 
		then
			TransCnt * 50.0 / 10000.0
		else
			FeeAmt
		end as FeeAmt,
		CostAmt
	from
		#TransByMer
	where
		DateRange = 'Current'
		and
		Category in (N'EPOS')
),
CurrB2C_1 as
(
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		CurrB2C
),
PrevB2C_1 as
(
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		#TransByMer
	where
		DateRange = 'Previous'
		and
		Category in (N'EPOS')	
)
select
	isnull(c.Category, p.Category) as Category,
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(c.MerchantNo, p.MerchantNo)) as MerchantName,
	isnull(c.Profit,0) - isnull(p.Profit,0) as IncreaseProfit,
	isnull(c.FeeAmt,0) - isnull(p.FeeAmt,0) as IncreaseFee,
	ISNULL(c.CostAmt,0) - ISNULL(p.CostAmt,0) as IncreaseCost
from
	CurrB2C_1 c 
	full outer join
	PrevB2C_1 p
	on
		c.Category = p.Category
		and
		c.MerchantNo = p.MerchantNo
order by
	isnull(c.Category,p.Category),
	isnull(c.Profit, 0) - ISNULL(p.Profit,0) 
desc;

--4.1 B2Bҵ��������������38.14%
With CurrB2C_1 as
(	
	select
		Category,
		MerchantNo,
		TransAmt
	from
		#TransByMer
	where
		DateRange = 'Current'
		and
		Category in (N'B2B')
),
PrevB2C_1 as
(
	select
		Category,
		MerchantNo,
		TransAmt
	from
		#TransByMer
	where
		DateRange = 'Previous'
		and
		Category in (N'B2B')	
)
select
	isnull(c.Category, p.Category) as Category,
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(c.MerchantNo, p.MerchantNo)) as MerchantName,
	isnull(c.TransAmt,0) - isnull(p.TransAmt,0) as IncreaseAmt
	--SUM(isnull(c.TransAmt,0) - isnull(p.TransAmt,0))
from
	CurrB2C_1 c 
	full outer join
	PrevB2C_1 p
	on
		c.Category = p.Category
		and
		c.MerchantNo = p.MerchantNo
order by
	isnull(c.Category,p.Category),
	isnull(c.TransAmt, 0) - ISNULL(p.TransAmt,0) 
desc;

--4.2 B2Bë����������45.87%
With CurrB2C_1 as
(	
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		#TransByMer
	where
		DateRange = 'Current'
		and
		Category in (N'B2B')
),
PrevB2C_1 as
(
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		#TransByMer
	where
		DateRange = 'Previous'
		and
		Category in (N'B2B')	
)
select
	isnull(c.Category, p.Category) as Category,
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(c.MerchantNo, p.MerchantNo)) as MerchantName,
	isnull(c.Profit,0) - isnull(p.Profit,0) as IncreaseProfit,
	isnull(c.FeeAmt,0) - isnull(p.FeeAmt,0) as IncreaseFee,
	ISNULL(c.CostAmt,0) - ISNULL(p.CostAmt,0) as IncreaseCost
from
	CurrB2C_1 c 
	full outer join
	PrevB2C_1 p
	on
		c.Category = p.Category
		and
		c.MerchantNo = p.MerchantNo
order by
	isnull(c.Category,p.Category),
	isnull(c.Profit, 0) - ISNULL(p.Profit,0) 
desc;

--5.1 ����ҵ���ױ�������85.77���
With CurrB2C_1 as
(	
	select
		Category,
		MerchantNo,
		TransCnt
	from
		#TransByMer
	where
		DateRange = 'Current'
		and
		Category in (N'����')
),
PrevB2C_1 as
(
	select
		Category,
		MerchantNo,
		TransCnt
	from
		#TransByMer
	where
		DateRange = 'Previous'
		and
		Category in (N'����')	
)
select
	isnull(c.Category, p.Category) as Category,
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(c.MerchantNo, p.MerchantNo)) as MerchantName,
	isnull(c.TransCnt,0) - isnull(p.TransCnt,0) as IncreaseCnt
from
	CurrB2C_1 c 
	full outer join
	PrevB2C_1 p
	on
		c.Category = p.Category
		and
		c.MerchantNo = p.MerchantNo
order by
	isnull(c.Category,p.Category),
	isnull(c.TransCnt, 0) - ISNULL(p.TransCnt,0) 
desc

--5.2 ����ҵ��ë����������28.07%
With CurrB2C_1 as
(	
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		#TransByMer
	where
		DateRange = 'Current'
		and
		Category in (N'����')
),
PrevB2C_1 as
(
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		#TransByMer
	where
		DateRange = 'Previous'
		and
		Category in (N'����')	
)
select
	isnull(c.Category, p.Category) as Category,
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(c.MerchantNo, p.MerchantNo)) as MerchantName,
	isnull(c.Profit,0) - isnull(p.Profit,0) as IncreaseProfit,
	isnull(c.FeeAmt,0) - isnull(p.FeeAmt,0) as IncreaseFee,
	ISNULL(c.CostAmt,0) - ISNULL(p.CostAmt,0) as IncreaseCost
from
	CurrB2C_1 c 
	full outer join
	PrevB2C_1 p
	on
		c.Category = p.Category
		and
		c.MerchantNo = p.MerchantNo
order by
	isnull(c.Category,p.Category),
	isnull(c.Profit, 0) - ISNULL(p.Profit,0) 
desc;

--6.1 �������ҵ���ױ�����������11.48���
With CurrB2C_1 as
(	
	select
		Category,
		MerchantNo,
		TransCnt
	from
		#TransByMer
	where
		DateRange = 'Current'
		and
		Category in (N'����')
),
PrevB2C_1 as
(
	select
		Category,
		MerchantNo,
		TransCnt
	from
		#TransByMer
	where
		DateRange = 'Previous'
		and
		Category in (N'����')	
)
select
	isnull(c.Category, p.Category) as Category,
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(c.MerchantNo, p.MerchantNo)) as MerchantName,
	isnull(c.TransCnt,0) - isnull(p.TransCnt,0) as IncreaseCnt
	--sum(isnull(c.TransCnt,0) - isnull(p.TransCnt,0))
from
	CurrB2C_1 c 
	full outer join
	PrevB2C_1 p
	on
		c.Category = p.Category
		and
		c.MerchantNo = p.MerchantNo
order by
	isnull(c.Category,p.Category),
	isnull(c.TransCnt, 0) - ISNULL(p.TransCnt,0) 
desc

--6.2 �������ҵ��ë��΢��-0.55��Ԫ
With CurrB2C_1 as
(	
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		#TransByMer
	where
		DateRange = 'Current'
		and
		Category in (N'����')
),
PrevB2C_1 as
(
	select
		Category,
		MerchantNo,
		FeeAmt,
		CostAmt,
		FeeAmt - CostAmt as Profit
	from
		#TransByMer
	where
		DateRange = 'Previous'
		and
		Category in (N'����')	
)
select
	isnull(c.Category, p.Category) as Category,
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	(select MerchantName from Table_MerInfo where MerchantNo = isnull(c.MerchantNo, p.MerchantNo)) as MerchantName,
	isnull(c.Profit,0) - isnull(p.Profit,0) as IncreaseProfit,
	isnull(c.FeeAmt,0) - isnull(p.FeeAmt,0) as IncreaseFee,
	ISNULL(c.CostAmt,0) - ISNULL(p.CostAmt,0) as IncreaseCost
from
	CurrB2C_1 c 
	full outer join
	PrevB2C_1 p
	on
		c.Category = p.Category
		and
		c.MerchantNo = p.MerchantNo
order by
	isnull(c.Category,p.Category),
	isnull(c.Profit, 0) - ISNULL(p.Profit,0) 
desc;


-------------------
With SAAP_Mer_Prev as
(
	select
		*,
		FeeAmt - CostAmt as ProfitAmt
	from
		#TransByMer
	where
		DateRange in ('Previous')
		and
		MerchantNo = '808080062104878'
		and
		Category = N'B2C_B2C-����'
),
SAAP_Mer_Curr as
(
	select
		*,
		FeeAmt - CostAmt as ProfitAmt
	from
		#TransByMer
	where
		DateRange in ('Current')
		and
		MerchantNo = '808080062104878'
		and
		Category = N'B2C_B2C-����'
)
select
	c.Category,
	c.MerchantNo,
	c.TransAmt - p.TransAmt as IncreaseAmt,
	c.TransCnt - p.TransCnt as IncreaseCnt,
	c.FeeAmt - p.FeeAmt as IncreaseFee,
	c.CostAmt - p.CostAmt as IncreaseCost,
	c.ProfitAmt - p.ProfitAmt as IncreaseProfit
from
	SAAP_Mer_Prev p
	full outer join
	SAAP_Mer_Curr c
	on
		p.MerchantNo = c.MerchantNo;


	
With SAAP_Mer_Gate_Prev as
(
	select
		*,
		FeeAmt - CostAmt as ProfitAmt
	from
		#TransByMerGate
	where
		DateRange in ('Previous')
		and
		MerchantNo = '808080062104878'
		and
		Category = N'B2C_B2C-����'
),
SAAP_Mer_Gate_Curr as
(
	select
		*,
		FeeAmt - CostAmt as ProfitAmt
	from
		#TransByMerGate
	where
		DateRange in ('Current')
		and
		MerchantNo = '808080062104878'
		and
		Category = N'B2C_B2C-����'
)
select
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	ISNULL(c.Gate, p.Gate) as GateNo,
	isnull(c.TransAmt, 0) - isnull(p.TransAmt, 0) as IncreaseAmt,
	isnull(c.TransCnt, 0) - isnull(p.TransCnt, 0) as IncreaseCnt,
	isnull(c.FeeAmt, 0) - isnull(p.FeeAmt, 0) as IncreaseFee,
	isnull(c.CostAmt, 0) - isnull(p.CostAmt, 0) as IncreaseCost,
	isnull(c.ProfitAmt, 0) - isnull(p.ProfitAmt, 0) as IncreaseProfit
from
	SAAP_Mer_Gate_Prev p
	full outer join
	SAAP_Mer_Gate_Curr c
	on
		p.MerchantNo = c.MerchantNo
		and
		p.Gate = c.Gate
order by
	IncreaseProfit;


-------------------------------
With SAAP_Mer_Prev as
(
	select
		*,
		FeeAmt - CostAmt as ProfitAmt
	from
		#TransByMer
	where
		DateRange in ('Previous')
		and
		MerchantNo = '808080051901999'
		and
		Category = N'B2C_B2C-����'
),
SAAP_Mer_Curr as
(
	select
		*,
		FeeAmt - CostAmt as ProfitAmt
	from
		#TransByMer
	where
		DateRange in ('Current')
		and
		MerchantNo = '808080051901999'
		and
		Category = N'B2C_B2C-����'
)
select
	c.Category,
	c.MerchantNo,
	c.TransAmt - p.TransAmt as IncreaseAmt,
	c.TransCnt - p.TransCnt as IncreaseCnt,
	c.FeeAmt - p.FeeAmt as IncreaseFee,
	c.CostAmt - p.CostAmt as IncreaseCost,
	c.ProfitAmt - p.ProfitAmt as IncreaseProfit
from
	SAAP_Mer_Prev p
	full outer join
	SAAP_Mer_Curr c
	on
		p.MerchantNo = c.MerchantNo;


	
With SAAP_Mer_Gate_Prev as
(
	select
		*,
		FeeAmt - CostAmt as ProfitAmt
	from
		#TransByMerGate
	where
		DateRange in ('Previous')
		and
		MerchantNo = '808080051901999'
		and
		Category = N'B2C_B2C-����'
),
SAAP_Mer_Gate_Curr as
(
	select
		*,
		FeeAmt - CostAmt as ProfitAmt
	from
		#TransByMerGate
	where
		DateRange in ('Current')
		and
		MerchantNo = '808080051901999'
		and
		Category = N'B2C_B2C-����'
)
select
	isnull(c.MerchantNo, p.MerchantNo) as MerchantNo,
	ISNULL(c.Gate, p.Gate) as GateNo,
	isnull(c.TransAmt, 0) - isnull(p.TransAmt, 0) as IncreaseAmt,
	isnull(c.TransCnt, 0) - isnull(p.TransCnt, 0) as IncreaseCnt,
	isnull(c.FeeAmt, 0) - isnull(p.FeeAmt, 0) as IncreaseFee,
	isnull(c.CostAmt, 0) - isnull(p.CostAmt, 0) as IncreaseCost,
	isnull(c.ProfitAmt, 0) - isnull(p.ProfitAmt, 0) as IncreaseProfit
from
	SAAP_Mer_Gate_Prev p
	full outer join
	SAAP_Mer_Gate_Curr c
	on
		p.MerchantNo = c.MerchantNo
		and
		p.Gate = c.Gate
order by
	IncreaseProfit;



	select
		*,
		FeeAmt/(TransAmt*10000.0) as FeeRate,
		CostAmt/(TransAmt*10000.0) as CostRate,
		FeeAmt - CostAmt as ProfitAmt
	from
		#TransByMerGate
	where
		DateRange in ('Current')
		and
		MerchantNo = '808080051901999'
		and
		Category = N'B2C_B2C-����'
		and
		Gate in ('0025','1010','4008')


	

	

drop table #TransByMer;