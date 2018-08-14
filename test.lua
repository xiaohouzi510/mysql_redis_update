package.path  = "redis/?.lua;" .. package.path
package.cpath = "redis/?.so;" .. package.cpath
local mysql = require("luasql.mysql")
local evn = mysql:mysql()
if not evn then 
    print("1",evn)
    return
end
function p(t)
	for k,v in pairs(t) do
	    print(k,type(v)..":"..tostring(v))
	end
end
sql_obj,status = evn:connect("test","root1","","127.0.0.1",3306)
if not sql_obj then 
    print(sql_obj,status)
    return
end
--os.execute('sleep ' .. tonumber(600))
sql_obj:execute("set charset utf8")
record,statu = sql_obj:execute("select roleid from student")
-- p(record:getcolnames())
-- p(record:getcoltypes())
-- print(type(record:fetch()))
record:close()
sql_obj:close()
evn:close()

local redis = require('redis')
client = redis.connect("127.0.0.1",6380)
if not client then 
	print(client)
	return
end
res = client:auth("123456")
-- res = client:set("huang","yongde")
str = [[
	for i=1,#KEYS do
		local key   = KEYS[i]	
		local value = ARGV[i]
		redis.call('set',key,value)
	end
	return true
]]
t = {"n1","n2","n3","n4","n5","l1","l2","l3","l4","l5"}
key = {"one","tow","three","1","2","3"}
value = {"1","2","3"}
status,res = pcall(client.eval,client,str,3,unpack(key))
print(status,res)

-- t = {os.execute('whoami')}
-- os.execute('ls')
res = io.popen('find pblua -maxdepth 1 -mindepth 1 -type d')
r = res:read("*a")
res:close()