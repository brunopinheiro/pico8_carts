pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- the amazing goblin's workshop
--   by brunopinheiro

-- "glossary"
--			act: active
--			comp: component
-- 		comps: components
--			nc: notification center
--			wc: wrapped component
-- 		wcs: wrapped components

-- core
printh('::::: new :::::')

local g_comps={
	{s=1,  c=6}, -- screw
	{s=2,  c=9}, -- gear
	{s=3, c=14}, -- wire
	{s=4, c=13}, -- iron
	{s=5, c=12}, -- lamp
	{s=6, c=11}, -- energy
	{s=7,  c=5}, -- oil
	{s=8,  c=8}  -- fire
}

function needed_comps(comp_pairs)
	local needs = {}
	for comp_pair in all(comp_pairs) do
		needs[comp_pair[1]] = comp_pair[2]
	end
	return needs
end

local g_items_spec={
	{
		ss={16,17,32,33},
		needs=needed_comps({{1, 3}, {4, 3}, {5, 3}})
	} -- night googles
}

local g_buttons={ l=0, r=1, u=2, d=3, o=4, x=5 }

nc = {
	events={},

	notify=function(self, event, params)
		local event_listeners = self.events[event] or {}
		for _, listener in pairs(event_listeners) do listener(params) end
	end,

	listen=function(self, event, handler)
		self.events[event] = self.events[event] or {}
		add(self.events[event], handler)
	end,

	stop=function(self, event, handler)
		if self.events[event] then
			remove(self.events[event], handler)
		end
	end
}

function clamp(val, minimun, maximum)
	return min(maximum, max(minimun, val))
end

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
			local completed = {}
			for k, anim in pairs(self.animations) do
				if not anim.update() then
					completed[k] = anim
				end
			end
			for k, anim in pairs(completed) do
				self:stop(k)
				if anim.callback then anim.callback(anim) end
			end
		end
	}
end

function linear_ease(initial, final, time, duration)
	return (final - initial) * time/duration + initial
end

function in_back_ease(overshoot)
	overshoot = overshoot or 1.70158
	return function(initial, final, time, duration)
		local elapsed = time/duration
		return (final - initial) * (elapsed ^ 2) * ((overshoot + 1) * elapsed - overshoot) + initial
	end
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
		target[attr] = ease(ov, fv, td, duration)
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
		ease_update,
		(loops ~= 0) and loop_callback or callback
	)
end

-->8
-- gameplay
function new_machine()
	local act_triple, animator, wcs = nil, new_animator(), {}
	local ix, iy, fx, fy = 2, 2, 42, 98

	function run(self)
		nc:notify(check_game_over() and 'machine_jammed' or 'request_triple')
	end

	function glue()
		glue_comps(act_triple.wcs())
		act_triple = nil
		collect()
	end

	function glue_comps(target_wcs)
		for wc in all(target_wcs) do
			wcs[pos_to_coords(wc.x, wc.y)] = wc
		end
	end

	function set_act_triple(triple)
		act_triple = triple
	end

	function pos_to_coords(x, y)
		return 'c'..x..'r'..y
	end

	-- have a state for highest y (maybe by x)
	function check_game_over()
		for _, wc in pairs(wcs) do
			if wc.y < -8 then
				return true
			end
		end

		return false
	end

	function wc_at(x, y)
		return wcs[pos_to_coords(x, y)]
	end

	function max_y(x)
		for y=fy, iy, -8 do
			if not wc_at(x, y) then return y end
		end

		return iy
	end

	function collect()
		for _, wc in pairs(wcs) do
			collect_direction(wc, 8, -8, { wc })
			collect_direction(wc, 8,  0, { wc })
			collect_direction(wc, 8,  8, { wc })
			collect_direction(wc, 0,  8, { wc })
		end

		if remove_marked() then
			delayed(animator, 'wait_gravity', { duration = 2.2, callback=function() gravity() end })
		else
			run()
		end
	end

	function collect_direction(current_wc, x, y, stack)
		local next_wc = wc_at(current_wc.x + x, current_wc.y + y)

		if not next_wc or next_wc.sprite ~= current_wc.sprite then
			if #stack >= 3 then
				for wc in all(stack) do
					wc.marked = true
				end
			end

			return
		end

		add(stack, next_wc)
		collect_direction(next_wc, x, y, stack)
	end

	function remove_marked()
		local unwrapped = false

		for _, wc in pairs(wcs) do
			if wc.marked then
				unwrapped = true
				wc:unwrap(remove_wc)
			end
		end

		return unwrapped
	end

	function gravity()
		local moved = false

		for y=fy, iy, -8 do
			for x=ix, fx, 8 do
				moved = gravity_wc(wc_at(x, y)) or moved
			end
		end

		if moved then
			collect()
		else
			run()
		end
	end

	function remove_wc(wc)
		wcs[pos_to_coords(wc.x, wc.y)] = nil
	end

	function gravity_wc(wc)
		if not wc then return false end

		local dest_y = max_y(wc.x)
		if dest_y > wc.y then
			remove_wc(wc)
			wc.y = dest_y
			glue_comps({ wc })
			return true
		end

		return false
	end

	nc:listen('triple_glued', glue)
	nc:listen('triple_produced', set_act_triple)

	return {
		max_y=max_y,
		turn_on=run,

		move_bounds=function(x, y)
			return {
				left=(wc_at(x - 8, y) or x - 8 < ix) and 0 or -8,
				right=(wc_at(x + 8, y) or x + 8 > fx) and 0 or 8,
				bottom=(wc_at(x, y + 8) or y + 8 > fy) and 0 or 8
			}
		end,

		update=function(self)
			animator:update()

			for _, wc in pairs(wcs) do
				wc:update()
			end

			if act_triple then
				act_triple.update(self)
			end
		end,

		draw=function(self)
			for _, wc in pairs(wcs) do
				wc:draw()
			end

			if act_triple then
				act_triple.draw()
				act_triple.preview(self)
			end

			rect(0, 0, 50, 108, 13)
			rect(1, 1, 49, 107, 6)
		end
	}
