--[[

	Airshuttle
	==========

	Copyright (C) 2018 Joachim Stolberg

	See LICENSE.txt for more information
	
]]--

local P = minetest.pos_to_string
local F = function(val) return string.format("            %g", val):sub(-8, -1) end
--local DBG = function(...) end
local DBG = print

local MAX_DISTANCE = 1000 -- per hop

-- Speed horizontal [m/s]
local SH_MAX = 8
local SH_CHECKP = 2
local SH_MIN = 0.1
local SH_STEP = 0.5

-- Speed vertival [m/s]
local SV_MAX = 2
local SV_MIN = 0.1
local SV_STEP = 0.2

-- Rotation steps [radiant]
local ROT_MAX = 0.3
local ROT_STEP = 0.2

-- decrease value if shuttle does not hit the target
local MAGIC_FACTOR = 0.18

-- used to detect a server restart to re-initialize the launcher node
local ServerRestart = {}

local function yaw_offset(rad1, rad2)
	local offs = rad1 - rad2
	if offs > math.pi then 
		return offs - 2 * math.pi
	end
	if offs < -math.pi then 
		return offs + 2 * math.pi
	end
	return offs
end

local function get_sign(i)
	if i == 0 then
		return 0
	else
		return i / math.abs(i)
	end
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
	local pos = self.object:getpos()
	if self.dest_pos == nil then
		self.dest_approach = false
		self.start_pos = pos
		self.wp_number = 1
		self.wp_number, self.dest_pos, self.sh_max = 
			airshuttle.get_next_waypoint(self.owner, self.route_id, self.wp_number)
		if not self.wp_number then return end
	end
	-- calculate yaw and distance H/V
	local distH = vector.distance(pos, self.dest_pos)
	local distV = self.dest_pos.y - pos.y
	local dir = vector.subtract(self.dest_pos, pos)
	local yaw = minetest.dir_to_yaw(dir)
	local dyaw = yaw_offset(yaw, self.object:getyaw())
	
	-- horizontal speed
	if self.dest_approach then
		if distH < 0.1 then 
			self.speedH = 0 
		else
			self.speedH = math.min(self.sh_max, distH/2 + SH_MIN, self.speedH + SH_STEP)
		end
	else -- normal check point
		self.speedH = math.min(self.sh_max, distH/2 + SH_CHECKP, self.speedH + SH_STEP)
	end
	
	-- vertical speed
	if distV > 0 then
		self.speedV = math.min(SV_MAX, distV/4 + SV_MIN, self.speedV + SV_STEP)
	elseif distV < 0 then
		self.speedV = math.max(-SV_MAX, distV/4 - SV_MIN, self.speedV - SV_STEP)
	end
	if math.abs(distV) < 0.1 then self.speedV = 0 end
	
	-- rotation speed
	if dyaw > ROT_MAX then
		self.rot = ROT_STEP
	elseif dyaw < -ROT_MAX then
		self.rot = -ROT_STEP
	else
		self.rot = dyaw
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
	local max_speed = distH * MAGIC_FACTOR / math.abs(dyaw)
	if self.speedH > max_speed then
		self.speedH = max_speed
	end
	
	if dest_position_reached(self, distH, distV) then
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
			airshuttle.remove_airshuttle(self, minetest.get_player_by_name(self.owner or ""))
			DBG("mission accomplished")
		end
	end
end

minetest.register_chatcommand("start_fly", {
	description = "Start the AirShuttle sightseeing trip",
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if player then
			local spos = minetest.pos_to_string(player:get_pos())
			player:set_attribute("airshuttle_start_pos", spos)
			local p = player:get_pos()
			p.y = p.y + 0.6
			airshuttle.place_shuttle(p, player, player)
		end
	end,
})


-- Place the player back to the start point
local function reset_player(player)
	if player then
		local spos = player:get_attribute("airshuttle_start_pos")
		if spos then
			local pos = minetest.string_to_pos(spos)
			if pos then
				player:set_pos(pos)
			end
			player:set_attribute("airshuttle_start_pos", nil)
		end
	end
end	

-- fly is canceled
minetest.register_on_joinplayer(function(player)
	reset_player(player)
end)

-- fly is canceled
minetest.register_on_dieplayer(function(player)
	reset_player(player)
end)

minetest.register_node("airshuttle:launcher", {
	description = "AirShuttle Launcher",
	drawtype = "node",
	tiles = {"airshuttle_launcher.png"},
	
	-- switch ON/OFF
	on_rightclick = function (pos, node, clicker)
		local meta = minetest.get_meta(pos)
		local busy = meta:get_int("busy")
		local owner = meta:get_string("owner")
		local route_id = meta:get_int("route_id")
		if busy == 0 or ServerRestart[route_id] == nil then
			ServerRestart[route_id] = true
			local spos = minetest.pos_to_string(clicker:get_pos())
			clicker:set_attribute("airshuttle_start_pos", spos)
			airshuttle.place_shuttle(pos, clicker, owner, node.param2, route_id)
			meta:set_int("busy", 1)
		end
	end,

	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		local route_id = airshuttle.get_next_id(placer:get_player_name())
		meta:set_int("route_id", route_id)
		meta:set_int("busy", 0)
		meta:set_string("owner", placer:get_player_name())
		meta:set_string("infotext", "AirShuttle Launcher (ID "..route_id..")")
	end,

	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		local meta = minetest.get_meta(pos)
		local route_id = meta:get_int("route_id")
		airshuttle.delete_id(digger:get_player_name(), route_id)
	end,
	
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = {cracky = 1},
	sounds = default.node_sound_metal_defaults(),
})


