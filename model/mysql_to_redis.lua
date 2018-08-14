local mysql_to_redis = {}

--初始化函数
function mysql_to_redis:init()
	self.m_tables    = nil 
	self.m_field_str = nil 
	self.m_per_count = nil 
	self.m_where     = nil 
end

--开始函数
function mysql_to_redis:run(mysql_env,mysql_obj,redis_obj)
	for _,v in ipairs(self.m_tables) do
		local res = self:run_one_table(mysql_obj,redis_obj,v)
		if not res then
			return res	
		end
	end
	return true
end

--执行一个 table
function mysql_to_redis:run_one_table(mysql_obj,redis_obj,table_name)
	local res_obj,status = mysql_obj:execeute(string.format("select count(*) from %s",table_name)) 
	if not res_obj then
		mysql_obj:execeute(string.format("select count error table_name=%s",table_name))
		return false
	end
	local result = res_obj:fetch()
	local all_count = tonumber(result)
	if all_count == 0 then
		return true
	end
	if self.m_per_count > all_count then
		self.m_per_count = all_count
	end
	local start_index = 0
	local end_index   = 0 
	--向上取整
	local count = math.ceil(all_count/self.m_per_count)
	for i=0,count-1 do
		start_index = self.m_per_count*i
		end_index   = start_index + self.m_per_count
		local str = string.format("select %s from %s %s limit %d,%d",self.m_field_str,table_name,self.m_where,start_index,end_index)
		local record_obj,status = mysql_obj:execeute(str)
		if not record_obj then
			local str = string.format("mysql run error=%s table=%s field=%s start_index=%d end_index=%d",status,table_name,self.field_str,start_index,end_index)
			g_global.m_log:error(str)
			return false
		end
		if not self:update(record_obj,mysql_obj,redis_obj) then
			return false
		end
	end
	return true
end

return mysql_to_redis 