end

function new_triple(comps)
	local animator = new_animator()
	local x, y  = 2, -30
	local fall_locked, fall_speedup = false, 0
	local hor_locked = false
	local glue_attempts = 0

	function glue_itself()
		nc:notify('triple_glued')
	end

	function try_swap()
		if btnp(g_buttons.x) then
			swap(comps, 1, 2)
			swap(comps, 1, 3)
		end
	end

	function try_speedup()
		if btn(g_buttons.d) then
			if fall_locked and fall_speedup == 0 then
				fall_locked = false
			end
			fall_speedup = 0.95
		else
			fall_speedup = 0
		end
	end

	function try_instant_glue(max_y)
		if btnp(g_buttons.o) then
			y = max_y - 16
			fall_locked = true
			hor_locked = true
			animator:stop('fall')
			delayed(animator, 'instant_glue', { duration=0.5, callback=glue_itself })
		end
	end

	function try_glue(bounds_bottom)
		if bounds_bottom == 0 then
			if glue_attempts < 2 then
				glue_attempts = glue_attempts + 1
			else
				glue_itself()
			end
		else
			glue_attempts = 0
		end
	end

	function fall_delay()
		return glue_attempts > 0 and 0.8 or 1 - fall_speedup
	end

	function move(bounds)
		-- horizontal
		if not hor_locked then
			local hor = btnp(g_buttons.l) and bounds.left or (btnp(g_buttons.r) and bounds.right or 0)
			x = x + hor
		end

		-- vertical
		if not fall_locked then
			fall_locked = true
			y = y + bounds.bottom
			try_glue(bounds.bottom)
			delayed(animator, 'fall', { duration=fall_delay(), callback=function() fall_locked = false end })
		end
	end

	return {
		pos=function() return {x=x, y=y} end,

		wcs=function()
			local wcs = {}
			for i=1, 3 do
				add(wcs, new_wc(comps[i].s, x, y + (i - 1) * 8))
			end
			return wcs
		end,

		set_pos=function(new_x, new_y)
			x=new_x
			y=new_y
		end,

		component=function(index)
			return comps[index]
		end,

		update=function(machine)
			animator:update()
			try_swap()
			try_speedup()
			try_instant_glue(machine.max_y(x))
			move(machine.move_bounds(x, y + 16))
		end,

		draw=function()
			for i, comp in pairs(comps) do
				spr(comp.s, x, y + (i - 1) * 8)
			end
		end,

		preview=function(machine)
			for i, comp in pairs(comps) do
				local comp_preview_y = machine.max_y(x) - (3 - i) * 8
				rect(x, comp_preview_y, x + 8, comp_preview_y + 7, comp.c)
			end
		end
	}
end

function new_wc(sprite, x, y)
	local animator = new_animator()

	return {
		x=x, y=y,
		sprite=sprite,
		visible=true,

		unwrap=function(self, callback)
			delayed(animator, 'unwrapping', {
				duration=0.25,
				callback=function(running_loop)
					self.visible = not self.visible
					if not running_loop then
						callback(self)
						nc:notify('component_unwrapped', self.sprite)
					end
				end,
				loops=8
			})
		end,

		update=function()
			animator:update()
		end,

		draw=function(self)
			if self.visible then
				spr(self.sprite, self.x, self.y)
			end
		end
	}
end

function new_factory()
	function produce()
		next_triple = new_triple({
			g_comps[1],
			g_comps[4],
			g_comps[5]
		})

		next_triple.set_pos(66, 1)

		nc:notify('triple_produced', new_triple({
			g_comps[1],
			g_comps[4],
			g_comps[5]
		}))
	end

	nc:listen('request_triple', produce)

	return {
		draw=function()
			print('n', 56, 1)
			print('e', 56, 7)
			print('x', 56, 13)
			print('t', 56, 19)
			rect(52, 0, 76, 25, 5)
			next_triple.draw()
		end
	}
