pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- the amazing goblin's workshop
--   by brunopinheiro

-- "glossary"
--			act: active
--			comp: component
--			idx: index
--			nc: notification center
--			obj: object
--			txt: text
--			wc: wrapped component

-- core
printh('::::: new :::::')

local g_particles_pool

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

function int_hash_from(kvpairs)
	local hash = {}
	for kv in all(kvpairs) do
		hash[kv[1]] = kv[2]
	end
	return hash
end

local g_items={
	{ --night googles
		sprites={16,17,32,33},
		comps=int_hash_from({ {1, 10}, {4, 15}, {5, 20} })
	}
}

local g_characters={
	{64,65,80,81} -- dragon
}

local g_buttons={ l=0, r=1, u=2, d=3, o=4, x=5 }

nc = {
	events={},

	notify=function(self, event, params)
		local event_listeners = self.events[event] or {}
		for _, listener in pairs(event_listeners) do listener(params) end
	end,

	clean=function(self)
		self.events = {}
	end,

	listen=function(self, event, handler)
		self.events[event] = self.events[event] or {}
		add(self.events[event], handler)
	end
}

function spr4(sprites, x, y)
	spr(sprites[1], x, y)
	spr(sprites[2], x + 8, y)
	spr(sprites[3], x, y + 8)
	spr(sprites[4], x + 8, y + 8)
end

function try_call(obj, method, params)
	if obj and obj[method] then obj[method](obj, params) end
end

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
				try_call(anim, 'callback')
			end
		end
	}
end

function linear_ease(initial, final, time, duration)
	return (final - initial) * time/duration + initial
end

