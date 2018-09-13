--[[

	Airshuttle
	==========

	Copyright (C) 2018 Joachim Stolberg

	See LICENSE.txt for more information
	
]]--

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
		visual_size = {x = 2, y = 2}, -- Scale up of nodebox is these * 1.5
		textures = {"airshuttle:airshuttle_nodebox"},
	},

	-- Custom fields
	driver = nil,
	removed = false,
	speedH = 0,
	speedV = 0,
	rot = 0,
	timer = 0,
	auto = false,
	on_trip = false,
	dest_pos = nil,
	start_pos = nil,
	dest_approach = false,
	remote_controlled = false,
}

function AirshuttleEntity.on_rightclick(self, clicker)
	if not clicker or not clicker:is_player() then
		return
	end
	local name = clicker:get_player_name()
	if self.driver and name == self.driver and self.speedH < 0.1 then
		local pos = self.object:getpos()
		pos.y = pos.y - 1.5
		if minetest.get_node(pos).name == "air" then
			return
		end
		-- Detach
		self.driver = nil
		self.auto = false
		self.on_trip = false
		clicker:set_detach()
		default.player_attached[name] = false
		pos = clicker:getpos()
		minetest.after(0.1, function()
			clicker:setpos(pos)
		end)
		print("remove_airshuttle")
		airshuttle.remove_airshuttle(self)
	elseif not self.driver then
		-- Attach
		airshuttle.start_fly(self, clicker, nil)
	end
end

function AirshuttleEntity.on_activate(self, staticdata, dtime_s)
	self.object:set_armor_groups({immortal = 1})
end

function AirshuttleEntity.on_punch(self, puncher)
	if not puncher or not puncher:is_player() or self.removed then
		return
	end

	local name = puncher:get_player_name()
	if not self.driver then
		if name == self.owner 
		or self.owner == "" 
		or self.owner == nil
		or minetest.check_player_privs(name, "server") then
			airshuttle.remove_airshuttle(self)
		end
	end
end


function AirshuttleEntity.on_step(self, dtime)
	self.timer = (self.timer or 0) + dtime
	if self.remote_controlled and self.timer < 0.3 then
		return
	end
	self.timer = 0
	
	if not self.on_trip then
		return false
	end
	
	if not self.driver then
		airshuttle.remove_airshuttle(self)
		return false
	end
		
	local driver_objref = minetest.get_player_by_name(self.driver)
	if not driver_objref then
		airshuttle.remove_airshuttle(self)
		return false
	end
		
	self.speedH = get_v(self.object:getvelocity()) * get_sign(self.speedH)
	self.speedV = self.object:getvelocity().y

	airshuttle.remote_control(self)
	
	if self.speedH == 0 and self.rot == 0 and self.speedV == 0 then
		self.object:setpos(self.object:getpos())
		return
	end
	
	self.object:setpos(self.object:getpos())
	self.object:setvelocity(get_velocity(self.speedH, self.object:getyaw(), self.speedV))
	self.object:setyaw(self.object:getyaw() + 1 * self.rot)
end


minetest.register_entity("airshuttle:airshuttle", AirshuttleEntity)


-- Craftitem

minetest.register_craftitem("airshuttle:airshuttle", {
	description = "AirShuttle",
	inventory_image = "airshuttle_launcher.png",
	liquids_pointable = true,
	groups = {not_in_creative_inventory = 1},
	
	on_place = function(itemstack, placer, pointed_thing)
		local under = pointed_thing.under
		local node = minetest.get_node(under)
		local udef = minetest.registered_nodes[node.name]

		-- Run any on_rightclick function of pointed node instead
		if udef and udef.on_rightclick and
				not (placer and placer:is_player() and
				placer:get_player_control().sneak) then
			return udef.on_rightclick(under, node, placer, itemstack,
				pointed_thing) or itemstack
		end

		if pointed_thing.type ~= "node" then
			return itemstack
		end

		pointed_thing.under.y = pointed_thing.under.y + 1
		local airshuttle = minetest.add_entity(pointed_thing.under,
			"airshuttle:airshuttle")
		if airshuttle then
			if placer then
				airshuttle:setyaw(placer:get_look_horizontal())
				local self = airshuttle:get_luaentity()
				self.owner = placer and placer:get_player_name() or "" 
				self.pos = table.copy(pointed_thing.under)
				itemstack:take_item()
			end
		end
		return itemstack
	end,
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


function airshuttle.remove_airshuttle(self)
	if not self.removed then
		self.removed = true
		self.on_trip = false
		if self.pos then
			local meta = minetest.get_meta(self.pos)
			meta:set_int("busy", 0)
		end
		minetest.after(0.1, function()
			self.object:remove()
		end)
	end
end