end

function new_item(item_spec, ix, iy)
	local animator = new_animator()

	return {
		x=ix, y=iy,

		update=function()
			animator:update()
		end,

		draw=function(self)
			spr(item_spec.ss[1], self.x, self.y)
			spr(item_spec.ss[2], self.x + 8, self.y)
			spr(item_spec.ss[3], self.x, self.y + 8)
			spr(item_spec.ss[4], self.x + 8, self.y + 8)
		end,

		can_assemble=function(stored_comps)
			for comp, amount in pairs(item_spec.needs) do
				if (stored_comps[comp] or 0) < amount then
					return false
				end
			end

			return true
		end,

		draw_needs=function(self, stored_comps)
			local count = 0
			for comp, amount in pairs(item_spec.needs) do
				local needed_amount = clamp(amount - (stored_comps[comp] or 0), 0, amount)
				local ry = self.y + 16 + (count * 10)
				spr(comp, self.x - 2, ry)
				print('x'..(needed_amount > 9 and '' or '0')..tostr(needed_amount), self.x + 8, ry + 2, 7)
				count = count + 1
			end
		end,

		disappear=function(self, callback)
			animate(animator, 'falling_y', {
				target=self,
				ease=in_back_ease(2),
				attr='y',
				duration=0.8,
				callback=function() callback(self) end,
				fv=140
			})

			animate(animator, 'falling_x', {
				target=self,
				attr='x',
				duration=0.8,
				fv=ix+10
			})
		end
	}
end

function new_customer()
	local item, stored_comps, assembling_items = nil, nil, {}

	function order()
		item = new_item(g_items_spec[1], 56, 34)
		stored_comps = {}
	end

	function store(comp)
		stored_comps[comp] = (stored_comps[comp] or 0) + 1

		if item.can_assemble(stored_comps) then
			item:disappear(function(i) del(assembling_items, i) end)
			add(assembling_items, item)
			order()
		end
	end

	nc:listen('component_unwrapped', store)
	order()

	return {
		update=function()
			for assembling_item in all(assembling_items) do
				assembling_item:update()
			end
		end,

		draw=function()
			print('want', 57, 29, 7)
			rect(52, 27, 76, 108, 5)

			item:draw()
			item:draw_needs(stored_comps)

			for assembling_item in all(assembling_items) do
				assembling_item:draw()
			end
		end
	}
end

-->8
-- game loop
local machine, factory, warehouse, director, customer

function _init()
	factory = new_factory()
	machine = new_machine()
	machine:turn_on()
	customer = new_customer()
end

function _update60()
	machine:update()
	customer:update()
end

function _draw()
	cls()
	machine:draw()
	factory:draw()
	customer:draw()
end

__gfx__
00000000056666500004400004222140000ddd5000cccc000b300b30000550000009800000000000000000000000000000000000000000000000000000000000
00000000567777650049940002efee2000dd6dd500cccc00bbbbbbbb005dd5000089880000000000000000000000000000000000000000000000000000000000
0070070067775776049aa94002e8ee200dd776d50ccaacc03bbba9b3055dd5500899988000000000000000000000000000000000000000000000000000000000
000770006777557649affa9402e88e20dd7776d50ca9aac00bbaa9b0555d1d550899998800000000000000000000000000000000000000000000000000000000
000770006775777649affa9402ee8e20d7776dd00caa9ac00baa9bb055d161d5889aa98800000000000000000000000000000000000000000000000000000000
0070070067577776049aa94002e88e20dd76dd50cca9aaccbba9bbbb55dd11d5889aa98000000000000000000000000000000000000000000000000000000000
00000000567777650049940002e8ee200dddd500cccaaccc3bbbbbb3055ddd55089aaa9000000000000000000000000000000000000000000000000000000000
0000000005666650000440000412224000dd5000ccc66ccc0b300b3000555550009aa90000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000080aa00000080006666666666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000080aa9a0000800066111111111116000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800a9aa0008000661111111111167000008000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0080000aa00080006666666666666679000088800088800000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888088808880006777988897777679000880080880880000000000000000000000000000000000000000000000000000000000000000000000000000000000
08ccc80008ccc8006777988897777679000880882800880000000000000000000000000000000000000000000000000000000000000000000000000000000000
08ccc80008ccc8006777988897777679006688828288866600000000000000000000000000000000000000000000000000000000000000000000000000000000
08ccc80008ccc8006777988897777679066777988897777600000000000000000000000000000000000000000000000000000000000000000000000000000000
00888000008880006777988897777679666666666666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006777988897777660667779888977777600000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006777988897777600677779888977776000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006666666666666000666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000