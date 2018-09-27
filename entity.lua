--[[

	Airshuttle
	==========

	Copyright (C) 2018 Joachim Stolberg

	See LICENSE.txt for more information
	
]]--

local DBG = function(...) end
--local DBG = print

-- used to detect a server restart to re-initialize the launcher node
local ServerRestart = {}

local function get_sign(i)
	if i == 0 then
		return 0
	else
		return i / math.abs(i)
	end
end

local function get_velocity(v, yaw, y)
	local x = -math.sin(yaw) * v
	local z =  math.cos(yaw) * v
	return {x = x, y = y, z = z}
end

local function get_v(v)
	return math.sqrt(v.x ^ 2 + v.z ^ 2)
end

--
-- Airshuttle entity
--
local AirshuttleEntity = {
		initial_properties = {
		physical = true,
		collide_with_objects = false, -- Workaround fix for a MT engine bug
		collisionbox = {-0.85, -0.40, -0.85, 0.85, 0.85, 0.85},
		visual = "wielditem",
		visual_size = {x = 2, y = 2},
		textures = {"airshuttle:airshuttle_nodebox"},
	},

	-- Custom fields
	driver = nil,  -- drivers name
	removed = false,
	speedH = 0,
	speedV = 0,
	rot = 0,  -- rotation
	timer = 0,
	on_trip = false,
	dest_pos = nil,
	start_pos = nil,
	dest_approach = false,
}

local function landed(self)
	if self.speedH < 0.1 then
		local pos = self.object:getpos()
		pos.y = pos.y - 1.5
		if minetest.get_node(pos).name ~= "air" then
			return true
		end	
	end
	return false
end
		
local function remove_airshuttle(self)
	self.removed = true
	self.on_trip = false
	if self.pos then
		local meta = minetest.get_meta(self.pos)
		meta:set_int("busy", 0)
	end
	-- delay remove to ensure player is detached
	minetest.after(0.1, function()
		self.object:remove()
	end)
	DBG("airshuttle removed")
end

function AirshuttleEntity.on_rightclick(self, clicker)
	if not clicker or not clicker:is_player() then
		return
	end
	local name = clicker:get_player_name()
	if self.driver and name == self.driver and landed(self) then
		-- Detach
		self.driver = nil
		self.on_trip = false
		clicker:set_detach()
		default.player_attached[name] = false
		default.player_set_animation(clicker, "stand" , 30)
		clicker:set_attribute("airshuttle_start_pos", nil)
		local pos = clicker:getpos()
		pos = {x = pos.x, y = pos.y + 0.2, z = pos.z}
		minetest.after(0.1, function()
			clicker:setpos(pos)
		end)
		remove_airshuttle(self)
		minetest.log("action", clicker:get_player_name().." detaches from airshuttle at "..
			minetest.pos_to_string(pos))
	elseif not self.driver then
		-- Attach
		self.on_trip = true
		local spos = minetest.pos_to_string(clicker:get_pos())
		clicker:set_attribute("airshuttle_start_pos", spos)
		local attach = clicker:get_attach()
		if attach and attach:get_luaentity() then
			local luaentity = attach:get_luaentity()
			if luaentity.driver then
				luaentity.driver = nil
			end
			clicker:set_detach()
		end
		self.driver = clicker:get_player_name()
		clicker:set_attach(self.object, "",
			{x = 0, y = 6, z = 0}, {x = 0, y = 0, z = 0})
		default.player_attached[name] = true
		minetest.after(0.2, function()
			default.player_set_animation(clicker, "stand" , 30)
		end)
		clicker:set_look_horizontal(self.object:getyaw())
		minetest.log("action", clicker:get_player_name().." attaches to airshuttle at "..
			minetest.pos_to_string(clicker:getpos()))
	end
end

function AirshuttleEntity.on_activate(self, staticdata, dtime_s)
	self.object:set_armor_groups({immortal = 1})
end

function AirshuttleEntity.on_punch(self, puncher)
	if not puncher or not puncher:is_player() or self.removed then
		return
	end

	if self.on_trip then
		return
	end
	
	local name = puncher:get_player_name()
	if self.driver and name == self.driver then
		self.driver = nil
		puncher:set_detach()
		default.player_attached[name] = false
	end
	if not self.driver then
		remove_airshuttle(self)
	end
