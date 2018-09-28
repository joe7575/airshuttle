--[[

	Airshuttle
	==========

	Copyright (C) 2018 Joachim Stolberg

	See LICENSE.txt for more information
	
]]--

local P = minetest.pos_to_string
local F = function(val) return string.format("%2.1f", val) end
local DBG = function(...) end
--local DBG = print

local MissingPlayer = {}

local MAX_DISTANCE = 1000 -- per hop
local TELEPORT_DIST = 400

-- Speed horizontal [m/s]
local SH_MAX = 8
local SH_CHECKP = 2.5
local SH_MIN = 0.1
local SH_STEP = 0.5

-- Speed vertival [m/s]
local SV_MAX = 2
local SV_MIN = 0.1
local SV_STEP = 0.2

-- Rotation steps [radiant]
local ROT_STEP = 0.2

-- decrease value if shuttle does not hit the target
local MAGIC_FACTOR = 0.18

local function get_sign(i)
	if i == 0 then
		return 0
	else
		return i / math.abs(i)
	end
end

local function yaw_offset(old, new)
	local d = (new - old) % (2*math.pi)
	if d > math.pi then
		return d - (2*math.pi)
	end
	return d
end


local function dest_position_reached(self, distH, distV)
	DBG(self.wp_number, self.dest_approach, F(distH), F(distV), F(self.speedH))
	if self.dest_approach then
		return distH < 0.2 and  math.abs(distV) < 0.1
	else
		return distH < 3 and math.abs(distV) < 2
	end
end

-- Calculation of v,vy and rot based on predefined route
function airshuttle.remote_control(self)
	local pos = self.object:get_pos()
	if self.dest_pos == nil then
		self.dest_approach = false
		self.start_pos = pos
		self.wp_number = nil
		self.wp_number, self.dest_pos, self.sh_max = 
			airshuttle.get_next_waypoint(self.owner, self.route_id, self.wp_number)
		if not self.wp_number then return false end
	end
	-- calculate yaw and distance H/V
	local distH = vector.distance(pos, self.dest_pos)
	local distV = self.dest_pos.y - pos.y
	local dir = vector.subtract(self.dest_pos, pos)
	local new_yaw = minetest.dir_to_yaw(dir)
	local yaw_offs = yaw_offset(self.object:get_yaw(), new_yaw)
	
	-- teleport distance?
	if distH > TELEPORT_DIST then
		self.object:set_pos(self.dest_pos)
		distH = 0
		distV = 0
	end
		
	-- waypoint missed due lag?
	if self.oldDist and distH > self.oldDist then
		self.object:set_pos(self.dest_pos)
	end
	self.oldDist = distH
	
	-- horizontal speed
	if self.dest_approach then
		if distH < 0.1 then 
			self.speedH = 0 
		else
			self.speedH = math.min(self.sh_max, distH + SH_MIN, self.speedH + SH_STEP)
		end
	else -- normal check point
		self.speedH = math.min(self.sh_max, distH + SH_CHECKP, self.speedH + SH_STEP)
	end
	
	-- vertical speed
	if distV > 0 then
		self.speedV = math.min(SV_MAX, distV/4 + SV_MIN, self.speedV + SV_STEP)
	elseif distV < 0 then
		self.speedV = math.max(-SV_MAX, distV/4 - SV_MIN, self.speedV - SV_STEP)
	end
	if math.abs(distV) < 0.1 then self.speedV = 0 end
	
	if self.speedH == 0 and yaw_offs == 0 and self.speedV == 0 then
		return false
	end
	
	-- H/V speed ratio correction
	if self.speedH > 0 and math.abs(self.speedV) > 0 then
		local ratio = distH / math.abs(distV)
		local maxV = (self.speedH / ratio) * 1
		local maxH = (math.abs(self.speedV) * ratio) * 1
		
		if maxV < math.abs(self.speedV) then
			DBG("correction1")
			self.speedV = maxV * get_sign(self.speedV)
		elseif maxH < self.speedH then
			DBG("correction2")
			self.speedH = maxH
		end
	end
	
	-- speed/rotation correction
	local max_speed = distH * MAGIC_FACTOR / math.abs(yaw_offs)
	if self.speedH > max_speed then
		self.speedH = max_speed
	end
	
	-- yaw_offs limitation
	self.yaw_offs = math.min(math.abs(yaw_offs), ROT_STEP) * get_sign(yaw_offs)
	print("new_yaw, get_yaw, yaw_offs, yaw_corr", G(new_yaw), G(self.object:get_yaw()), G(yaw_offs), G(self.yaw_offs))
	
	if dest_position_reached(self, distH, distV) then
		self.oldDist = nil
		self.wp_number, self.dest_pos, self.sh_max = 
			airshuttle.get_next_waypoint(self.owner, self.route_id, self.wp_number)
		if self.wp_number and not self.dest_approach then
			DBG("checkpoint hit")
		elseif not self.dest_approach then -- destination approach
			self.dest_pos = table.copy(self.start_pos)
			self.sh_max = 3
			self.dest_approach = true
			DBG("destination approach")
		else
			self.on_trip = false
			DBG("mission accomplished")
			self.object:set_velocity({x = 0, y = 0, z = 0})
			self.object:set_pos(self.object:get_pos())
			return false
		end
	end
	return true
end

function airshuttle.player_gone(player_name)
	if not player_name then
		return true
	end
	
	local player = minetest.get_player_by_name(player_name)
	if not player then
		return true
	end
	
	if MissingPlayer[player_name] then
		MissingPlayer[player_name] = nil
		return true
	end
	return false
end

-- Place the player back to the start point
local function reset_player(player)
	if player then
		local spos = player:get_attribute("airshuttle_start_pos")
		if spos then
			local pos = minetest.string_to_pos(spos)
			if pos then
				player:set_detach()
				default.player_attached[player:get_player_name()] = false
				default.player_set_animation(player, "stand" , 30)
				minetest.after(0.1, function()
					player:set_pos(pos)
				end)
			end
			player:set_attribute("airshuttle_start_pos", nil)
			DBG("player reset")
		end
	end
end	

-- fly is canceled
minetest.register_on_joinplayer(function(player)
	reset_player(player)
end)

minetest.register_on_leaveplayer(function(player)
	MissingPlayer[player:get_player_name()] = true
end)

minetest.register_on_dieplayer(function(player)
	MissingPlayer[player:get_player_name()] = true
	reset_player(player)
end)




