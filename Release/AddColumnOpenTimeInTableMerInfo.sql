--created by chen wu on 2012-01-12
--add column OpenTime in Table_MerInfo

if not exists (select 
					1 
				from 
					sys.columns 
				where 
					object_id = OBJECT_ID(N'Table_MerInfo', N'U') 
					and 
					name = N'OpenTime')
begin
	alter table Table_MerInfo
	add OpenTime datetime;
end
