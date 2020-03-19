pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- ldr
--  by brunopinheiro
--  camera shake based on @krystman's https://www.lexaloffle.com/bbs/?tid=28306

-- core
local btn_left, btn_right, btn_up, btn_down, btn_o, btn_x = 0, 1, 2, 3, 4, 5

local collision_mapping={
	bullet       = { 'enemy' },
	enemy        = { 'player' },
	enemy_bullet = { 'player' }
}

local scene

function _init()
	scene = c_levelone()
end

function _update60()
	scene:update()
end

function _draw()
	cls()
	scene:draw()
end

function call(method)
	return function(t) t[method](t) end
end

function partial(obj, method, ...)
	local fst, snd, trd = ...
	return function() obj[method](obj, fst, snd, trd) end
end

-- todo: refactor (debug)
function validate_args(t, keys)
	missing_args=''
	for k in all(keys) do
		if t[k] == nil then missing_args = missing_args .. tostr(k) .. ', ' end
	end

	if missing_args ~= '' then
		printh('error: table does not contains mandatory args: ' .. missing_args)
		return false
	end

	return true
end

function merge(t1, t2)
	local merged = {}
	for k, v in pairs(t1) do merged[k] = v end
	if t2 then for k, v in pairs(t2) do merged[k] = v end end
	if merged.init then merged:init() end
	return merged
end

nc = {
	listeners = {},

	add_listener = function(self, notification, listener)
		self.listeners[notification] = self.listeners[notification] or {}
		add(self.listeners[notification], listener)
	end,

	remove_listener = function(self, notification, listener)
		if self.listener[notification] then
			del(self.listeners[notification], listener)
		end
	end,

	notify = function(self, notification)
		local listeners = self.listeners[notification] or {}
		for _, v in pairs(listeners) do v() end
	end
}

function c_gameobject()
	return {
		animator = c_animator(),

		update = function(self)
			self.animator:update()
		end,

		draw = function() end,

		wait = function(self, name, duration, callback, loops)
			local it=time()
			loops = loops or 0

			self.animator:animate(
				name,
				nil,
				function() return time() - it < duration end,
				(loops ~= 0) and function()
					if callback then callback() end
					self:wait(name, duration, callback, loops - 1)
				end or callback
			)
		end,

		ease_animate = function(self, name, args)
			if not validate_args(args, { 'attr', 'duration' }) then return end
			local loops = args.loops or 0
			local ease = args.ease or linear_ease
			local target = args.target or self

			local it=time()
			local ov=target[args.attr]

			local fv = args.fv

			local callback = args.callback
			if loops ~= 0 then
				callback = function()
					if args.bounce_loop then
						fv = ov
						ov = args.fv
					end

					target[args.attr]=ov
					self:ease_animate(name, merge(args, { loops=loops-1, fv=fv }))
				end
			end

			self.animator:animate(
				name,
				target,
				function()
					local td=time()-it
					target[args.attr]=ease(ov, fv, td, args.duration)
					return td < args.duration
				end,
				callback
			)
		end,

		add_to_scene = function(self, scene)
			add(scene.objects, self)
			self.scene=scene
		end,

		remove_from_scene = function(self)
			if self.scene then del(self.scene.objects, self) end
			self.scene=nil
		end
	}
end

-->8
-- physics
function c_rect(x, y, w, h)
	return { x1 = x, x2 = x+w, y1 = y, y2 = y+h }
end

function rects_collide(r1, r2)
	return r1.x1 <= r2.x2 and r1.x2 >= r2.x1 and r1.y1 <= r2.y2 and r1.y2 >= r2.y1
end

function simulate_physics(objs)
	local layer_map={}

	for obj in all(objs) do
		if obj.layer then
			if not layer_map[obj.layer] then layer_map[obj.layer] = {} end
			add(layer_map[obj.layer], obj)
		end
	end

	for origin_layer, target_layers in pairs(collision_mapping) do
		for origin in all(layer_map[origin_layer] or {}) do
			for target_layer in all(target_layers) do
				for target in all(layer_map[target_layer] or {}) do
					if rects_collide(origin:bounding_box(), target:bounding_box()) then
						origin:collide(target)
						target:collide(origin)
					end
				end
			end
		end
	end
