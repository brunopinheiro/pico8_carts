pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- the amazing goblin's workshop
--   by brunopinheiro

-- game loop
printh('::::: new :::::')
local board, factory
function _init()
	board = new_board(new_factory())
	board:turn_on()
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

function merged(t1, t2)
	local new = {}
	for k, v in pairs(t1) do new[k] = v end
	for k, v in pairs(t2) do new[k] = v end
	return new
end

function swap(t, k1, k2)
	local backup = t[k1]
	t[k1] = t[k2]
	t[k2] = backup
end

function try(t, method)
	if t then t[method](t) end
end

function new_animator()
	return {
		animations={},

		add=function(self, name, update, callback)
			self.animations[name]={ update=update, callback=callback }
		end,

		stop=function(self, name)
			self.animations[name]=nil
		end,

		update=function(self)
			local completed={}
			for k, anim in pairs(self.animations) do
				if not anim.update() then completed[k] = anim end
			end
			for k, anim in pairs(completed) do
				self:stop(k)
				try(anim, 'callback')
			end
		end
	}
end

function linear_ease(initial, final, time, duration)
	return (final - initial) * time/duration + initial
end

function delayed(animator, name, args)
	local it = time()
	local loops = args.loops or 0
	local callback = args.callback or printh('error: callback for delayed execution is required')
	local duration = args.duration or printh('error: duration for delayed execution is required')

	animator:add(
		name,
		function() return time() - it < duration end,
		(loops ~= 0) and function()
			callback()
			delayed(animator, name, merged(args, { loops=loops - 1 }))
		end or callback
	)
end

function animate(animator, name, args)
	local loops = args.loops or 0
	local ease = args.ease or linear_ease
	local target = args.target or printh('error: target for animation is required')
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
		animate(animator, name, merged(args, { loops=loops - 1, fv=fv }))
	end

	animator:add(
		name,
		ease_update
		(loops ~= 0) and loop_callback or callback
	)
end

-->8
-- board and components
function new_board(factory)
	local active_triple
	local glued_components = {}

	return {
		turn_on=function(self)
			active_triple = factory:produce(self)
		end,

		bounds=function()
			return { min_x=2, max_x=42, max_y=72 }
		end,

		glue=function(self)
			local pos = active_triple:pos()
			for i=1, 3 do
				add(glued_components, {
					sprite=active_triple:component(i),
					x=pos.x,
					y=pos.y + (i-1) * 8
				})
			end
			active_triple = factory:produce(self)
		end,

		update=function()
			try(active_triple, 'update')
		end,

		draw=function()
			try(active_triple, 'draw')
			for component in all(glued_components) do
				spr(component.sprite, component.x, component.y)
			end
			rect(0, 0, 50, 98, 13)
			rect(1, 1, 49, 97, 6)
		end
	}
end

local comp_screw, comp_gear, comp_wire = 1, 2, 3

function new_factory()
	return {
		produce=function(self, board)
			return new_triple(board, { comp_screw, comp_gear, comp_wire })
		end
	}
end

function new_triple(board, components)
	local animator = new_animator()
	local x, y, status = 2, -30, 'fall'

	function try_swap()
		if btnp(btn_x) then
			swap(components, 1, 2)
			swap(components, 1, 3)
		end
	end

	function try_speedup()
		status = (btn(btn_down) and status == 'idle') and 'speed-up' or status
	end

	function move()
		local bounds = board:bounds()

		-- horizontal
		local hor = btnp(btn_left) and -8 or (btnp(btn_right) and 8 or 0)
		x = max(bounds.min_x, min(x + hor, bounds.max_x))

		-- vertical
		if status == 'fall' then
			y = min(bounds.max_y, y + 8)
			status = y < bounds.max_y and 'float' or 'glue'
		elseif status == 'float' then
			delayed(animator, 'fall', { duration=1, callback=function() status = 'fall' end })
			status = 'idle'
		elseif status == 'glue' then
			delayed(animator, 'glue', { duration=1, callback=function() board:glue() end })
			status = 'idle'
		elseif status == 'speed-up' then
			delayed(animator, 'fall', { duration=0.01, callback=function() status = 'fall' end })
			status = 'speed-idle'
		end
	end

	return {
		pos=function() return {x=x, y=y} end,

		component=function(self, index)
			return components[index]
		end,

		update=function()
			animator:update()
			try_swap()
			try_speedup()
			move()
		end,

		draw=function()
			for i, comp in pairs(components) do
				spr(comp, x, y + (i - 1) * 8)
			end
		end
	}
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