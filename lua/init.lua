---@module "mez_types"

local json = require("json")

---@class Conductor
---@field config ConductorConfig 
---@field state ConductorState
local M = {}

local utils = {}

---Find view ID within all tags
---@param view_id integer
---@return "floating" | "stacking" | nil view_type
---@return number | nil tag_index
---@return string | nil view_index
utils.find_view = function(view_id)
	if view_id == 0 then view_id = mez.view.get_focused_id(0) end
	if not view_id then return end

	for i, t in ipairs(M.state.tags) do
		for j, v in ipairs(t.stack) do
			if tostring(view_id) == v then
				return "stacking", i, j
			end
		end

		for j, v in ipairs(t.floating) do
			if tostring(view_id) == v then
				return "floating", i, j
			end
		end
	end

	print("couldnt find " .. view_id)
	return nil, nil, nil
end

---Merge two tables
---@param t1 table
---@param t2 table
---@return table
utils.table_merge = function(t1, t2)
	for k, v in pairs(t2) do
		if type(v) == "table" then
			if type(t1[k]) == "table" then
				t1[k] = utils.table_merge(t1[k], v)
			else
				t1[k] = utils.table_merge({}, v)
			end
		else
			if t1[k] == nil then
				t1[k] = v
			end
		end
	end
	return t1
end

