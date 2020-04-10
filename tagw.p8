pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- the amazing goblin's workshop
--   by brunopinheiro

-- game loop
printh('::::: new :::::')
local board, factory, warehouse
local comp_screw, comp_gear, comp_wire = {s=1, c=6}, {s=2, c=9}, {s=3, c=14}

function _init()
	warehouse = new_warehouse({
		comp_screw,
		comp_gear,
		comp_wire
	})
	board = new_board(new_factory())
	board:turn_on()
end

function _update60()
	board:update()
end

function _draw()
	cls()
	board:draw()
	warehouse:draw()
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
			callback(loops - 1 > 0)
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
	local new_b = {}
	local active_triple
	local animator = new_animator()
	local glued_components = {}
	local ix, iy, fx, fy = 2, 2, 42, 98

	function pos_to_coords(x, y)
		return 'c'..x..'r'..y
	end

	function contains(x, y)
		return glued_components[pos_to_coords(x, y)]
	end

	function glue_component(sprite, x, y)
		glued_components[pos_to_coords(x, y)] = {
			sprite=sprite,
			visible=true,
			x=x,
			y=y
		}
	end

	function check_game_over()
		for _, component in pairs(glued_components) do
			if component.y < -8 then
				return true
			end
		end

		return false
	end

	function component_at(x, y)
		return glued_components[pos_to_coords(x, y)]
	end

	function max_y(x)
		for y=fy, iy, -8 do
			if not component_at(x, y) then return y end
		end

		return iy
	end

	function collect()
		for i, component in pairs(glued_components) do
			collect_direction(component, 8, -8, { component })
			collect_direction(component, 8,  0, { component })
			collect_direction(component, 8,  8, { component })
			collect_direction(component, 0,  8, { component })
		end

		if remove_marked() then
			delayed(animator, 'wait_gravity', { duration = 2.2, callback=function() gravity() end })
		else
			new_b:turn_on()
		end
	end

	function remove_marked()
		local collecting = false

		for i, component in pairs(glued_components) do
			if component.marked then
				collecting = true
				delayed(animator, 'coll'..i, {
					duration=0.25,
					callback=function(running_loop)
						component.visible = not component.visible
						if not running_loop then remove_component(component) end
					end,
					loops=8
				})
			end
		end

		return collecting
	end

	function collect_direction(current_comp, x, y, stack)
		local next_comp = glued_components[pos_to_coords(current_comp.x + x, current_comp.y + y)]

		if not next_comp or next_comp.sprite ~= current_comp.sprite then
			if #stack >= 3 then
				for _, component in pairs(stack) do component.marked = true end
			end

			return
		end

		add(stack, next_comp)
		collect_direction(next_comp, x, y, stack)
	end


	function gravity()
		local moved = false

		for y=fy, iy, -8 do
			for x=ix, fx, 8 do
				moved = gravity_component(component_at(x, y)) or moved
			end
		end

		if moved then
			collect()
		else
			new_b:turn_on()
		end
	end

	function remove_component(component)
		glued_components[pos_to_coords(component.x, component.y)] = nil
	end

	function gravity_component(component)
		if not component then return false end

		local dest_y = max_y(component.x)
		if dest_y > component.y then
			remove_component(component)
			glue_component(component.sprite, component.x, dest_y)
			return true
		end

		return false
	end

	new_b.max_y = max_y

	new_b.turn_on = function(self)
		if not check_game_over() then
			active_triple = factory.produce(self)
		else
			printh('game over')
		end
	end

	new_b.move_bounds = function(x, y)
		return {
			left=(contains(x - 8, y) or x - 8 < ix) and 0 or -8,
			right=(contains(x + 8, y) or x + 8 > fx) and 0 or 8,
			bottom=(contains(x, y + 8) or y + 8 > fy) and 0 or 8
		}
	end

	new_b.glue = function(self)
		local pos = active_triple:pos()
		for i=1, 3 do glue_component(active_triple.component(i).s, pos.x, pos.y + (i-1) * 8) end

		active_triple = nil
		collect()
	end

	new_b.update = function()
		animator:update()
		try(active_triple, 'update')
	end

	new_b.draw = function()
		for _, component in pairs(glued_components) do
			if component.visible then spr(component.sprite, component.x, component.y) end
		end
		try(active_triple, 'draw')
		rect(0, 0, 50, 108, 13)
		rect(1, 1, 49, 107, 6)
	end

	return new_b
end


function new_factory()
	return {
		produce=function(board)
			return new_triple(board, { comp_screw, comp_gear, comp_wire })
		end
	}
end

function new_triple(board, components)
	local animator = new_animator()
	local x, y  = 2, -30
	local fall_locked, fall_speedup = false, 0
	local hor_locked = false
	local glue_attempts = 0

	function try_swap()
		if btnp(btn_x) then
			swap(components, 1, 2)
			swap(components, 1, 3)
		end
	end

	function try_speedup()
		if btn(btn_down) then
			if fall_locked and fall_speedup == 0 then
				fall_locked = false
			end
			fall_speedup = 0.95
		else
			fall_speedup = 0
		end
	end

	function try_instant_glue()
		if btnp(btn_o) then
			y = board.max_y(x) - 16
			fall_locked = true
			hor_locked = true
			animator:stop('fall')
			delayed(animator, 'instant_glue', { duration=0.5, callback=function() board:glue() end })
		end
	end

	function try_glue(bounds)
		if bounds.bottom == 0 then
			if glue_attempts < 2 then
				glue_attempts = glue_attempts + 1
			else
				board:glue()
			end
		else
			glue_attempts = 0
		end
	end

	function fall_delay()
		return glue_attempts > 0 and 0.8 or 1 - fall_speedup
	end

	function move()
		local bounds = board.move_bounds(x, y + 16)

		-- horizontal
		if not hor_locked then
			local hor = btnp(btn_left) and bounds.left or (btnp(btn_right) and bounds.right or 0)
			x = x + hor
		end

		-- vertical
		if not fall_locked then
			fall_locked = true
			y = y + bounds.bottom
			try_glue(bounds)
			delayed(animator, 'fall', { duration=fall_delay(), callback=function() fall_locked = false end })
		end
	end

	return {
		pos=function() return {x=x, y=y} end,

		component=function(index)
			return components[index]
		end,

		update=function()
			animator:update()
			try_swap()
			try_speedup()
			try_instant_glue()
			move()
		end,

		draw=function()
			local max_y_preview = board.max_y(x)

			for i, comp in pairs(components) do
				spr(comp.s, x, y + (i - 1) * 8)
				local comp_preview_y = max_y_preview - (3 - i) * 8
				rect(x, comp_preview_y, x + 8, comp_preview_y + 7, comp.c)
			end
		end
	}
end

function new_warehouse(components)
	local counter = {}
	for component in all(components) do
		counter[component.s] = 0
	end

	return {
		draw=function()
			rect(52, 0, 76, 108, 5)
			for i, component in pairs(components) do
				local y = 2 * i + 8 * (i -1)
				spr(component.s, 54, y)
				print('x'..tostr(counter[component.s]), 64, y + 2, 7)
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