end

-->8
-- animations
function c_animator()
	return {
		animations = {},

		animate = function(self, name, target, update, callback)
			self.animations[name]={ name = name, target = target, update = update, callback = callback }
		end,

		stop = function(self, name)
			self.animations[name]=nil
		end,

		update = function(self)
			local completed={}
			for k, anim in pairs(self.animations) do
				if not anim.update() then add(completed, anim) end
			end
			for anim in all(completed) do
				self:stop(anim.name)
				if anim.callback then anim.callback(anim.target) end
			end
		end
	}
end

function linear_ease(initial, final, time, duration)
	return (final - initial) * time/duration + initial
end

function in_cubic_ease(initial, final, time, duration)
	return (final - initial) * (time/duration)^3 + initial
end

function out_cubic_ease(initial, final, time, duration)
	return (final - initial) * ((time/duration - 1)^3 + 1) + initial
end

function in_out_cubic_ease(initial, final, time, duration)
	local elapsed = time/(duration * 0.5)
	if elapsed < 1 then
		return (final - initial) * 0.5 * (elapsed^3) + initial
	else
		return (final - initial) * 0.5 * ((elapsed - 2)^3 + 2) + initial
	end
end

function out_back_ease_with(overshoot)
	overshoot = (overshoot or 1.70158) * 1.525

	return function(initial, final, time, duration)
		local delta = final - initial
		local elapsed = time/(duration * 0.5)
		if elapsed < 1 then
			return delta * 0.5 * ((elapsed^2) * ((overshoot+1) * elapsed - overshoot)) + initial
		else
			elapsed-=2
			return delta * 0.5 * ((elapsed^2) * ((overshoot+1) * elapsed + overshoot) + 2) + initial
		end
	end
end

