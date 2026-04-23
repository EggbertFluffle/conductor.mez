---@module "mez_types"

local json = require("json")

---@class Conductor
local M = {}

---@param snippet string
---@param params number[]
M.doLayout = function (snippet, params)
	if not M.config then error("Run 'require(\"conductor\").setup() before doLayout") end

	if not params then params = {} end

	M.previous = {
		snippet = snippet,
		params = params
	}

	local state = {
		window_ids = mez.output.get_views(0),
		screen_size = mez.output.get_available_area(0),
		snippet = snippet,
		params = params,

		starting_variable = M.config.starting_variable,
		max_depth = M.config.max_depth
	}

	local raw_json = json.encode(state)
	print(raw_json)

	local layout_cmd = io.popen(string.format("echo '%s' | %s", raw_json, M.config.binary_path), "r")
	if not layout_cmd then
		error("Not able to execute layout")
	end

	raw_json = layout_cmd:read("*a")
	print(raw_json)

	---@type { ignored: integer[], placements: { id: integer, transform: { x: integer, y: integer, width: integer, height: integer } }[] }
	local window_layouts = json.decode(raw_json)
	for _, placement in ipairs(window_layouts.placements) do
		mez.view.set_geometry(placement.id, placement.transform)
	end
end

---@param file_path string
---@param params number[]
M.doFile = function (file_path, params)
	local file, errmsg = io.open(file_path, "r")
	if not file then error(errmsg) end
	local snippet = string.gsub(file:read("*a"), "\n", "\\n")

	if not params then params = {} end

	M.doLayout(snippet, params)

	file:close()
end

---@class ConductorConfig
---@field binary_path string
---@field max_depth integer
---@field start_variable string
local default_config = {
	binary_path = "conductor",
	max_depth = 25,
	starting_variable = "start",
	mod_key = "alt"
}

---@type { snippet: string, params: number[] }?
M.previous = nil

---@param config ConductorConfig
M.setup = function (config)
	M.config = config or default_config

	-- mez.input.add_keymap(M.config.mod_key, "j", { press = function () M.change_focus(1) end })
	-- mez.input.add_keymap(M.config.mod_key, "k", { press = function () M.change_focus(-1) end })

	local retry = function ()
		if not M.previous then return end
		M.doLayout(M.previous.snippet, M.previous.params)
	end

	mez.hook.add("ViewMapPre", { callback = function (id)
		retry()
		mez.view.set_focused(0, id)
	end })

	mez.hook.add("ViewUnmapPost", { callback = function (id)
		retry()
	end})

	mez.hook.add("OutputStateChange", { callback = retry })
end

return M
