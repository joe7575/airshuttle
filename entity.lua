--[[

	Airshuttle
	==========

	Copyright (C) 2018 Joachim Stolberg

	See LICENSE.txt for more information
	
]]--

local P = minetest.pos_to_string
local F = function(val) return string.format("           w %g", val):sub(-8, -1) end


local remote_controlled = tonumber(minetest.setting_get("remote_controlled")) or true

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
	v = 0,
	vy = 0,
	rot = 0,
	auto = false,
	on_trip = false,
	next_idx = 1,
	dest_pos = nil,
	start_pos = nil,
}

function AirshuttleEntity.on_rightclick(self, clicker)
	if not clicker or not clicker:is_player() then
		return
	end
	local name = clicker:get_player_name()
	if self.driver and name == self.driver and self.v < 0.1 then
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
	elseif not self.driver then
		-- Attach
		local attach = clicker:get_attach()
		if attach and attach:get_luaentity() then
			local luaentity = attach:get_luaentity()
			if luaentity.driver then
				luaentity.driver = nil
			end
			clicker:set_detach()
		end
		self.driver = name
		self.on_trip = true
		clicker:set_attach(self.object, "",
			{x = 0, y = 6, z = 0}, {x = 0, y = 0, z = 0})
		default.player_attached[name] = true
		clicker:set_look_horizontal(self.object:getyaw())
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
			-- Move to inventory
			airshuttle.remove_airshuttle(self, puncher)
		end
	end
end


local timer = 0

function AirshuttleEntity.on_step(self, dtime)
	timer = timer + dtime
	if remote_controlled and timer < 0.5 then
		return
	end
	timer = 0
	
	self.v = get_v(self.object:getvelocity()) * get_sign(self.v)
	self.vy = self.object:getvelocity().y

	-- Controls
	if remote_controlled then
		airshuttle.remote_control(self)
		dtime = 0
	else
		if not airshuttle.user_control(self) then return end
	end
	
	-- Early return for stationary vehicle
	if self.v == 0 and self.rot == 0 and self.vy == 0 then
		self.object:setpos(self.object:getpos())
		return
	end
	
	local new_acce = {x = 0, y = 0, z = 0}
	-- Bouyancy in liquids
	local p = self.object:getpos()
	p.y = p.y - 1.5
	local def = minetest.registered_nodes[minetest.get_node(p).name]
	if def and (def.liquidtype == "source" or def.liquidtype == "flowing") then
		new_acce = {x = 0, y = 10, z = 0}
	end

	self.object:setvelocity(get_velocity(self.v, self.object:getyaw(), self.vy))
	self.object:setacceleration(new_acce)
	self.object:setyaw(self.object:getyaw() + (1 + dtime) * self.rot)
end

minetest.register_entity("airshuttle:airshuttle", AirshuttleEntity)


-- Craftitem

minetest.register_craftitem("airshuttle:airshuttle", {
	description = "AirshuttleEntity",
	inventory_image = "airshuttle_inv.png",
	liquids_pointable = true,

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
				airshuttle:get_luaentity().owner = placer and placer:get_player_name() or "" 
			end
		end
		return itemstack
	end,
})


-- Nodebox for entity wielditem visual

minetest.register_node("airshuttle:airshuttle_nodebox", {
	description = "Airshuttle",
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
	groups = {not_in_creative_inventory = 1},
})

function airshuttle.remove_airshuttle(self, player)
	if not self.removed  and player then
		self.removed = true
		local inv = player:get_inventory()
		local stack = ItemStack("airshuttle:airshuttle")
		if inv:room_for_item("main", stack) then
			inv:add_item("main", stack)
			minetest.after(0.1, function()
				self.object:remove()
			end)
		end
	end
end
