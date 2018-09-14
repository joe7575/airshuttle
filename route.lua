--[[

	Airshuttle
	==========

	Copyright (C) 2018 Joachim Stolberg

	See LICENSE.txt for more information
	
]]--

local MAX_NUM_WAYPOINTS = 20
local MAX_NUM_ROUTES = 20
-------------------------------------------------------------------
-- Data base storage
-------------------------------------------------------------------
local storage = minetest.get_mod_storage()
local AirRoutes = minetest.deserialize(storage:get_string("AirRoutes")) or {}

local function update_mod_storage()
	storage:set_string("AirRoutes", minetest.serialize(AirRoutes))
end

local function array(size, val)
	local tbl = {}
	for i = 1,size do
		if type(val) == "table" then
			tbl[i] = table.copy(val)
		else
			tbl[i] = val
		end
	end
	return tbl
end

local function range(val, min, max)
	val = math.floor(math.abs(tonumber(val) or min))
	if val > max then return max end
	if val < min then return min end
	return val
end

local function replace_node(pos, player_name, old_name, new_node)
	local node = minetest.get_node(pos)
	local player = minetest.get_player_by_name(player_name)
	if player and node.name == old_name then
		minetest.remove_node(pos)
		minetest.set_node(pos, new_node)
		local after_place_node = minetest.registered_nodes[new_node.name].after_place_node
		if after_place_node then
			after_place_node(pos, player)
		end
	end
end

local function add_waypoint(name, id, number, pos, height)
	if not AirRoutes[name] then
		AirRoutes[name] = {}
	end
	if not AirRoutes[name][id] then
		AirRoutes[name][id] = array(MAX_NUM_WAYPOINTS, false)
	end
	local speed = range(height/2, 2, 8)
	pos.y = pos.y + height
	AirRoutes[name][id][number] = {waypoint = table.copy(pos), speed = speed}
	update_mod_storage()
	return pos
end

local function get_waypoint(name, id, number)
	if AirRoutes[name] 
	and AirRoutes[name][id] 
	and AirRoutes[name][id][number] then
		return AirRoutes[name][id][number].waypoint
	end
	return nil
end

local function del_waypoint(name, id, number)
	if get_waypoint(name, id, number) then
		AirRoutes[name][id][number] = false
	end
	update_mod_storage()
end

local function del_route(name, id)
	if AirRoutes[name] and AirRoutes[name][id] then 
		AirRoutes[name][id] = array(MAX_NUM_WAYPOINTS, false)
	end
	update_mod_storage()
end

