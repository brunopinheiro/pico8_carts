pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- The Amazing Goblin's Workshop
--   by brunopinheiro

-- game loop
function _init()

end

function _update60()

end

function _draw()
	cls()
end

--core
local btn_left, btn_right, btn_up, btn_down, btn_o, btn_x = 0, 1, 2, 3, 4, 5

function merge(t1, t2)
	local merged = {}
	for k, v in pairs(t1) do merged[k] = v end
	if t2 then for k, v in pairs(t2) do merged[k] = v end end
	return merged
end

function c_animator()
	return {
		animations = {},

		animate = function(self, name, target, update, callback)
			self.animations[name]={ name=name, target=target, update=update, callback=callback }
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

function stepped_ease_with(steps, ease)
	ease = ease or linear_ease
	return function(initial, final, time, duration)
		return steps[flr(ease(1, #steps + 1, time, duration))]
	end
end

function c_gameobject()
	return {
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

		animate = function(self, name, args)
			local loops = args.loops or 0
			local ease = args.ease or linear_ease
			local target = args.target or self
			local attr = args.attr or printh('error: attr for animation is required')
			local duration = args.duration or printh('error: duration for animation is required')
			local callback = args.callback
			local it = time()
			local ov = target[args.attr]
			local fv = args.fv or printh('error: fv for animation is required')
			local inverted_loop = args.inverted_loop or false

			self.animator:animate(
				name,
				target,
				function()
					local td = time() - it
					target[attr]=ease(ov, fv, td, duration)
					return td < duration
				end,
				(loops ~= 0) and function()
						if inverted_loop then
							fv = ov
							ov = args.fv
						end

						target[attr] = ov
						self:animate(name, merge(args, { loops=loops - 1, fv=fv }))
					end or callback
				end
			)
		end
	}
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
