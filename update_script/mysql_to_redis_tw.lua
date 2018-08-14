local mysql_to_redis = require("mysql_to_redis")
local zlib = require("zlib")
local mysql_to_redis_tw = {}

setmetatable(mysql_to_redis_tw,{__index=mysql_to_redis})

--初始化函数
function mysql_to_redis_tw:init()
	self.m_tables    = {} 
	self.m_field_str = "*" 
	self.m_per_count = 100 
	self.m_where     = ""
	for i=0,63 do
		table.insert(self.m_tables,string.format("DBRoleData_%d",i))
	end
end

--一行转换成 key,value
function mysql_to_redis_tw:convert_key_value(record_obj)
	local result    = {}
	local col_names = record_obj:getcolnames()
	while true do
		local one_record = {record_obj:fetch()}
		if #one_record == 0 then
			break
		end
		for i,field in ipairs(col_names) do
			one_record[field] = one_record[i]
		end
		table.insert(result,one_record)
	end
	return result
end

local username_file = io.popen("whoami")
local username = username_file:read("*a"):sub(1,-2)
username_file:close()

local eval_str = string.format([[
	local rediskey = '%s_RoleData:'
	for i=1,#KEYS do
		local player_id = KEYS[i]
		local value 	= ARGV[i]
		local res = redis.call('hget',rediskey..player_id,'CompareFight') 
		-- if not res then
		redis.call("hset",rediskey..player_id,'CompareFight',value)
		-- end
	end
]],username)

