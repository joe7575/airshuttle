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

-- Calculation of v,vy and rot based on user inputs
function airshuttle.user_control(self)
	if not self.driver then
		airshuttle.remove_airshuttle(self, minetest.get_player_by_name(self.owner or ""))
		return false
	end
		
	local driver_objref = minetest.get_player_by_name(self.driver)
	if not driver_objref then
		airshuttle.remove_airshuttle(self, minetest.get_player_by_name(self.owner or ""))
		return false
	end
	
	if not self.on_trip then
		return false
	end
	
	local ctrl = self.driver:get_player_control()
	if ctrl.up and ctrl.down then
		if not self.auto then
			self.auto = true
			minetest.chat_send_player(self.driver:get_player_name(), "[airshuttle] Cruise on")
		end
	elseif ctrl.down then
		self.v = self.v - 0.2
		if self.auto then
			self.auto = false
			minetest.chat_send_player(driver:get_player_name(), "[airshuttle] Cruise off")
		end
	elseif ctrl.up or self.auto then
		self.v = self.v + 0.2
	end
	if ctrl.left then
		self.rot = self.rot + 0.002
	elseif ctrl.right then
		self.rot = self.rot - 0.002
	end
	if ctrl.jump then
		self.vy = self.vy + 0.075
	elseif ctrl.sneak then
		self.vy = self.vy - 0.075
	end
	
	-- Reduction and limiting of linear speed
	local s = get_sign(self.v)
	self.v = self.v - 0.02 * s
	if s ~= get_sign(self.v) then
		self.v = 0
	end
	if math.abs(self.v) > 6 then
		self.v = 6 * get_sign(self.v)
	end

	-- Reduction and limiting of rotation
	local sr = get_sign(self.rot)
	self.rot = self.rot - 0.0003 * sr
	if sr ~= get_sign(self.rot) then
		self.rot = 0
	end
	if math.abs(self.rot) > 0.02 then
		self.rot = 0.02 * get_sign(self.rot)
	end

	-- Reduction and limiting of vertical speed
	local sy = get_sign(self.vy)
	self.vy = self.vy - 0.03 * sy
	if sy ~= get_sign(self.vy) then
		self.vy = 0
	end
	if math.abs(self.vy) > 4 then
		self.vy = 4 * get_sign(self.vy)
	end
	
	return true
end	