end


function AirshuttleEntity.on_step(self, dtime)
	self.timer = (self.timer or 0) + dtime
	if self.timer < 0.2 then
		return
	end
	self.timer = 0
	
	if not self.on_trip then
		return
	end
	
	if airshuttle.player_gone(self.driver) then
		remove_airshuttle(self)
		return
	end
		
	self.speedH = get_v(self.object:getvelocity()) * get_sign(self.speedH)
	self.speedV = self.object:getvelocity().y

	if airshuttle.remote_control(self) then
		self.object:setpos(self.object:getpos())
		self.object:setvelocity(get_velocity(self.speedH, self.object:getyaw(), self.speedV))
		self.object:setyaw(self.object:getyaw() + 1 * self.rot)
	end
end


minetest.register_entity("airshuttle:airshuttle", AirshuttleEntity)


-- Craftitem

minetest.register_craftitem("airshuttle:airshuttle", {
	description = "AirShuttle",
	inventory_image = "airshuttle_launcher.png",
	liquids_pointable = true,
	groups = {not_in_creative_inventory = 1},
})


-- Nodebox for entity wielditem visual

minetest.register_node("airshuttle:airshuttle_nodebox", {
	description = "AirShuttle",
	tiles = { -- Top, base, right, left, front, back
		"airshuttle_top.png",
		"airshuttle_base.png",
		"airshuttle_right.png",
		"airshuttle_left.png",
		"airshuttle_front.png",
		"airshuttle_back.png",
	},
	paramtype = "light",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = { 
			-- Widmin, heimin, lenmin,   widmax, heimax, lenmax
			{-6/24,  -5/24,  -12/24,     6/24,  6/24,  12/24}, -- Envelope
			{-1/48,   6/24,  -15/24,     1/48, 12/24,  -3/24}, -- Top fin
			{-12/24,  0/24,  -15/24,    -6/24,  1/24,  -3/24}, -- Left fin
			{  6/24,  0/24,  -15/24,    12/24,  1/24,  -3/24}, -- Right fin
		},
	},
	groups = {cracky = 3, oddly_breakable_by_hand = 3, not_in_creative_inventory = 1},
})

local function place_shuttle(pos, owner, facedir, route_id)
	pos.y = pos.y + 1
	local airshuttle_entity = minetest.add_entity(pos, "airshuttle:airshuttle")
	if airshuttle_entity then
		local self = airshuttle_entity:get_luaentity()
		if facedir then
			local dir = minetest.facedir_to_dir(facedir)
			local yaw = minetest.dir_to_yaw(dir)
			airshuttle_entity:set_yaw(yaw)
		end
		pos.y = pos.y - 1
		self.owner = owner
		self.pos = table.copy(pos)
		self.route_id = route_id
	end
end

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
			place_shuttle(pos, owner, node.param2, route_id)
			meta:set_int("busy", 1)
			minetest.get_node_timer(pos):start(60*10)
		end
	end,

	on_timer = function(pos, elapsed)
		print("timer")
		local meta = minetest.get_meta(pos)
		meta:set_int("busy", 0)
		return false
	end,

	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		local route_id = airshuttle.get_next_id(placer:get_player_name())
		if route_id then
			meta:set_int("route_id", route_id)
			meta:set_int("busy", 0)
			meta:set_string("owner", placer:get_player_name())
			meta:set_string("infotext", "AirShuttle Launcher (ID "..route_id..")")
			minetest.log("action", placer:get_player_name().." places airshuttle:launcher at "..
				minetest.pos_to_string(pos))
		else
			minetest.chat_send_player(placer:get_player_name(), "[AirShuttle] Number of Launcher exceeded!")
		end
	end,

	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		local route_id = tonumber(oldmetadata["fields"]["route_id"])
		airshuttle.delete_id(digger:get_player_name(), route_id)
	end,
	
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = {cracky = 1},
	sounds = default.node_sound_metal_defaults(),
})
