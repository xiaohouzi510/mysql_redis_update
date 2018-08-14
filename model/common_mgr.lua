local common_mgr = {}

function common_mgr:table_format(t,index,fun_write,max_depth)
	for k,v in pairs(t) do
		if type(v) == "table" and index + 1 < max_depth then
			fun_write(string.rep(" ",index*2)..tostring(k).." {\n")
			self:table_format(v,index+1,fun_write,max_depth)
			fun_write(string.rep(" ",index*2).."}\n")
		else
			fun_write(string.rep(" ",index*2)..tostring(k).." = "..tostring(v).."\n")
		end
	end
end

--table转成字符串
function common_mgr:table_to_string(t,max_depth)
	max_depth = max_depth or 3
	local out_list  = {};
	local fun_write = function(value)
		out_list[#out_list+1] = value;
	end
	self:table_format(t,0,fun_write,max_depth);
	return table.concat(out_list);
end

--读文件
function common_mgr:read_file(file_name)
	local file,status = io.open(file_name,"r")
	if not file then
		g_global.m_log:error(string.format("read file=%s error=%s",file_name,status))
		return false
	end
	local str = file:read("*a")
	file:close()
	return str
end

--执行命令并且返回结果
function common_mgr:popen_cmd(cmd_str)
	local file,status = io.popen(cmd_str)
	if not file then
		g_global.m_log:error(string.format("popen cmd=%s error=%s",cms_str,status))
		return false
	end
	local result = {}
	local str = file:read("*a"):sub(1,-2)
	for word in string.gmatch(str,"[^\r\n]+") do
		table.insert(result,word)
	end
	return result 
end

return common_mgr