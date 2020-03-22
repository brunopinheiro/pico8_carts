pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- the amazing goblin's workshop
--   by brunopinheiro

-- game loop
local board
function _init()
	board = c_board()
	board:set_active(c_triple(board))
end

function _update60()
	board:update()
end

function _draw()
	cls()
	board:draw()
end

--core
local btn_left, btn_right, btn_up, btn_down, btn_o, btn_x = 0, 1, 2, 3, 4, 5

function merge_into(origin, target)
	local result = target or {}
	for k, v in pairs(origin) do
		result[k] = v
	end
	return result
end

function swap(t, k1, k2)
	local backup = t[k1]
	t[k1] = t[k2]
	t[k2] = backup
end

function try(t, method)
	if t then t[method](t) end
end

function c_animator()
	return {
		animations = {},

		animate = function(self, name, target, update, callback)
			self.animations[name]={ target=target, update=update, callback=callback }
		end,

		stop = function(self, name)
			self.animations[name]=nil
		end,

		update = function(self)
			local completed={}
			for k, anim in pairs(self.animations) do
				if not anim.update() then completed[k] = anim end
			end
			for k, anim in pairs(completed) do
				self:stop(k)
				if anim.callback then anim.callback(anim.target) end
			end
		end
	}
end

function linear_ease(initial, final, time, duration)
	return (final - initial) * time/duration + initial
end

function c_gameobject(args)
	return merge_into(args or {}, {
		animator = c_animator(),

		update = function(self)
			self.animator:update()
		end,

		draw = function() end,

		delayed = function(self, name, args)
			local it = time()
			local loops = args.loops or 0
			local callback = args.callback or printh('error: callback for delayed execution is required')
			local duration = args.duration or printh('error: duration for delayed execution is required')

			self.animator:animate(
				name,
				nil,
				function() return time() - it < duration end,
				(loops ~= 0) and function()
					callback()
					self:delayed(name, merge(args, { loops=loops - 1 }))
				end or callback
			)
		end,

		stop = function(self, name)
			self.animator:stop(name)
		end,

		animate = function(self, name, args)
			local loops = args.loops or 0
			local ease = args.ease or linear_ease
			local target = args.target or self
			local attr = args.attr or printh('error: attr for animation is required')
			local duration = args.duration or printh('error: duration for animation is required')
			local callback = args.callback
			local it = time()
			local ov = target[attr]
			local fv = args.fv or printh('error: fv for animation is required')
			local inverted_loop = args.inverted_loop or false

   		local ease_update = function()
     		local td = time() - it
     		target[attr]=ease(ov, fv, td, duration)
     		return td < duration
   		end

   		local loop_callback = function()
				if inverted_loop then
					fv = ov
					ov = args.fv
				end

				target[attr] = ov
				self:animate(name, merge(args, { loops=loops - 1, fv=fv }))
			end

			self.animator:animate(
				name,
				target,
				ease_update
				(loops ~= 0) and loop_callback or callback
			)
		end
	})
end

-->8
-- board and components
function c_board()
	local active_triple

	return merge_into({
		bounds = function()
			return { min_x=2, max_x=40, max_y=80 }
		end,

		set_active = function(self, triple)
			active_triple = triple
		end,

		glue = function(self, triple)
			active_triple = nil
		end,

		update = function()
			try(active_triple, 'update')
		end,

		draw = function()
			try(active_triple, 'draw')
			rect(0, 0, 49, 105, 13)
			rect(1, 1, 48, 104, 6)
		end
	}, c_gameobject())
end

local comp_screw, comp_gear, comp_wire = 1, 2, 3

function c_triple(board)
	local x, y, should_fall, gluing = 2, -30, true, false
	local components = { comp_screw, comp_gear, comp_wire }

	function try_swap()
		if btnp(btn_x) then
			swap(components, 1, 2)
			swap(components, 1, 3)
		end
	end

	function hor_mov(bounds)
		local hor = btnp(btn_left) and -8 or (btnp(btn_right) and 8 or 0)
		x = max(bounds.min_x, min(x + hor, bounds.max_x))
	end

	function ver_mov(triple, bounds)
		if not should_fall then return end

		should_fall = false
		gluing = false
		triple:delayed('fall', { duration=1, callback=function() should_fall = true end })
		triple:stop('glue')
		y = min(bounds.max_y, y + 8)
	end

	function try_move(triple)
		local bounds = board:bounds()
		hor_mov(bounds)

		if y < bounds.max_y then
			ver_mov(triple, bounds)
		else
			if not gluing then
				triple:delayed('glue', { duration=1, callback=function() board:glue(triple) end })
				gluing = true
			end
		end
	end

	return merge_into({
		update = function(self)
			self.animator:update()
			try_swap()
			try_move(self)
		end,

		draw = function()
			for i, comp in pairs(components) do
				spr(comp, x, y + (i - 1) * 8)
			end
		end
	}, c_gameobject())
end

__gfx__
00000000056666500004400004222140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000567777650049940002efee20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070067775776049aa94002e8ee20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770006777557649affa9402e88e20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770006775777649affa9402ee8e20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070067577776049aa94002e88e20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000567777650049940002e8ee20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000056666500004400004122240000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000