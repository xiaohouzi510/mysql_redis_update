local mysql_obj = {}

--创建一个对象
function mysql_obj.new(env)
	local res = setmetatable({},{__index=mysql_obj})
	res.m_connect    = nil
	res.m_json_array = nil
	res.m_env 	     = env
	return res
end

--初始化函数
function mysql_obj:init(json_array)
	self.m_json_array = json_array 
	if not self.m_env then
		return false
	end
	self.m_connect = self:connect(json_array)
	if not self.m_connect then
		return false
	end
	return true
end 

--连接
function mysql_obj:connect(json_array)
	local host = json_array.host	
	local user = json_array.user
	local port = json_array.port
	local pwd  = json_array.pwd or ""
	local db   = json_array.db
	local obj,status = self.m_env:connect(db,user,pwd,host,port)
	if not obj then
		g_global.m_log:error("connect mysql error=%s host=%s user=%s port=%s pwd=%s db=%s",status,host,user,port,pwd,db)
		return false
	end
	return obj
end

--执行
function mysql_obj:execeute(sql)
	while true do
		local record,status = self.m_connect:execute(sql)
		if not record then
			--执行失败，处理重连
			if not self:deal_reconnect(status) then
				g_global.m_log:error("execute error=%s sql=%s"),status,tostring(sql)
				return false	
			end
		else
			return record	
		end
	end
	return 
end

--重连
function mysql_obj:deal_reconnect(str)
	--有 closed 表示已关闭
	local start_index,end_index = string.find(str,"closed")
	if start_index then
		return false
	end
	if not self:init(self.m_json_array) then 
		g_global.m_log:error("mysql reconnect error str=%s",str)
		return false
	end
	return true
end

--关闭
function mysql_obj:close()
	if not self.m_connect then
		return
	end 
	return self.m_connect:close()
end

return mysql_obj