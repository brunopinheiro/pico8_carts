pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- the amazing goblin's workshop
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

function copy(t1, t2)
	for k, v in pairs(t1) do t2[k] = v end
	return t2
end

function merge(t1, t2)
	return copy(t2, copy(t1, {}))
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
	}
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
