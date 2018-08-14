local log_file = {}

--初始化
function log_file:init(file_name)
	if self.m_file then
		self.m_file:close()
	end
	self.m_file_name  = file_name 
	local file,status = io.open(file_name,"a")
	if not file then
		print(string.format("open log file=%s error=%s",file_name,status))
		return false
	end
	self.m_file = file
	return true
end

--获得前缀信息
function log_file:get_prefix(mod)
	local time_date = os.date("%Y-%m-%d %H:%M:%S",os.time())
	local info = debug.getinfo(4,"nSl")	
	return string.format("[%s] %s|%s:%d|%s| ",time_date,mod,info.short_src,info.currentline,tostring(info.name))
end

--错误日志
function log_file:error(format,...) 
	self:log("ERROR",format,...)
end

--debug 日志
function log_file:debug(format,...)
	self:log("DEBUG",format,...)
end

--警告日志
function log_file:warn(format,...) 
	self:log("WARN",format,...)
end

function log_file:log(mod,format,...)
	local prefix = self:get_prefix(mod)
	--先写前缀
	local status = self.m_file:write(prefix)	
	--成功后再写 log
	if status then
		local str = string.format(format,...)
		print(prefix..str)
		self.m_file:write(str)
		self.m_file:write("\n")
	end
	if not status then
		self:init(self.m_file_name)
	end
end

return log_file