--update 函数
function mysql_to_redis_tw:update(record_obj,mysql_obj,redis_obj)
	local blob_attr_proto = PBBlobAttr() 
	local records 		  = self:convert_key_value(record_obj)
	local keys     = {}
	local values   = {}
	for _,record in ipairs(records) do
		blob_attr_proto:Clear()
		local status,cur_attr = pcall(zlib.inflate(),record["BlobAttr"]:sub(13,-1))
		if not status then
			local str = string.format("zip decode role=%s len=%d error=%s",record["RoleID"],#record["BlobAttr"],cur_attr) 
			g_global.m_log:error(str)
			return false
		end
		blob_attr_proto:ParseFromString(cur_attr:sub(5,-1))
		--mysql 返回 string 类型
		local fight_obj = self:cal_fight(record,blob_attr_proto)
		if not fight_obj then
			return false
		end
		fight_obj.Total = tonumber(record["Fighting"])
		g_global.m_log:debug(tostring(fight_obj))	
		table.insert(keys,record["RoleID"])
		table.insert(values,fight_obj)
	end 
	local result = {}
	for i=1,#keys do
		table.insert(result,keys[i])	
	end
	for i=1,#values do
		table.insert(result,values[i]:SerializeToString())	
	end	
	local status,res = redis_obj:execute("eval",eval_str,#keys,unpack(result))
	if not status then
		g_global.m_log:error(string.format("eval error=%s",res))
		return false
	end
	return true
end

--计算战斗力
function mysql_to_redis_tw:cal_fight(record,blob_attr_proto)
	local fight_proto = CompareFightProtoData()
	local status = self:role_base_fight(record,blob_attr_proto,fight_proto)
	if not status then
		return status
	end
	status = self:role_equip_fight(record,blob_attr_proto,fight_proto)
	if not status then
		return status
	end
	status = self:role_skill_fight(record,blob_attr_proto,fight_proto)
	if not status then
		return status
	end
	status = self:role_beast_fight(record,blob_attr_proto,fight_proto)
	if not status then
		return status
	end
	status = self:get_honor_fight(record,blob_attr_proto,fight_proto)
	if not status then
		return status
	end
	status = self:get_fashion_fight(record,blob_attr_proto,fight_proto)
	if not status then
		return status
	end
	return fight_proto
end

--等级战斗力
function mysql_to_redis_tw:role_base_fight(record,blob_attr_proto,fight_proto)
	--mysql 返回 string 类型
	local grade  = tonumber(record["RoleGrade"])
	local weapon = tonumber(record["Weapon"])
	--grade << 8 | weapon
	local key    = g_global.m_xls:left_move(grade,8) + weapon 
	local config = g_global.m_xls:get_row("RoleBaseAttr",key)
	if not config then
		g_global.m_log:error(string.format("RoleBaseAttr not found config grade=%d weapon=%d",grade,weapon))
		return false
	end
	fight_proto.Level = config.Fighting
	return true
end

--获得装备单个属性的战斗力
function mysql_to_redis_tw:cal_singel_equip_attr_fighting(dwLevelRange,dwEquipTypeID,dwAttrValue)
	local dwSingelEquipAttrFighting = 0
	local key = dwLevelRange * 100 + dwEquipTypeID
	local config = g_global.m_xls:get_row("AttrFighting",key)
	if not config then
		g_global.m_log:error(string.format("AttrFighting not found config key=%d",key))
		return false
	end
	local isGetFighting = false
	for _,v in ipairs(config.RandRangeList) do
		if dwAttrValue >= v.RangeMin and dwAttrValue <= v.RangeMax then
			isGetFighting = true
			dwSingelEquipAttrFighting = v.Fighting
			break
		end
	end
	return isGetFighting,dwSingelEquipAttrFighting
end

--装备战斗力
function mysql_to_redis_tw:role_equip_fight(record,blob_attr_proto,fight_proto)
	--1装备基础战斗力
	local dwEquipBaseFighting          = 0
	--2装备随机属性战斗力
	local dwEquipRandomAttrFighting    = 0
	--3装备强化属性战斗力
	local dwEquipStrengthenFighting    = 0
	--4宝石镶嵌属性战斗力
	local dwEquipLingShiFighting       = 0
	--5强化激活属性战斗力
	local dwStrengthenActivateFighting = 0
	--6镶嵌激活属性战斗力
	local dwLingShiFighting 		   = 0
	for i,equip in ipairs(blob_attr_proto.BlobRoleItemData.EquipList) do
		local equip_conf = g_global.m_xls:get_row("SystemEquip",equip.BaseInfo.ItemNo)
		if not equip_conf then
			g_global.m_log:error(string.format("SystemEquip not found config itemno=%d",equip.BaseInfo.ItemNo))
			return false
		end
		dwEquipBaseFighting = dwEquipBaseFighting + equip_conf.Fighting
		local group_conf    = g_global.m_xls:get_row("AttrGroup",equip_conf.AttrGroupID)	
		if not group_conf then
			g_global.m_log:debug(string.format("AttrGroup not found config id=%d",equip_conf.AttrGroupID))
		else
			local dwAttrRangeID = 0
			for _,equip_attr in ipairs(equip.EquipAttr.Attr) do
				for _,one_attr in ipairs(group_conf.GeneAttrOneList) do 
					if one_attr.AttrID == equip_attr.Type then
						dwAttrRangeID = one_attr.AttrRangeID
						break
					end
				end
				if dwAttrRangeID == 0 then
					for _,one_attr in ipairs(group_conf.GeneAttrTwoList) do 
						if equip_attr.AttrID == equip_attr.Type then
							dwAttrRangeID = equip_attr.AttrRangeID
							break
						end
					end
				end
				if dwAttrRangeID ~= 0 then
					local range_conf = g_global.m_xls:get_row("AttrRange",dwAttrRangeID)
					if not range_conf then
						g_global.m_log:debug(string.format("AttrRange not found config AttrRangeID=%d",dwAttrRangeID))
					else
						if range_conf.AttrMax - range_conf.AttrMin ~= 0 then
							local dBaiFenBi = (equip_attr.Value - range_conf.AttrMin)/(range_conf.AttrMax - range_conf.AttrMin) 
							iBaiFenBi = math.floor(dBaiFenBi*100)
							iBaiFenBi = iBaiFenBi > 0 and iBaiFenBi or 0
							local isGetFighting,fight = self:cal_singel_equip_attr_fighting(equip_conf.LevelRange,equip_conf.EquipTypeID,iBaiFenBi)
							if isGetFighting then
								dwEquipRandomAttrFighting = dwEquipRandomAttrFighting + fight
							end
						end
					end
				end
			end
		end
		--强化
		for _,strengthen in ipairs(blob_attr_proto.PositionStrengInfo.PoitionStreing) do
			if strengthen.PositionID == i then 
				local strengthen_key  = g_global.m_xls:left_move(strengthen.PositionID,16) + strengthen.StrengLevel
				local strengthen_conf = g_global.m_xls:get_row("StrengthenConf",strengthen_key)
				if not strengthen_conf then
					local str = string.format("StrengthenConf not found config position=%d level=%d",strengthen.PositionID,strengthen.StrengLevel)
					g_global.m_log:error(str)
					return false
				end
				dwEquipStrengthenFighting = dwEquipStrengthenFighting + strengthen_conf.Fighting
			end
		end
		--镶嵌
		for _,stone in ipairs(equip.HoleInfo) do
			local stone_conf = g_global.m_xls:get_row("LingShi",stone.FillItemID)
			if not stone_conf then
				g_global.m_log:error(string.format("LingShi not found config id=%d",stone.FillItemID))
				return false
			end
			dwEquipLingShiFighting = dwEquipLingShiFighting + stone_conf.Fighting
		end
	end
	local extraddr_level = blob_attr_proto.PositionStrengInfo.StrengAchieveLevel
	local extraaddr_conf = g_global.m_xls:get_row("ExtraStrengthenAdd",extraddr_level*10 + record["Weapon"])
	if extraaddr_conf then
		dwStrengthenActivateFighting = extraaddr_conf.Fighting
	end 
	
	local lingshigrade_level = blob_attr_proto.PositionStrengInfo.LingShiAchieveLevel
	local lingshigrade_conf  = g_global.m_xls:get_row("LingShiGrade",lingshigrade_level*10 + record["Weapon"])
	if lingshigrade_conf then
		dwLingShiFighting = lingshigrade_conf.Fighting
	end
	local total = dwEquipBaseFighting+dwEquipRandomAttrFighting+dwEquipStrengthenFighting+dwEquipLingShiFighting+dwStrengthenActivateFighting+dwLingShiFighting
	fight_proto.Equip      = total
	fight_proto.Washing    = dwEquipRandomAttrFighting
	fight_proto.StrengThen = dwEquipStrengthenFighting
	fight_proto.LingShi    = dwEquipLingShiFighting
	return true
end

--获得等级所技能点
function mysql_to_redis_tw:get_grade_skill_point(record,blob_attr_proto)
	local result = 0
	for _,v in ipairs(blob_attr_proto.SkillPointItem) do
		result = result + v.PointNum*v.UseCount
	end
	local grade = tonumber(record["RoleGrade"])
	for i=1,grade-1 do
		local config = g_global.m_xls:get_row("ExpUpgrade",i)
		if config then
			result = result + config.Point
		else
			g_global.m_log:error(string.format("ExpUpgrade not found conf id=%d",i))
		end
	end 
	return result
end

--获得剩余技能点
function mysql_to_redis_tw:get_surplus_skill_point(record,blob_attr_proto)
	local project_id  = 0
	local weapon      = tonumber(record["Weapon"])
	for _,v in ipairs(blob_attr_proto.SkillProject.CurProject) do
		if v.WeanponType == weapon then
			project_id = v.CurProjectNum
			break
		end
	end
	local surplus_point = 0
	local cur_project = blob_attr_proto.SkillProject.SkillProjectDetailData[project_id]
	for _,v in ipairs(cur_project.ProjectSkillLastPoint) do
		if v.WeanponType == weapon then
			surplus_point = v.LastSkillPointNum
			break;
		end
	end
	return surplus_point
end

--技能战斗力
function mysql_to_redis_tw:role_skill_fight(record,blob_attr_proto,fight_proto)
	local all_point     = self:get_grade_skill_point(record,blob_attr_proto)
	local surplus_point = self:get_surplus_skill_point(record,blob_attr_proto)
	local fight_conf    = g_global.m_xls:get_row("SkillFighting",all_point - surplus_point)
	if not fight_conf then
		g_global.m_log:warn(string.format("SkillFighting not found conf all=%d surplus=%d",all_point,surplus_point))
		return true 
	end
	fight_proto.Skill = fight_conf.Fighting
	return true
end

--是否上阵
function mysql_to_redis_tw:is_battle(id,blob_attr_proto)
	for _,v1 in ipairs(blob_attr_proto.BeastData.FormationList) do
		if v1.ID == blob_attr_proto.BeastData.CurFormation then
			for _,v2 in ipairs(v1.BattleList) do 
				if v2 == id then
					return true
				end
			end
			break
		end
	end
	return false
end

--获得属性
function mysql_to_redis_tw:get_beast_property(id,beast_datas)
	for _,v in ipairs(beast_datas.Property) do
		if v.ID == id then
			return v
		end
	end
end

--获得神兽战斗力
function mysql_to_redis_tw:role_beast_fight(record,blob_attr_proto,fight_proto)
	local weapon = tonumber(record["Weapon"]) 
	for _,v in ipairs(blob_attr_proto.BeastData.BeastInfo) do
		local star_conf  = g_global.m_xls:get_row("ShenShouStar",v.ID,v.Star,v.StarStep)
		if star_conf then
			fight_proto.BeastLevel = fight_proto.BeastLevel + star_conf.ExFightNum
			if self:is_battle(star_conf.ID,blob_attr_proto) then
				fight_proto.BeastStar = fight_proto.BeastStar + star_conf.ExGuardFightNum
				for _,v1 in ipairs(star_conf.BaseProperty) do
					local best_property = self:get_beast_property(v1.Type,v)
					if best_property then
						local strengthen_conf = g_global.m_xls:get_row("BeastStrengthenConfig",v1.Type,best_property.GiftLevel)
						if not strengthen_conf then
							g_global.m_log:error(string.format("BeastStrengthenConfig conf not found type=%d level=%d",v1.Type,v1.GiftLevel))
						else
							fight_proto.BeastStrengthen = fight_proto.BeastStrengthen + strengthen_conf.Fighting
						end
					end
				end
				local attr_conf = g_global.m_xls:get_row("shenshoubaseattr",v.ID)
				if not attr_conf then
					g_global.m_log:error(string.format("shenshoubaseattr conf not found id=%d weapon",v.ID))
				else
					fight_proto.BeastLevel = fight_proto.BeastLevel + attr_conf.Fighting	
				end
				local level_conf = g_global.m_xls:get_row("ShenShouLevel",v.Level)
				if not level_conf then
					g_global.m_log:error(string.format("ShenShouLevel conf not found level=%d",v.Level))
				else
					fight_proto.BeastLevel = fight_proto.BeastLevel + level_conf.Fighting
				end
				for _,v1 in ipairs(v.SkillList) do
					local skill_conf = g_global.m_xls:get_row("ShenShouSkills",v1)
					if skill_conf then
						fight_proto.BeastSkill = fight_proto.BeastSkill + skill_conf.fighting
					end
				end
			end
		end 
	end
	return true
end

--获取头衔战斗力
function mysql_to_redis_tw:get_honor_fight(record,blob_attr_proto,fight_proto)
	local weapon = tonumber(record["Weapon"]) 
	local honor  = tonumber(blob_attr_proto.HonorTitle)
	local conf = g_global.m_xls:get_row("HonorConfig",g_global.m_xls:left_move(honor,8) + weapon)
	if conf then
		fight_proto.Honor = fight_proto.Honor + conf.PromoteFighting
	end
	return true
end

--获得时装战斗力
function mysql_to_redis_tw:get_fashion_fight(record,blob_attr_proto,fight_proto)
	for _,v in ipairs(blob_attr_proto.OutWardData.EnableOutWard) do
		local conf = g_global.m_xls:get_row("OutWardConf",v.EnableOutWardID)
		if not conf then
			g_global.m_log:error(string.format("OutWardConf conf not found id=%d ",v.EnableOutWardID))
		else
			fight_proto.OutWard = fight_proto.OutWard + conf.FightNum
		end
	end
	return true
end

return mysql_to_redis_tw