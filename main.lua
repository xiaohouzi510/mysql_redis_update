local script_dir  = ...
if not script_dir then
	script_dir = "update_script"
end
local script_path = string.format("%s/?.lua",script_dir) 
local lua_path = {
	"redis/?.lua",
	"model/?.lua",	
	"protobufluaint64/protobuf_lua/?.lua",
	"pblua/cs/?.lua",
	"pblua/common/?.lua",
	"pblua/database/?.lua",
	"pblua/proto/?.lua",
	"pblua/ss/?.lua",
	"pblua/game_third/?.lua",
	script_path,
}
local c_path = {
	"lua-zlib-master/?.so",
	"redis/?.so;",
	"lib/?.so;",
	"protobufluaint64/?.so;",
}
package.path  = table.concat(lua_path,";").. ";" .. package.path
package.cpath = table.concat(c_path,";").. ";" .. package.cpath

local mysql = require("luasql.mysql")
local redis = require('redis')
local cjson = require("cjson")
local mysql_env_model = require("luasql.mysql")
local mysql_model = require("mysql_obj")
local redis_model = require("redis_obj")
require("global")

local redis_json  = nil
local mysql_json  = nil
local pbdir_name  = "pblua"
local script_file = nil
local redis_obj   = nil
local mysql_obj   = nil
local mysql_env   = nil
local log_file    = "log/mysql_to_redis.log" 
local username_file = io.popen("whoami")
g_username = username_file:read("*a"):sub(1,-2)
username_file:close()

--初始化配置
local function init_conf()
	if not g_global.m_log:init(log_file) then
		return false
	end
	if not g_global.m_xls:init() then
		return false
	end
	local env,status = mysql_env_model:mysql() 
	if not env then
		g_global.m_log:error("create mysql env error=%s",status)
		return false
	end
	mysql_env  = env
	redis_json = g_global.m_common_mgr:read_file("json_conf/redis.json")
	if not redis_json then
		return false
	end
	local status,json_table = pcall(cjson.decode,redis_json)
	if not status then
		g_global.m_log:error("json=%s decode redis error=%s",redis_json,json_table)
		return 
	end
	redis_obj  = redis_model.new()
	if not redis_obj:init(json_table) then
		return false
	end 
	mysql_json = g_global.m_common_mgr:read_file("json_conf/mysql.json")
	mysql_json = string.gsub(mysql_json,"${user}",g_username)
	if not mysql_json then
		return false
	end
	status,json_table = pcall(cjson.decode,mysql_json)
	if not status then
		g_global.m_log:error("json=%s decode mysql error=%s",mysql_json,json_table)
		return 
	end
	mysql_obj = mysql_model.new(mysql_env)
	if not mysql_obj:init(json_table) then
		return false
	end
	return true
end

--require 所有 pb 文件
local function require_pb_file()
	local files = g_global.m_common_mgr:popen_cmd(string.format("find %s -type f -name '*.lua'",pbdir_name))
	if not files then
		return false
	end
	for _,v in ipairs(files) do
		local str = string.match(v,"[^/]*\/[^/]*\/([^/]*)\.lua")
		require(str)
	end
	return true 
end

--获取所脚本文件
local function get_all_script()
	if not script_dir then
		g_global.m_log:error("script dir is nil")
		return false
	end
	script_file = g_global.m_common_mgr:popen_cmd(string.format("ls %s/*.lua",script_dir))	
	if not script_file then
		return false
	end
	return true
end

--初始化
local function init()
	if not require_pb_file() then
		return false
	end
	if not init_conf() then
		return false 
	end
	if not get_all_script() then
		return false
	end
	return true
end

--开始 
local function run()
	for _,v in ipairs(script_file) do
		local cur_script = require(v:sub(1,-5))
		cur_script:init()
		if not cur_script:run(mysql_env,mysql_obj,redis_obj) then
			return false
		end
	end
	mysql_obj:close()
	return true
end

if not init() then
	return	
end
if run() then
	g_global.m_log:debug("run success")
	print("run success")
else
	g_global.m_log:error("run fail")
	print("run fail more than see ./log/mysql_to_redis.log")
end