---@param t1 any[]
---@param t2 any[]
---@return any[]
utils.list_concat = function (t1, t2)
	local t = {}
	for i, v in ipairs(t1) do
		t[i] = v
	end
	for j, v in ipairs(t2) do
		t[#t1+j] = v
	end
    return t
end

---@class ConductorTag
---@field stack integer[]
---@field floating integer[]
---@field last_focused number | nil

---@class ConductorState
---@field tag_id number
---@field tags ConductorTag[]
---@field previous { params: number[], snippet: string }?

---Add the id of a new view
---@param view_id integer
M.add_view = function(view_id)
	local tag = M.state.tags[M.state.tag_id]

	tag.stack[#tag.stack + 1] = view_id

	if M.config.focus_on_spawn then
		mez.view.set_focused(0, view_id)
	end

	M.tile_tag(M.state.tag_id)
end

---Tile all of the master and stack windows for a tag
---@param tag_id number
M.tile_tag = function(tag_id)
	local tag = M.state.tags[tag_id]

	if #tag.stack == 0 then return end

	if not M.state.previous then return end

	M.do_layout(M.state.previous.snippet, tag.stack, M.state.previous.params)
end

---@param snippet string
---@param views integer[]
---@param params number[]
M.do_layout = function (snippet, views, params)
	if not M.config then error("Run 'require(\"conductor\").setup() before do_layout") end

	M.set_layout_snippet(snippet, params)

	for i, v in ipairs(views) do
		views[i] = tostring(v)
	end

	local state = {
		window_ids = views,
		screen_size = mez.output.get_available_area(0) or {x = 0, y = 0, width = 1920, height = 1080},
		snippet = snippet,
		params = params,

		starting_variable = M.config.starting_variable,
		max_depth = M.config.max_depth
	}

	local raw_json = json.encode(state)
	print("JSON Message:")
	print(raw_json)

	local layout_cmd, errmsg = io.popen(string.format("echo '%s' | %s", raw_json, M.config.binary_path), "r")
	if not layout_cmd then error(errmsg) end

	raw_json = layout_cmd:read("*a")
	print("JSON Return:")
	print(raw_json)

	---@type { ignored: integer[], placements: { id: string, transform: { x: integer, y: integer, width: integer, height: integer } }[] }
	local succ, window_layouts = pcall(json.decode, raw_json)
	if not succ then error(raw_json) end

	for _, placement in ipairs(window_layouts.placements) do
		mez.view.set_geometry(tonumber(placement.id), placement.transform)
	end
end

---@param file_path string
---@param views integer[]
---@param params number[]
M.do_layout_file = function (file_path, views, params)
	local file, errmsg = io.open(file_path, "r")
	if not file then error(errmsg) end
	local snippet = string.gsub(file:read("*a"), "\n", "\\n")

	if not params then params = {} end

	M.do_layout(snippet, views, params)

	file:close()
end


---@param snippet string
---@param params number[]
M.set_layout_snippet = function (snippet, params)
	if not params then params = {} end

	M.state.previous = {
		snippet = snippet,
		params = params
	}
end

---@param file_path string
---@param params number[]
M.set_layout_file = function (file_path, params)
	local file, errmsg = io.open(file_path, "r")
	if not file then error(errmsg) end
	local snippet = string.gsub(file:read("*a"), "\n", "\\n")

	M.set_layout_snippet(snippet, params)

	file:close()
end

---Move the focus in a tag to the next view
M.focus_next = function()
	local view_id = mez.view.get_focused_id(0)
	if not view_id then return end

	local type, tag_idx, view_idx = utils.find_view(view_id)
	local tag = M.state.tags[tag_idx]

	local list = utils.list_concat(tag.stack, tag.floating)
	if type == "floating" then view_idx = view_idx + #tag.stack end

	mez.view.set_focused(0, list[view_idx % #list + 1])
end

---Move the focus in a tag to the previous view
M.focus_prev = function()
	local view_id = mez.view.get_focused_id(0)
	if not view_id then return end

	local type, tag_idx, view_idx = utils.find_view(view_id)
	local tag = M.state.tags[tag_idx]

	local list = utils.list_concat(tag.stack, tag.floating)
	if type == "floating" then view_idx = view_idx + #tag.stack end

	view_idx = view_idx - 1
	if view_idx == 0 then view_idx = #list end

	mez.view.set_focused(0, list[view_idx])
end

---Remove a view_id from the layout
---@param view_id integer
M.remove_view = function(view_id)
	if view_id == 0 then view_id = mez.view.get_focused_id(0) end
	if not view_id then return end
	local type, tag_idx, view_idx = utils.find_view(view_id)

	local tag = M.state.tags[tag_idx]

	print(tag_idx)

	if M.config.refocus_on_kill then
		M.focus_prev()
	end

	--- Now remove the view and re-tile if needed
	if type == "floating" then
		table.remove(tag.floating, view_idx)
	elseif type == "stacking" then
		table.remove(tag.stack, view_idx)
	end

	M.tile_tag(tag_idx)
end

---Switch to a tag by enabling all views for 1 tag,
---and disabling all the views for the old tag
---@param tag_idx number
M.tag_enable = function (tag_idx)
	---@param t number
	---@param enabled boolean
	local set_tag_enable = function (t, enabled)
		local tag = M.state.tags[t]

		if enabled then
			if tag.last_focused ~= nil then

				if utils.find_view(tag.last_focused) == nil then
					if tag.master then
						mez.view.set_focused(0, tag.master)
					elseif #tag.floating ~= 0 then
						mez.view.set_focused(0, tag.floating[1])
					end
				else
					mez.view.set_focused(0, tag.last_focused)
				end
			else
				if tag.master then
					mez.view.set_focused(0, tag.master)
				elseif #tag.floating ~= 0 then
					mez.view.set_focused(0, tag.floating[1])
				end
			end
		else
			tag.last_focused = mez.view.get_focused_id(0)
		end

		for _, v in ipairs(tag.floating) do
			mez.view.set_enabled(v, enabled)
		end

		if tag.master ~= nil then
			mez.view.set_enabled(tag.master, enabled)

			for _, v in ipairs(tag.stack) do
				mez.view.set_enabled(v, enabled)
			end
		end
	end

	set_tag_enable(M.state.tag_id, false)
	set_tag_enable(tag_idx, true)

	M.state.tag_id = tag_idx
end

---Move a stack window to the master, and vice versa
---@param view_id integer
M.zoom = function (view_id)
	if view_id == 0 then view_id = mez.view.get_focused_id(0) end
	if not view_id then return end
	local type, tag_idx, view_idx = utils.find_view(view_id)

	if type ~= "stacking" or M.state.tag_id ~= tag_idx then return end

	local tag = M.state.tags[M.state.tag_id]

	table.insert(tag.stack, 1, table.remove(tag.stack, view_idx))

	M.tile_tag(tag_idx)
end

---Move a view from tiling to floating
---@param view_id integer
M.make_float = function (view_id)
	if view_id == 0 then view_id = mez.view.get_focused_id(0) end
	if not view_id then return end
	local type, tag_idx, view_idx = utils.find_view(view_id)

	local tag = M.state.tags[tag_idx]
	local list = type == "floating" and tag.floating or tag.stack

	table.insert(
		tag.floating,
		#tag.floating + 1,
		table.remove(list, view_idx)
	)

	mez.view.raise_to_top(tag.floating[#tag.floating])
	mez.view.set_focused(0, tag.floating[#tag.floating])
	M.tile_tag(tag_idx)
end

---Move a view from floating to tiling
---@param view_id integer
M.make_tile = function (view_id)
	if view_id == 0 then view_id = mez.view.get_focused_id(0) end
	if not view_id then return end
	local _, tag_idx, view_idx = utils.find_view(view_id)

	local tag = M.state.tags[tag_idx]

	if type ~= "floating" then return end
	table.insert(tag.stack, #tag.stack + 1, table.remove(tag.floating, view_idx))

	M.tile_tag(tag_idx)
end

M.set_fullscreen = function (view_id)
	if view_id == 0 then view_id = mez.view.get_focused_id(0) end
	if not view_id then return end
	local _, tag_idx, _= utils.find_view(view_id)
	mez.view.toggle_fullscreen(view_id)

	if not mez.view.get_fullscreen(view_id) then
		local prev_geometry = mez.view.get_previous_geometry(view_id)
		if not prev_geometry then return end
		mez.view.set_geometry(view_id, prev_geometry)
		M.tile_tag(tag_idx)
	end
end

---@param view_id integer
---@param tag_id number
M.send_view = function (view_id, tag_id)
	if view_id == 0 then view_id = mez.view.get_focused_id(0) end
	if not view_id then return end
	if tag_id == M.state.tag_id then return end

	local type, _, _ = utils.find_view(view_id)

	local tag = M.state.tags[tag_id]

	M.remove_view(view_id)

	if type == "floating" then
		table.insert(tag.floating, #tag.floating, view_id)
	else
		tag.stack[#tag.stack + 1] = view_id
	end

	mez.view.set_enabled(view_id, false)
	M.tile_tag(M.state.tag_id)
	M.tile_tag(tag_id)
end

---@class ConductorConfig
---@field binary_path string
---@field max_depth integer
---@field start_variable string
---@field mod_key string
---@field tag_count integer
---@field focus_on_spawn boolean
---@field refocus_on_kill boolean
local default_config = {
	binary_path = "conductor",
	max_depth = 25,
	starting_variable = "start",
	mod_key = "alt",
	tag_count = 5,
	focus_on_spawn = true,
	refocus_on_kill = true,
}

---@param config ConductorConfig
M.setup = function (config)
	M.config = utils.table_merge(config or {}, default_config)

	M.state = {
		tag_id = 1,
		tags = {},
	}

	-- Create all tags for the state
	for i = 1, M.config.tag_count do
		M.state.tags[i] = {
			floating = {},
			stack = {},
			last_focused = nil
		}
	end

	mez.hook.add("ViewMapPost", {
		callback = function(view_id)
			M.add_view(view_id)
		end
	})
	mez.hook.add("ViewUnmapPre", {
		callback = function(view_id)
			M.remove_view(view_id)
		end
	})

	mez.input.add_keymap(M.config.mod_key, "j", { press = function () M.focus_next() end })
	mez.input.add_keymap(M.config.mod_key, "k", { press = function () M.focus_prev() end })
	mez.input.add_keymap(M.config.mod_key, "Return", { press = function () M.zoom(0) end })

	mez.input.add_keymap(M.config.mod_key.."|shift", "F", { press = function () M.set_fullscreen(0) end })

	for i = 1, M.config.tag_count do
		mez.input.add_keymap(M.config.mod_key, tostring(i), {
			press = function ()
				M.tag_enable(i)
			end
		})

		mez.input.add_keymap(M.config.mod_key.."|shift", tostring(i), {
			press = function ()
				M.send_view(0, i)
			end
		})
	end

	mez.input.add_mousemap(M.config.mod_key, "BTN_LEFT", {
		press = function(view_id) M.make_float(view_id) end,
		drag = function(view_id, pos, _, offset)
			if view_id ~= nil then
				mez.view.set_geometry(view_id, {
					x = pos.x - offset.x,
					y = pos.y - offset.y
				})
			end
		end
	})

	mez.input.add_mousemap(M.config.mod_key, "BTN_MIDDLE", {
		press = function(view_id)
			M.make_tile(view_id)
		end
	})

	mez.input.add_mousemap(M.config.mod_key, "BTN_RIGHT", {
		press = function(view_id) M.make_float(view_id) end,
		drag = function(view_id, pos, drag_start, offset)
			if view_id ~= nil then
				local width = (pos.x - drag_start.x) + offset.x
				local height = (pos.y - drag_start.y) + offset.y

				if width <= 10 then width = 10 end
				if height <= 10 then height = 10 end
				mez.view.set_geometry(view_id, {
					width = width,
					height = height
				})
			end
		end
	})

	mez.hook.add("OutputStateChange", { callback = function ()
		for i = 1, M.config.tag_count do
			M.tile_tag(i)
		end
	end})

	mez.hook.add("ViewRequestFullscreen", {
		callback = function (view_id)
			M.set_fullscreen(view_id)
		end
	})
end

return M
