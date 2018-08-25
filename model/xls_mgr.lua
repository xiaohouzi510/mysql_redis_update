local xls_mgr = {}

--初始化函数
function xls_mgr:init()
	self.m_conf_list = {
		{"ShenShouBase","ID"},
		{"RoleBaseAttr",self.base_att_key},
		{"SystemEquip","ID"},
		{"AttrGroup","AttrGroupID"},
		{"AttrRange","AttrRangeID"},
		{"AttrFighting",self.system_equip_key},
		{"LingShi","ID"},
		{"StrengthenConf",self.strengthen_key},
		{"ExtraStrengthenAdd",self.extra_streng_key},
		{"LingShiGrade",self.lingshi_grade_key},
		{"ExpUpgrade","Grade"},
		{"SkillFighting","SkillPointLv"},
		{"ShenShouStar","ID","Star","StarLevel"},
		{"BeastStrengthenConfig","AttrID","StrengthenLevel"},
		{"ShenShouBaseAttr","ID"},
		{"ShenShouLevel","Level"},
		{"ShenShouSkills","ShenShouSkillID"},
		{"HonorConfig",self.honor_key},
		{"OutWardConf","OutWardID"},
		{"BeastExtraStrengthenAdd","ID","Weapon"},
		{"RechargePoint","Id"},
	}
	self.m_list = {}
	self.m_hash = {}
	return self:read_xls()
end

--左移
function xls_mgr:left_move(num,n)
	for i = 1,n do
		num = num*2
	end
	return num
end

--右移
function xls_mgr:right_move(num,n)
	for i = 1,n do
		num = num/2
	end
	return num
end
 
--玩家基础属性 key 
function xls_mgr:base_att_key(one_row)
	return self:left_move(one_row.level,8) + one_row.Weapon
end

--系统装备 key
function xls_mgr:system_equip_key(one_row)
	return one_row.LevelRange*100 + one_row.EquipTypeID
end

--强化部位 key
function xls_mgr:strengthen_key(one_row)
	return self:left_move(one_row.Position,16) + one_row.StrengthenLevel
end

--灵石等级 key 
function xls_mgr:lingshi_grade_key(one_row)
	return one_row.ID*10 + one_row.Weapon
end

--额外强化 key
function xls_mgr:extra_streng_key(one_row)
	return one_row.ID*10 + one_row.Weapon
end

--头衔战斗力 key
function xls_mgr:honor_key(one_row)
	return self:left_move(one_row.ID,8) + one_row.Weapon
end

--读取 excel 表
function xls_mgr:read_xls()
	local data_prefix = g_global.m_common_def.single_conf.data_prefix
	for _,v in ipairs(self.m_conf_list) do
		local sheet 	  = v[1]
		local lower_sheet = string.lower(sheet)
		local data_file   = data_prefix .. lower_sheet ..".data" 
		local array       = sheet .. "Array"
		local file,status = io.open(data_file,"rb")
		if not file then
			g_global.m_log:error("read file=%s error=%s",data_file,status)
			return false
		end
		local data = file:read("*a")
		local array_obj = _G[array]()
		array_obj:ParseFromString(data)
		file:close()
		self.m_list[lower_sheet] = {}
		self.m_hash[lower_sheet] = {}
		for _,one_row in ipairs(array_obj.items) do
			local key    = nil 
			local value  = nil
			local result = self.m_hash[lower_sheet]
			for i = 2,#v do
				key = v[i]
				if type(key) == "function" then
					value = key(self,one_row)
				else
					value = one_row[key] 
				end
				assert(value,string.format("%s %s",tostring(key),lower_sheet))
				if i == #v then
					result[value] = one_row	
				else
					if not result[value] then
						local temp = {}
						result[value] = temp
						result = temp
					else
						result = result[value]
					end
				end
			end
			table.insert(self.m_list[lower_sheet],one_row)
		end
	end
	return true
end

--根据表名和键获得一行
function xls_mgr:get_row(sheet,...)
	sheet = string.lower(sheet)
	local one_table = self.m_hash[sheet]
	if not one_table then 
		return 
	end
	local keys   = {...}
	local result = one_table 
	for i=1,#keys do
		local key = keys[i]
		if not result[key] then
			return 
		end
		if i == #keys then
			return result[key] 
		else
			result = result[key]
		end
	end
	return 
end

--根据表名获得表数据
function xls_mgr:get_table(sheet)
	sheet = string.lower(sheet)
	return self.m_list[sheet]
end

return xls_mgr