function steps_ease_with(steps)
	return function(initial, final, time, duration)
		local percentage = time/duration
		local index = clamp(flr(#steps * percentage) + 1, 1, #steps)
		return steps[index]
	end
end

function out_bounce_ease(initial, final, time, duration)
	local elapsed = time/duration
	local modifier = 0
	if elapsed < 1/2.75 then
		elapsed = elapsed
	elseif elapsed < 2/2.75 then
		elapsed = elapsed - 1.5/2.75
		modifier = 0.75
	elseif elapsed < 2.5/2.75 then
		elapsed = elapsed - 2.25/2.75
		modifier = 0.9375
	else
		elapsed = elapsed - 2.625/2.75
		modifier = 0.984375
	end
	return (final - initial) * (7.5625 * (elapsed^2) + modifier) + initial
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
	local request_triple_allowed = true

	function disallow_triple_request()
		request_triple_allowed = false
	end

	function request_triple(self)
		if request_triple_allowed then
			nc:notify(check_game_over() and 'machine_jammed' or 'request_triple')
		end
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
			nc:notify('comps_unwrapped')
		else
			request_triple()
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
			request_triple()
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

	return {
		max_y=max_y,

		init=function()
			nc:listen('shop_list_completed', disallow_triple_request)
			nc:listen('triple_glued', glue)
			nc:listen('triple_produced', set_act_triple)
		end,

		run=function()
			request_triple()
		end,

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

			try_call(act_triple, 'update', self)
		end,

		draw=function(self)
			for _, wc in pairs(wcs) do
				wc:draw()
			end

			try_call(act_triple, 'draw')
			try_call(act_triple, 'preview', self)

			rect(0, 0, 50, 108, 13)
			rect(1, 1, 49, 107, 6)
		end
	}
end

function new_machine_door(callback)
	local animator = new_animator()

	function close(door)
		animate(animator, 'close-l', {
			target=door,
			attr='lx',
			fv=64,
			ease=out_bounce_ease,
			duration=2
		})

		animate(animator, 'close-r', {
			target=door,
			attr='rx',
			fv=64,
			ease=out_bounce_ease,
			duration=2,
      callback=callback
		})
	end

	return {
		lx=-1, rx=129,
		close_ref=nil,

		init=function(self)
			self.close_ref = function() close(self) end
			nc:listen('machine_jammed', self.close_ref)
		end,

		update=function(self)
			animator:update()
		end,

		draw=function(self)
			rectfill(-1, 0, self.lx, 128, 4)
			rectfill(self.rx, 0, 129, 128, 4)
			line(self.lx, 0, self.lx, 128, 9)
			line(self.rx, 0, self.rx, 128, 9)
			for i=0, 10, 1 do
				pset(self.lx - 2, i * 12, 9)
				pset(self.rx + 2, i * 12 + 6, 9)
			end
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
				add(wcs, new_wc(comps[i].s, comps[i].c, x, y + (i - 1) * 8))
			end
			return wcs
		end,

		set_pos=function(new_x, new_y)
			x=new_x
			y=new_y
		end,

		component=function(idx)
			return comps[idx]
		end,

		update=function(self, machine)
			animator:update()
			try_swap()
			try_speedup()
			try_instant_glue(machine.max_y(x))
			move(machine.move_bounds(x, y + 16))
		end,

		draw=function(self, machine)
			for i, comp in pairs(comps) do
				spr(comp.s, x, y + (i - 1) * 8)
			end
		end,

		preview=function(self, machine)
			for i, comp in pairs(comps) do
				local comp_preview_y = machine.max_y(x) - (3 - i) * 8
				rect(x, comp_preview_y, x + 8, comp_preview_y + 7, comp.c)
			end
		end
	}
end

function new_wc(sprite, color, x, y)
	local animator = new_animator()

	function throw_particles(x, y, color)
		for i=5, flr(rnd(4) + 6), 1 do
				g_particles_pool:add(new_particle(
							x,
							y,
							rnd(2) + 1,
							color,
							{ x=rnd(4) - 2, y=-rnd(4) }
				))
		end
	end

	return {
		x=x, y=y,
		sprite=sprite,
		color=color,
		visible=true,

		unwrap=function(self, callback)
			delayed(animator, 'unwrapping', {
				duration=0.25,
				callback=function(running_loop)
					self.visible = not self.visible
					if not running_loop then
						throw_particles(self.x, self.y, self.color)
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
	local needed_comps, next_triple_comps = {}, nil

	function update_needed_comps(comps)
		needed_comps = comps
	end

	function random_comp()
		return g_comps[needed_comps[flr(rnd(#needed_comps)) + 1]]
	end

	function produce()
		local generating_comps = next_triple_comps and next_triple_comps or { random_comp(), random_comp(), random_comp() }
		next_triple_comps = { random_comp(), random_comp(), random_comp() }
		nc:notify('triple_produced', new_triple(generating_comps))
	end

	return {
		init=function()
			nc:listen('request_triple', produce)
			nc:listen('needed_comps', update_needed_comps)
		end,

		draw=function()
			print('n', 56, 1)
			print('e', 56, 7)
			print('x', 56, 13)
			print('t', 56, 19)
			rect(52, 0, 76, 25, 5)

			if next_triple_comps then
				spr(next_triple_comps[1].s, 66, 1)
				spr(next_triple_comps[2].s, 66, 9)
				spr(next_triple_comps[3].s, 66, 17)
			end
		end
	}
end

function new_item(item_def)
	local animator = new_animator()

	return {
		x = 56,
		y = 34,

		update=function()
			animator:update()
		end,

		draw=function(self)
			spr4(item_def.sprites, self.x, self.y)
		end,

		needed_comps=function()
			local comps = {}
			for comp, _ in pairs(item_def.comps) do add(comps, comp) end
			return comps
	  end,

		can_assemble=function(stored_comps)
			for comp, amount in pairs(item_def.comps) do
				if (stored_comps[comp] or 0) < amount then
					return false
				end
			end

			return true
		end,

		draw_needs=function(self, stored_comps)
			local count = 0
			for comp, amount in pairs(item_def.comps) do
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
				fv=self.x+10
			})
		end
	}
end

function new_arcade_customer()
	local item, stored_comps, assembling_items = nil, nil, {}

	function order()
		stored_comps = {}
		item = new_item(g_items[flr(rnd(#g_items)+1)])
		nc:notify('needed_comps', item and item.needed_comps() or {})
	end

	function store(comp)
		stored_comps[comp] = (stored_comps[comp] or 0) + 1

		if item and item.can_assemble(stored_comps) then
			item:disappear(function(i) del(assembling_items, i) end)
			add(assembling_items, item)
			nc:notify('new_order')
			order()
		end
	end

	return {
		init=function()
			nc:listen('component_unwrapped', store)
		end,

		run=function()
			order()
		end,

		update=function()
			for assembling_item in all(assembling_items) do
				assembling_item:update()
			end
		end,

		draw=function()
			print('want', 57, 29, 7)
			rect(52, 27, 76, 108, 5)

			try_call(item, 'draw')
			try_call(item, 'draw_needs', stored_comps)

			for assembling_item in all(assembling_items) do
				assembling_item:draw()
			end
		end
	}
end

-->8
-- particles
function new_particles_pool()
	local particles = {}

	function remove_particle(particle)
		del(particles, particle)
	end

	return {
		add=function(self, particle)
			particle.on_disappear = remove_particle
			add(particles, particle)
			particle:init()
		end,

		update=function(self)
			for particle in all(particles) do
				particle:update()
			end
		end,

		draw=function(self)
			for particle in all(particles) do
				particle:draw()
			end
		end
	}
end

g_particles_pool = new_particles_pool()

function new_particle(x, y, radius, color, impulse)
	local animator = new_animator()

	return {
			x=x, y=y,
			impulse=impulse,
			radius=radius,
			color=color,

			on_disappear=function() end,

			init=function(self)
				animate(animator, 'radius', {
					target=self,
					attr='radius',
					fv=0,
					duration=radius,
					callback=function() self:on_disappear() end
				})
			end,

			update=function(self)
				self.impulse.y = self.impulse.y + 0.1
				self.x = self.x + self.impulse.x
				self.y = self.y + self.impulse.y
				animator:update()
			end,

			draw=function(self)
				circfill(self.x, self.y, self.radius, self.color)
			end
	}
end

-->8
-- UI
function new_menu(x, y, w, h, options)
	local selected_item, visible = 1, false

	function move_selection(direction)
		selected_item = clamp(selected_item + direction, 1, #options)
	end

	return {
    open=function()
      visible = true
    end,

		update=function()
      if not visible then return end
			move_selection(btnp(g_buttons.d) and 1 or (btnp(g_buttons.u) and -1 or 0))

      if btnp(g_buttons.o) then
        options[selected_item].callback()
        visible = false
      end
		end,

		draw=function()
      if not visible then return end
      rectfill(x, y, x + w, y + h, 0)
			spr(9, x + 2, y + 2 + (selected_item - 1) * 8)
			for i=1, #options, 1 do
				print(options[i].text, x + 14, y + 2 + (i - 1) * 8, i == selected_item and 3 or 7)
			end
		end
	}
end

function new_typped_txt(txt, x, y, callback)
	local animator, completed, char_idx = new_animator(), false, 1

	function type(running_loop)
		if running_loop then
			char_idx = char_idx + 1
		else
			stop()
		end
	end

	function stop()
		animator:stop('typping')
		char_idx = #txt
		completed = true
	end

	return {
		run=function()
			delayed(animator, 'typping', { duration=0.05, callback=type, loops=#txt - 1 })
		end,

		update=function(self)
			animator:update()

			if completed and btnp(g_buttons.o) then
				callback()
			end
		end,

		draw=function(self)
			print(sub(txt, 1, char_idx), x, y)
		end
	}
end

function new_combo_counter()
	local count, blink, animator = 0, false, new_animator()

	function count_combo()
		count = count + 1
		delayed(animator, 'blink', {
			loops=10,
			duration=0.3,
			callback=function(looping)
				blink = not looping and false or not blink
			end
		})
	end

	function reset_combo()
		nc:notify('combo_finished', count)
		count = 0
		blink = false
	end

	return {
		init=function(self)
			nc:listen('comps_unwrapped', count_combo)
			nc:listen('request_triple', reset_combo)
		end,

		draw=function(self)
			if count > 1 then
				print('combo: '..count, 2, 120, blink and 10 or 8)
			end
		end,

		update=function(self)
			animator:update()
		end
	}
end

function new_scoreboard()
	local animator = new_animator()
	local multiplier, score, acc_score = 0, 0, 0
	local acc_visible, visual_score, visual_acc_score = false, 0, ''

	function increase_multiplier()
		multiplier = multiplier + 1
		update_visual_acc_score()
	end

	function update_visual_acc_score()
		if acc_score == 0 then return end
		acc_visible = true
		visual_acc_score = '+'..(acc_score * multiplier)
	end

	function accumulate(value)
		acc_score = acc_score + value
		update_visual_acc_score()
	end

	function count_score()
		local final_acc_score = acc_score * multiplier
		visual_score = score
		score = score + final_acc_score
		multiplier = 0
		acc_score = 0

		nc:notify('acc_score', final_acc_score)
		nc:notify('score', score)

		delayed(animator, 'score_feedback', {
			duration=2,
			callback=function()
				acc_visible = false
				visual_acc_score = ''
				visual_score = score
			end
		})
	end

	return {
		init=function()
			nc:listen('comps_unwrapped', increase_multiplier)
			nc:listen('component_unwrapped', function() accumulate(1) end)
			nc:listen('new_order', function() accumulate(100) end)
			nc:listen('request_triple', count_score)
		end,

		draw=function()
			rect(0, 110, 76, 126, 7)
			local score_text = 'score '..visual_score
			print(score_text, 2, 112, 7)
			if acc_visible then
				print(visual_acc_score, 4 + #score_text*4, 112, 3)
			end
		end,

		update=function()
			animator:update()
		end
	}
end

function new_records()
	local max_combo, max_acc_score, score, deliveries = 0, 0, 0, 0
	local visible = false

	function check_combo(combo)
		max_combo = max(max_combo, combo)
	end

	function check_acc_score(acc_score)
		max_acc_score = max(max_acc_score, acc_score)
	end

	function update_score(new_score)
		score = new_score
	end

	function increase_delivery()
		deliveries = deliveries + 1
	end

	return {
		init=function()
			nc:listen('new_order', increase_delivery)
			nc:listen('score', update_score)
			nc:listen('acc_score', check_acc_score)
			nc:listen('combo_finished', check_combo)
		end,

		show=function()
			visible = true
		end,

		draw=function()
		  if not visible then return end

			rectfill(2, 2, 64, 28, 0)
			print('max combo:  '..max_combo, 4, 4, 7)
			print('max earned: '..max_acc_score, 4, 10, 7)
			print('deliveries: '..deliveries, 4, 16, 7)
			print('score: '..score, 4, 22, 7)
		end
	}
end

-->8
-- scenes and levels
local g_scene_manager = {
	animator=new_animator(),
	current_scene=nil,
	next_scene=nil,

	open=function(self, scene)
		self.next_scene = scene
		if self.current_scene then
			self:close_current_scene()
		else
			self:present_next_scene()
		end
	end,

	close_current_scene=function(self)
		self.current_scene:unload()
		self:present_next_scene()
	end,

	present_next_scene=function(self)
		self.current_scene = self.next_scene
		self.next_scene = nil
		self.current_scene:init()
		try_call(self.current_scene, 'run')
	end,

	update=function(self)
		self.animator:update()
		try_call(self.current_scene, 'update')
	end,

	draw=function(self)
		try_call(self.current_scene, 'draw')
	end
}

function new_scene(objs)
	objs = objs or {}

	function for_each(method)
		return function()
			for obj in all(objs) do
				if obj[method] then obj[method](obj) end
			end
		end
	end

	return {
		init=for_each('init'),
		update=for_each('update'),
		draw=for_each('draw'),
		unload=function() nc:clean() end
	}
end

function new_splash_scene()
	local animator, x = new_animator(), 75

	function open_main_menu()
		delayed(animator, 'waiting_to_change', {
			duration=2,
			callback=function()
				g_scene_manager:open(new_logo_screen())
			end
			}
		)
	end

	local logo = {
		y=100,
		color=7,

		init=function(self)
			animate(animator, 'down', {
				target=self,
				attr='y',
				fv=120,
				duration=2,
				callback=open_main_menu
			})

			animate(animator, 'fade', {
				target=self,
				attr='color',
				fv=1,
				duration=2,
				ease=steps_ease_with({ 7, 6, 5, 0 })
			})
		end,

		draw=function(self)
			cls(7)
			print('pine brothers', x, self.y, self.color)
		end,

		update=function(self)
			animator:update()
		end
	}

	return new_scene({ logo })
end

function new_logo_screen()
	local main_menu = new_menu(30, 56, 46, 24, {
		{ text='arcade', callback=function() g_scene_manager:open(new_arcade_screen()) end },
		{ text='lore', callback=function() end },
		{ text='credits', callback=function() end }
	})

	main_menu:open()

	return new_scene({ main_menu })
end

function new_arcade_screen()
	local machine, customer, records = new_machine(), new_arcade_customer(), new_records()

	function retry()
		g_scene_manager:open(new_arcade_screen())
	end

	function exit()
		g_scene_manager:open(new_logo_screen())
	end

  local gameover_menu = new_menu(45, 56, 40, 16, {
    { text='retry', callback=retry },
    { text='exit', callback=function() printh('exiting...') end }
  })

  local game_objects = {
    machine,
    new_factory(),
    customer,
    new_combo_counter(),
		new_scoreboard(),
    new_machine_door(function()
			records:show()
			gameover_menu:open()
		end),
		records,
    gameover_menu
  }

	return merged(new_scene(game_objects), {
		run=function()
			customer:run()
			machine:run()
		end
	})
end

-->8
-- game loop
function _init()
	g_scene_manager:open(new_splash_scene())
end

function _update60()
	g_scene_manager:update()
	g_particles_pool:update()
end

function _draw()
	cls()
	g_scene_manager:draw()
	g_particles_pool:draw()
end

__gfx__
00000000056666500004400004222140000ddd5000cccc000b300b30000550000009800000000000000000000000000000000000000000000000000000000000
00000000567777650049940002efee2000dd6dd500cccc00bbbbbbbb005dd5000089880000000000000000000000000000000000000000000000000000000000
0070070067775776049aa94002e8ee200dd776d50ccaacc03bbba9b3055dd5500899988000bbbbba000000000000000000000000000000000000000000000000
000770006777557649affa9402e88e20dd7776d50ca9aac00bbaa9b0555d1d5508999988bbb33330000000000000000000000000000000000000000000000000
000770006775777649affa9402ee8e20d7776dd00caa9ac00baa9bb055d161d5889aa9883b3bb300000000000000000000000000000000000000000000000000
0070070067577776049aa94002e88e20dd76dd50cca9aaccbba9bbbb55dd11d5889aa9803bb33000000000000000000000000000000000000000000000000000
00000000567777650049940002e8ee200dddd500cccaaccc3bbbbbb3055ddd55089aaa9003300000000000000000000000000000000000000000000000000000
0000000005666650000440000412224000dd5000ccc66ccc0b300b3000555550009aa90000000000000000000000000000000000000000000000000000000000
00000000000000000000000000440000000000ddd500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000004004000000005555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000004004000000ddddddddd500000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000004004000000c66666666c00000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000080aa0000008000000000400400000c6686866866c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
000080aa9a00008000000000004400000c66666888669c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800a9aa00080000666666666665000c68668889866cc000000000000000000000000000000000000000000000000000000000000000000000000000000000
0080000aa0008000066666666d6d66500c666989998666c000000000000000000000000000000000000000000000000000000000000000000000000000000000
008880888088800006655b5666d666500c668899998666c000000000000000000000000000000000000000000000000000000000000000000000000000000000
08ccc80008ccc8000665b5b66d6d66500c68899aa998a6c000000000000000000000000000000000000000000000000000000000000000000000000000000000
08ccc80008ccc800066b5556666666500c6699aaa99966c000000000000000000000000000000000000000000000000000000000000000000000000000000000
08ccc80008ccc800066666666696665000c689aaaaa96c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
0088800000888000066087776999665000c689aaaa966c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000666666666966650000cccccccccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000066666666666500005555555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000ddddddddddddd5000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000868886000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000ccc688ccc800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000c777c8c777c80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c71117c71117c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c71117c71117c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c71117c71117c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0002c777c8c777c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00288ccc888ccc020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02888882888888220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
080808280a8888220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02888280aaa888820000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0822280aa9aa88880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0088800a9a9aa8880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000a9a9a9a8880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000a9a99a9a8880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
