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
function airshuttle.user_control(self, pilot)
	local ctrl = pilot:get_player_control()
	if ctrl.up and ctrl.down then
		if not self.auto then
			self.auto = true
			minetest.chat_send_player(pilot:get_player_name(), "[airshuttle] Cruise on")
		end
	elseif ctrl.down then
		self.speedH = self.speedH - 0.8
		if self.auto then
			self.auto = false
			minetest.chat_send_player(pilot:get_player_name(), "[airshuttle] Cruise off")
		end
	elseif ctrl.up or self.auto then
		self.speedH = self.speedH + 0.8
	end
	if ctrl.left then
		self.rot = self.rot + 0.01
	elseif ctrl.right then
		self.rot = self.rot - 0.01
	end
	if ctrl.jump then
		self.speedV = self.speedV + 0.4
	elseif ctrl.sneak then
		self.speedV = self.speedV - 0.4
	end
	
	-- Reduction and limiting of linear speed
	local s = get_sign(self.speedH)
	self.speedH = self.speedH - 0.4 * s
	if s ~= get_sign(self.speedH) then
		self.speedH = 0
	end
	if math.abs(self.speedH) > 8 then
		self.speedH = 8 * get_sign(self.speedH)
	end

	-- Reduction and limiting of rotation
	local sr = get_sign(self.rot)
	self.rot = self.rot - 0.005 * sr
	if sr ~= get_sign(self.rot) then
		self.rot = 0
	end
	if math.abs(self.rot) > 0.1 then
		self.rot = 0.1 * get_sign(self.rot)
	end

	-- Reduction and limiting of vertical speed
	local sy = get_sign(self.speedV)
	self.speedV = self.speedV - 0.2 * sy
	if sy ~= get_sign(self.speedV) then
		self.speedV = 0
	end
	if math.abs(self.speedV) > 4 then
		self.speedV = 4 * get_sign(self.speedV)
	end
	
	return true
end	