function stepped_ease_with(steps, ease)
	ease = ease or linear_ease
	return function(initial, final, time, duration)
		return steps[flr(ease(1, #steps + 1, time, duration))]
	end
end

-->8
-- scenes
function c_gamescene()
	return merge(c_gameobject(), {
		particles = {},
		objects = {},

		shake = function(self, args)
			local it=time()
			local strength = args.strength or 2
			local duration = args.duration or 1
			local ease = args.ease or linear_eas

			self.animator:animate(
				'shake',
				nil,
				function()
					local td=time()-it
					local sf=ease(1, 0, td, duration)
					local x = (-strength + rnd(strength*2)) * sf
					local y = (-strength + rnd(strength*2)) * sf
					camera(x,y)
					return td < duration
				end,

				args.callback
			)
		end,

		update = function(self)
			self.animator:update()
			simulate_physics(self.objects)
			self.background:update()
			foreach(self.particles, call('update'))
			foreach(self.objects, call('update'))
		end,

		draw = function(self)
			self.background:draw()
			foreach(self.particles, call('draw'))
			foreach(self.objects, call('draw'))
		end
	})
end

function c_galaxy()
	return merge(c_gameobject(), {
		elasticity = 5,
		star_count = 0,
		stars = {},

		init = function(self)
			for i=1, 20 do self:create_star() end
			self:ease_animate('elasticity', { attr='elasticity', fv=0, duration=4, ease=out_cubic_ease })
		end,

		create_star = function(self)
			local colors={ 1, 2, 4, 7, 9 }
			local star={ x=rnd(128), y=-16 + rnd(16), r=rnd(1), c=colors[ceil(rnd(#colors))] }
			add(self.stars, star)
			self:ease_animate('star_mov_' .. self.star_count, {
				target=star,
				attr='y',
				fv=132,
				duration=(self.elasticity > 0) and rnd(10 - self.elasticity) or 5 + rnd(123),
				ease=linear_ease,
				callback=partial(self, 'replace_star', star)
			})
			self.star_count += 1
		end,

		replace_star = function(self)
			del(self.stars, star)
			self:create_star()
		end,

		draw = function(self)
			for star in all(self.stars) do
				if(self.elasticity <= 0) then
					circfill(star.x, star.y, star.r, star.c)
				else rectfill(
					star.x-star.r*0.5,
					star.y-star.r*0.5,
					star.x+star.r*0.5,
					star.y+star.r*0.5 + self.elasticity * 2,
					star.c
				) end
			end
		end
	})
end

function c_alert(title, bc1, bc2, fc1, fc2)
	return merge(c_gameobject(), {
		h = 0,
		print_text = false,
		background_color = bc1,
		text_color = fc1,

		init = function(self)
			self:ease_animate('open', { attr='h', fv=20, duration=1, ease=linear_ease, callback=partial(self, 'present')})
		end,

		present = function(self)
			self.print_text = true
			self:wait('blink', 0.2, partial(self, 'toggle_colors'), 10)
			self:wait('wait_to_close', 2, partial(self, 'close'))
		end,

		toggle_colors = function(self)
			self.background_color = (self.background_color == bc1) and bc2 or bc1
			self.text_color = (self.text_color == fc1) and fc2 or fc1
		end,

		close = function(self)
			self.print_text = false
			self:ease_animate('close', { attr='h', fv=0, duration=1, ease=linear_ease, callback=partial(self, "remove_from_scene")})
		end,

		draw = function(self)
			rectfill(0, 64 - self.h * 0.5, 128, 64 + self.h * 0.5, self.background_color)
			if self.print_text then print(title, 64 - #title * 2, 61, self.text_color) end
		end
	})
end

function c_levelscene()
	return merge(c_gamescene(), {
		init = function(self)
			c_alert('get ready', 1, 1, 9, 10):add_to_scene(self)
			c_ship():add_to_scene(self)
		end
	})
end

function c_levelone()
	local scene = merge(c_levelscene(), {
		background = c_galaxy(),
		removed_enemies = 0,

		show_boss = function(self)
			c_alert('warning', 8, 9, 10, 8):add_to_scene(self)
		end
	})

	local enemy_count = 0
	local enemy_removed_handler = function()
		enemy_count += 1
		if(enemy_count >= 36) scene:wait('wait_boss', 2, partial(scene, 'show_boos'))
	end

	nc:add_listener('enemy_removed', enemy_removed_handler)

	scene:wait('wave_1', 5, function()
		c_enemyspawner({ factory = c_zminion }):add_to_scene(scene)
	end)

	scene:wait('wave_2', 15, function()
		c_enemyspawner({ x = 120, factory = c_zminion }):add_to_scene(scene)
	end)

	scene:wait('wave_3', 25, function()
		c_enemyspawner({ factory = c_zminion }):add_to_scene(scene)
		c_enemyspawner({ x = 120, factory = c_zminion }):add_to_scene(scene)
	end)

	scene:wait('wave_4', 40, function()
		c_enemyspawner({ x = -8, delay = 2, factory = c_uminion }):add_to_scene(scene)
	end)

	scene:wait('wave_5', 50, function()
		c_enemyspawner({ x = 136, delay = 2, factory = c_uminion }):add_to_scene(scene)
	end)

 	return scene
end

--> 8
-- particles
function c_particle(x, y, radius, color)
	return merge(c_gameobject(), {
		x = x,
		y = y,
		r = radius,
		c = color,

		draw = function(self)
			circfill(self.x, self.y, self.r, self.c)
		end,

		add_to_scene = function(self, scene)
			add(scene.particles, self)
			self.scene = scene
		end,

		remove_from_scene = function(self)
			del(self.scene.particles, self)
			self.scene = nil
		end
	})
end

function c_explosion(scene, args)
	if not validate_args(args, { 'x', 'y' }) then return end
	local colors = args.colors or { 8, 9, 10 }
	local max_radius = args.radius or 5
	local amount = args.amount or 50

	for i=1, amount do
		local anim_time = rnd(args.time or 1)
		local p = c_particle(args.x, args.y, 0.1 + rnd(max_radius), colors[ceil(rnd(#colors))])
		p:ease_animate('hmove'..i, { attr='x', fv=-10 + rnd(20) + p.x, duration=anim_time, ease=in_out_cubic_ease })
		p:ease_animate('vmove'..i, { attr='y', fv=-10 + rnd(20) + p.y, duration=anim_time, ease=in_out_cubic_ease, callback=partial(p, 'remove_from_scene') })
		p:ease_animate('radius'..i, { attr='r', fv=0, duration=anim_time, ease=in_out_cubic_ease })
		p:add_to_scene(scene)
	end
end

function c_smoke(scene, args)
	if not validate_args(args, { 'x', 'y' }) then return end
	local amount = args.amount or 10
	local color_steps = args.color_steps or { 7, 6, 6, 5, 5 }

	for i=1, amount do
		local anim_time = 0.1 + rnd(2)
		local p = c_particle(args.x + rnd(4) - 2, args.y, 0.1, 7)
		p:ease_animate('hmove'..i, { attr='x', fv=-4 + rnd(8) + p.x, duration=anim_time, ease=out_cubic_ease })
		p:ease_animate('vmove'..i, { attr='y', fv=60 + rnd(40) + p.y, duration=anim_time, ease=out_cubic_ease, callback=partial(p, 'remove_from_scene') })
		p:ease_animate('radius'..i, { attr='r', fv=2 + rnd(3), duration=anim_time, ease=out_cubic_ease })
		p:ease_animate('color'..i, { attr='c', ease=stepped_ease_with(color_steps), duration=anim_time })
		p:add_to_scene(scene)
	end
end

-->8
-- player
function c_ship()
	return merge(c_gameobject(), {
		x = 64,
		y = 136,
		speed = 1.5,
		movement = 'up',
		layer = 'player',
		draw_warning = false,
		damaged = false,
		smoking = false,
		palette = {},
		recovering_palette_steps = {
			{{12, 11}},
			{{12, 3},{9, 11}},
			{{9, 3},{7, 11}},
			{{7, 3},{6, 11},{8, 11}},
			{{6, 3},{8, 3}},
			{}
		},

		init = function(self)
			self:ease_animate('intro', { attr='y', fv=84, duration=4, ease=out_back_ease_with(1.70158 * 8), callback=partial(self, 'enable_controllers')})
			self:wait('accelerating', 0.05, partial(self, 'accelerate'), 60)
		end,

		accelerate = function(self)
			c_smoke(self.scene, { x=self.x, y=self.y, amount=3, color_steps={ 7, 7, 12, 12, 1 } })
		end,

		collide = function() end,

		bounding_box = function(self)
			if self.movement == "up" then
				return c_rect(self.x-8, self.y-4, 16, 8)
			else
				return c_rect(self.x-4, self.y-4, 8, 8)
			end
		end,

		enable_controllers = function(self)
			self.control_movement = c_controller_movement(self)
			self.control_gun = c_controller_gun(self)
		end,

		update = function(self)
			self.animator:update()

			if self.control_movement then self.control_movement:update() end
			if self.control_gun then self.control_gun:update() end

			-- todo: debug
			if btnp(btn_x) then self:damage() end
		end,

		inflict_damage = function(self, fatal)
			if fatal or self.damaged then
				self:explode()
			else
				self:damage()
			end
		end,

		explode = function(self)
			c_explosion(self.scene, { x=self.x, y=self.y, colors={ 6, 7, 12 }, max_radius=3, amount=10 })
			self:remove_from_scene()
		end,

		smoke = function(self)
			if self.damaged then
				c_smoke(self.scene, { x=self.x - 1, y=self.y, amount=5 })
				c_smoke(self.scene, { x=self.x + 1, y=self.y, amount=5 })
			end
		end,

		damage = function(self)
			self.damaged=true
			self.animator:stop('recover')
			self.animator:stop('recovering')
			self.palette={}
			self.scene:shake({ strength=10, duration=0.5, ease=in_cubic_ease })
			self:wait('recover', 10, partial(self, 'recover'))
			self:wait('smoking', 0.2, partial(self, 'smoke'), -1)
			self:wait('warning', 0.3, partial(self, 'toggle_warning'), -1)
		end,

		toggle_warning = function(self)
			self.warning = not self.warning
		end,

		recover = function(self)
			self.damaged=false
			self.smoking=false
			self.warning=false
			self.animator:stop('smoking')
			self.animator:stop('warning')
			self:ease_animate('recovering', { attr='palette', ease=stepped_ease_with(self.recovering_palette_steps), duration=0.5, loops=3 })
		end,

		draw = function(self)
			if self.warning then
				spr(16, 110, 110)
				spr(16, 118, 110, 1, 1, true)
				spr(32, 110, 118)
				spr(32, 118, 118, 1, 1, true)
			end

			for pair in all(self.palette) do
				pal(pair[1], pair[2])
			end

			if self.movement == 'up' then
				spr(1, self.x-8, self.y-4, 1, 1, false)
				spr(1, self.x, self.y-4, 1, 1, true)
			else
				spr(2, self.x-4, self.y-4, 1, 1, self.movement ~= 'left')
			end

			pal()
		end
	})
end

function c_controller_movement(ship)
	return {
		update=function(self)
			local speed = ship.damaged and ship.speed-1 or ship.speed

			if btn(btn_left) then
				ship.movement = 'left'
				ship.x-=speed
			else
				if btn(btn_right) then
					ship.movement = 'right'
					ship.x+=speed
				else
					ship.movement = 'up'
				end
			end

			if btn(btn_up) then
				ship.y-=speed
			else
				if btn(btn_down) then ship.y+=speed end
			end

			ship.x = min(120, max(8, ship.x))
			ship.y = min(124, max(4, ship.y))
		end
	}
end

function c_controller_gun(ship)
	return {
		update=function()
			if btnp(btn_o) then c_bullet(ship.x, ship.y):add_to_scene(ship.scene) end
		end
	}
end

function c_bullet(x, y)
	return merge(c_gameobject(), {
		x = x,
		y = y,
		speed = 4,
		layer = 'bullet',

		bounding_box = function(self)
			return c_rect(self.x - 4, self.y + 1, 8, 3)
		end,

		collide = function(self, collider)
			collider:inflict_damage(1)
			self:remove_from_scene()
		end,

		update = function(self)
			self.y -= self.speed
			if self.y <= - 8 then self:remove_from_scene() end
		end,

		draw = function(self)
			spr(3, self.x-4, self.y)
		end
	})
end

-->8
-- enemies
function c_enemyspawner(args)
	return merge(c_gameobject(), {
		x = args.x or 0,
		y = args.y or 0,
		amount = args.amount or 5,
		delay = args.delay or 1,
		factory = args.factory,

		init = function(self)
			self:wait('spawn', self.delay, partial(self, 'spawn'), self.amount)
		end,

		spawn = function(self)
			self.factory(self.x, self.y):add_to_scene(self.scene)
		end
	})
end

function c_enemy(x, y)
	return merge(c_gameobject(), {
		x = x,
		y = y,
		hp = 2,
		layer = 'enemy',
		blinking = false,

		collide = function(self, collider)
			if collider.layer == 'player' then
				collider:inflict_damage(true)
				self:explode()
			end
		end,

		inflict_damage = function(self, amount)
			if self.damage_feedback then self:damage_feedback() end
				self.hp -= amount
			if self.hp <= 0 then
				self:explode()
			else
				self:wait('dmg_blink', 0.05, partial(self, 'toggle_blinking'), 3)
			end
		end,

		toggle_blinking = function(self)
			self.blinking = not self.blinking
		end,

		explode = function(self)
			c_explosion(self.scene, { x=self.x, y=self.y })
			self:remove_from_scene()
			nc:notify('enemy_removed')
		end
	})
end

function c_zminion(x, y)
	return merge(c_enemy(x, y), {
		movement = 'down',

		init = function(self)
			self:move_horizontally()
			self:move_vertically()
		end,

		shoot = function(self)
			self:wait('shooting', 0.1 + rnd(4), function()
				c_enemybullet(self.x, self.y):add_to_scene(self.scene)
			end)
		end,

		bounding_box = function(self)
			return c_rect(self.x - 4, self.y - 4, 8, 8)
		end,

		move_south = function(self)
			self.movement = 'down'
			self:wait('wait_hmov', 1, partial(self, 'move_horizontally', next_dest))
		end,

		move_horizontally = function(self)
			self:shoot()
			local destination = self.x < 64 and 120 or 8
			self.movement=(destination > self.x) and 'right' or 'left'
			self:ease_animate('hmov', {
				attr='x',
				fv=destination,
				duration=4,
				ease=in_out_cubic_ease,
				callback=partial(self, 'move_south', self.movement == 'right' and min(self.ox, self.fx) or max(self.ox, self.fx))
			})
		end,

		move_vertically = function(self)
			self:ease_animate('vmov', {
				attr='y',
				fv=136,
				duration=20,
				ease=linear_ease,
				callback=partial(self, 'remove_from_scene')
			})
		end,

		draw = function(self)
			if self.blinking then
				pal(2, 14)
				pal(12, 13)
				pal(9, 6)
				pal(8, 15)
			end

			if self.movement == 'down' then
				spr(4, self.x-4, self.y-4, 1, 1, false, true)
			else
				spr(5, self.x-4, self.y-4, 1, 1, self.movement ~= 'left', true)
			end

			pal()
		end
	})
end

function c_uminion(x, y)
	return merge(c_enemy(x, y), {
		movement = 'down',

		init = function(self)
			local destination = self.x < 64 and 136 or -8
			self.movement = destination > 64 and "right" or "left"
			self:ease_animate('hmov', {
				fv=destination,
				attr='x',
				duration=6,
				ease=in_out_cubic_ease,
				callback=partial(self, 'remove_from_scene')
			})

			self:ease_animate('vmov', {
				fv=70,
				attr='y',
				duration=3,
				loops=1,
				bounce_loop=true,
				ease=out_cubic_ease
			})

			self:wait('shoot', rnd(2), partial(self, 'shoot'))
		end,

		shoot = function(self)
			c_enemybullet(self.x, self.y):add_to_scene(self.scene)
			self:wait('shoot', rnd(2), partial(self, 'shoot'))
		end,

		bounding_box = function(self)
			return c_rect(self.x - 4, self.y - 4, 8, 8)
		end,

		draw = function(self)
			if self.blinking then
				pal(14, 2)
				pal(12, 13)
				pal(4, 6)
				pal(11, 15)
			end

			spr(6, self.x-4, self.y-4, 1, 1, self.movement ~= 'left', true)

			pal()
		end
	})
end

function c_enemybullet(x, y, radius)
	return merge(c_gameobject(), {
		x = x,
		y = y,
		speed_x = 0,
		speed_y = 1,
		radius = radius or 2,
		layer = 'enemy_bullet',
		blinking = false,

		init = function(self)
			self:wait('blinking', 0.2, partial(self, 'toggle_blinking'), -1)
		end,

		toggle_blinking = function(self)
			self.blinking = not self.blinking
		end,

		collide = function(self, collider)
			collider:inflict_damage(false)
			self:remove_from_scene()
		end,

		bounding_box = function(self)
			return c_rect(self.x - self.radius, self.y - self.radius, self.radius * 2, self.radius * 2)
		end,

		update = function(self)
			self.animator:update()
			self.x += self.speed_x
			self.y += self.speed_y

			if self.y >= 132 then self:remove_from_scene() end
		end,

		draw = function(self)
			circfill(self.x, self.y, self.radius, self.blinking and 10 or 9)
			circfill(self.x, self.y, self.radius-1, self.blinking and 9 or 8)
		end
	})
end

__gfx__
000000000000000900090000000000000002200000020000000e0000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000900090000000000000002200000020000000e0000000000000000000000000000000000000000000000000000000000000000000000000000
007007000000009c009900000c0000c0002222000022000000ee0000000000000000000000000000000000000000000000000000000000000000000000000000
000770000000009c00c98000c7c00c7c002cc20000c2000000ce0000000000000000000000000000000000000000000000000000000000000000000000000000
000770000000869c00c96000c7c00c7c002cc20000c2000000ce0000000000000000000000000000000000000000000000000000000000000000000000000000
007007000000679c09c976000c0000c0002cc20002c200000ece0000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000867799899977800000000009822890022290000eee4000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000677779699777600000000098888889922889004eebb400000000000000000000000000000000000000000000000000000000000000000000000000
00000055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000005a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000055a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000005aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000055aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005aa5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00055aa5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0005aaa5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0055aaa5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
005aaaa5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
055aaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05aaaaa5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55aaaaa5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5aaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5aaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
