local redis = require("redis")
local redis_obj = {}

--创建一个对象
function redis_obj.new()
	local res = setmetatable({},{__index=redis_obj})
	res.m_connect    = nil
	res.m_json_array = nil
	return res
end

--执行函数方法
function redis_obj:execute(fun_name,...)
	local fun = self.m_connect[fun_name]
	if not fun then
		g_global.m_log:error("not found fun=%s",fun_name)
		return false
	end
	while true do
		local status,res = pcall(fun,self.m_connect,...)
		if not status then
			if not self:deal_reconnect(res) then
				return false,res
			end
		else
			return true,res
		end
	end
end

--初始化函数
function redis_obj:init(json_array)
	self.m_json_array = json_array	
	if not self:connect(json_array) then
		return false
	end
	return true
end

--连接
function redis_obj:connect(json_array)
	local host = json_array.host
	local port = json_array.port
	local obj,status = redis.connect(host,port)
	if not obj then
		g_global.m_log:error("redis connect error=%s host=%s port=%s",status,host,port)
		return false
	end
	self.m_connect = obj
	if json_array.auth and json_array.auth ~= "" then
		local res,status = self:execute("auth",json_array.auth)
		if not res then
			g_global.m_log:error("redis auth error=%s host=%s port=%s auth=%s",status,host,port,json_array.auth)
			return false
		end 
	end
	return obj
end

--重连
function redis_obj:deal_reconnect(str)
	if not str then
		return false 
	end
	--有 closed 表示已关闭
	local start_index,end_index = string.find(str,"closed")
	if not start_index then
		return false
	end
	if not self:connect(self.m_json_array) then 
		g_global.m_log:error("redis reconnect error str=%s",str)
		return false
	end
	return true
end

return redis_obj