local function show_route(name, id)
	if AirRoutes[name] and AirRoutes[name][id] then 
		local tbl = {}
		for num = 1,MAX_NUM_WAYPOINTS do
			if AirRoutes[name][id][num] then
				local item = AirRoutes[name][id][num] 
				tbl[#tbl+1] = num.." : "..P(item.waypoint)..", "..item.speed.." m/s\n"
			end
		end
		local text = "AirShuttle route "..id..":\n"..table.concat(tbl)
		minetest.chat_send_player(name, text)
	end
	update_mod_storage()
end

function airshuttle.get_next_waypoint(name, id, number)
	if not number then number = 0 end
	if AirRoutes[name] and AirRoutes[name][id] then
		for num = number+1,MAX_NUM_WAYPOINTS do
			if AirRoutes[name][id][num] then
				return num,
					AirRoutes[name][id][num].waypoint,
					AirRoutes[name][id][num].speed
			end
		end
	end
end

function airshuttle.get_next_id(name)
	if not AirRoutes[name] then
		AirRoutes[name] = {}
	end
	for id = 1, MAX_NUM_ROUTES do
		if not AirRoutes[name][id] then
			AirRoutes[name][id] = array(MAX_NUM_WAYPOINTS, false)
			update_mod_storage()
			return id
		end
	end
end

function airshuttle.delete_id(name, id)
	if AirRoutes[name] and AirRoutes[name][id] then
		AirRoutes[name][id] = false
	end
	update_mod_storage()
end

minetest.register_node("airshuttle:routemarker", {
	description = "AirShuttle Route Marker",
	drawtype = "node",
	tiles = {
		"airshuttle_marker_top.png",
		"airshuttle_marker_top.png",
		"airshuttle_marker.png",
		"airshuttle_marker.png",
		"airshuttle_marker.png",
		"airshuttle_marker.png",
		},
	
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		local node = minetest.get_node(pos)
		local spos = minetest.pos_to_string(pos)
		meta:set_string("infotext", "Waypoint "..node.param2.." "..spos)
		minetest.get_node_timer(pos):start(60)
	end,
	
	on_timer = function(pos, elapsed)
		minetest.remove_node(pos)
	end,

	paramtype = "light",
	light_source = 8,
	use_texture_alpha = true,
	sunlight_propagates = true,
	is_ground_content = false,
	drop = "",
	walkable = false,
	groups = {cracky = 3, oddly_breakable_by_hand = 3, not_in_creative_inventory = 1},
	sounds = default.node_sound_glass_defaults(),
})

minetest.register_privilege("airshuttle", 
	{description = "rights to buy and operate an AirShuttle", 
	give_to_singleplayer = false})


minetest.register_chatcommand("add_waypoint", {
	params = "<id> <number> <extra-height>" , 
	description = "Set AirShuttle fly waypoint",
	func = function(name, param)
		if minetest.check_player_privs(name, "airshuttle") then
			local id, number, height = param:match('^(%d+)%s(%d+)%s(%d+)$')
			if not id or not number or not height then
				return false, "Incorrect usage, /add_waypoint <id> <number> <extra-height>"
			end
			id = range(id, 1, MAX_NUM_ROUTES)
			number = range(number, 1, MAX_NUM_WAYPOINTS)
			height = range(height, 1, 50) + 1
			local pos = get_waypoint(name, id, number)
			if pos then
				replace_node(pos, name, "airshuttle:routemarker", {name = "air"})
			end
			local player = minetest.get_player_by_name(name)
			pos = player and player:get_pos() or nil
			if pos then
				pos = vector.round(pos)
				pos = add_waypoint(name, id, number, pos, height)
				replace_node(pos, name, "air", {name="airshuttle:routemarker", param2 = number})
				local spos =  minetest.pos_to_string(pos)
				return true, "Waypoint "..number.." at "..spos.." added."
			end
		else
			return false, "You do not have the necessary privs"
		end
	end,
})

minetest.register_chatcommand("del_waypoint", {
	params = "<id> <number>" , 
	description = "Delete AirShuttle fly waypoint",
	func = function(name, param)
		if minetest.check_player_privs(name, "airshuttle") then
			local id, number = param:match('^(%d+)%s(%d+)$')
			if not id or not number then
				return false, "Incorrect usage, /del_waypoint <id> <number>"
			end
			id = range(id, 1, MAX_NUM_ROUTES)
			number = range(number, 1, MAX_NUM_WAYPOINTS)
			local player = minetest.get_player_by_name(name)
			local pos = get_waypoint(name, id, number)
			if pos then
				replace_node(pos, name, "airshuttle:routemarker", {name = "air"})
				local spos =  minetest.pos_to_string(pos)
				return true, "Waypoint "..id.." at "..spos.." removed."
			end
		else
			return false, "You do not have the necessary privs"
		end
	end,
})

minetest.register_chatcommand("del_route", {
	params = "<id>" , 
	description = "Delete AirShuttle fly route",
	func = function(name, param)
		if minetest.check_player_privs(name, "airshuttle") then
			local id = param:match('^(%d+)$')
			if not id then
				return false, "Incorrect usage, /del_route <id>"
			end
			id = range(id, 1, MAX_NUM_ROUTES)
			del_route(name, id)
			return true, "Route "..id.." removed."
		else
			return false, "You do not have the necessary privs"
		end
	end,
})

minetest.register_chatcommand("show_route", {
	params = "<id>" , 
	description = "Show AirShuttle fly route",
	func = function(name, param)
		if minetest.check_player_privs(name, "airshuttle") then
			local id = param:match('^(%d+)$')
			if not id then
				return false, "Incorrect usage, /show_route <id>"
			end
			id = range(id, 1, MAX_NUM_ROUTES)
			show_route(name, id)
			return true
		else
			return false, "You do not have the necessary privs"
		end
	end,
})
