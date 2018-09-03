--[[

	Airshuttle
	==========

	Copyright (C) 2018 Joachim Stolberg

	See LICENSE.txt for more information
	
]]--

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


--local Route = {
--	{x=0, y=15, z=0},
--	{x=30, y=0, z=30},w
--	{x=-30, y=0, z=-30},
--	{x=0, y=-15, z=0},
--}	

local Route = {
	{x=0, y=20, z=30},
	{x=30, y=5, z=0},
	{x=0, y=-5,  z=-30},
}	

-- Calculation of v,vy and rot based on predefined route
function airshuttle.remote_control(self)
	local pos = self.object:getpos()
	if self.dest_pos == nil then
		self.start_pos = pos
		self.dest_pos = vector.add(pos, Route[self.next_idx])
		self.next_idx = self.next_idx + 1
	end
	-- calculate yaw and distance H/V
	local distH = vector.distance(pos, self.dest_pos)
	local distV = self.dest_pos.y - pos.y
	local dir = vector.subtract(self.dest_pos, pos)
	local yaw = minetest.dir_to_yaw(dir)
	local dyaw = yaw_offset(yaw, self.object:getyaw())
	--print("dyaw", F(dyaw), F(yaw), F(distH), F(distV))
	
	-- horizontal speed
	self.v = math.min(8, distH/2.5 + 0.01, self.v + 0.5)
	if distH < 0.1 then self.v = 0 end
	
	-- vertical speed
	if distV > 0 then
		self.vy = math.min(2, distV/4 + 0.04, self.vy + 0.2)
	elseif distV < 0 then
		self.vy = math.max(-2, distV/4 - 0.04, self.vy - 0.2)
	end
	if math.abs(distV) < 0.1 then self.vy = 0 end
	
	-- rotation speed
	if dyaw > 0.5 then
		self.rot = 0.2
	elseif dyaw < -0.5 then
		self.rot = -0.2
	else
		self.rot = dyaw
	end
	
	-- first correct yaw then increase speed
	if self.v > 0 then
		if dyaw > 0.1 and math.abs(distH/dyaw) > 5 or distH < 1 then 
			self.v = self.v/2 
		elseif distH < (math.abs(distV) * 4) then
			self.v = self.v/2 
		end
	end
	
	-- dest_position reached?
	if distH < 0.3 and math.abs(distV) < 0.1 then
		if self.next_idx <= #Route then
			local delta = vector.subtract(self.dest_pos, pos)	
			self.dest_pos = vector.add(pos, Route[self.next_idx])
			self.dest_pos = vector.add(self.dest_pos, delta)			
			self.next_idx = self.next_idx + 1
		elseif self.start_pos then
			local delta = vector.subtract(self.dest_pos, pos)	
			self.dest_pos = vector.add(self.start_pos, delta)			
			self.start_pos = nil
		else
			airshuttle.remove_airshuttle(self, minetest.get_player_by_name(self.owner or ""))
		end
	end
end
