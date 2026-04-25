# conductor.mez

Conductor.mez is designed as an implementation of the [Conductor](https://github.com/EggbertFluffle/Conductor) DSL, a language designed to unify how we describe dynamic window management.

## Installation

This plugin is for [Mezzaluna](https://github.com/MezzalunaWM/Mezzaluna). After mez is installed, clone this repo into you plugins folder. You will also need the [Conductor](https://github.com/EggbertFluffle/Conductor) binary built for your system. We do not package prebuilt binaries.

```sh
mkdir -p ~/.local/share/mez/plugins
git clone https://github.com/EggbertFluffle/conductor.mez ~/.local/share/mez/plugins/
```

## Getting Started

Once installed, add the following into your mez config.

```lua
local conductor = require("conductor")
conductor.setup({})

conductor.set_layout_snippet("start = full [|] ?stack\nstack = full (-) ?stack", {})
```

This sets up a basic master stack layout.

## Configuration

Below is the default configuration.

```lua
{
	binary_path = "conductor", -- Path to built conductor binary
	max_depth = 25, -- Max amount of windows to manage
	starting_variable = "start", -- Starting variable for parsing
	mod_key = "alt", -- The mod key for basic keybinds
	focus_on_spawn = true, -- Focus any new windows
	refocus_on_kill = true -- Focus existing window after closing one
}
```

Layout can be supplied to conductor.mez via the following. Using `set_layout` does not manage windows as it is called, but stores the layout and parameters until the windows need to be rearranged next.

```lua
conductor.set_layout_snippet("<CONDUCTOR SNIPPET>", {params, list, here})

-- From a file instead
conductor.set_layout_file("<FILE WITH CONDUCTOR>", {params, list, here})
```

Or use `do_layout` in order to layout a specified windows list as a new snippet and parameters list is supplied.

```lua
conductor.do_layout_snippet("<CONDUCTOR SNIPPET>", {view, list, here}, {params, list, here})

-- From a file instead
conductor.do_layout_file("<FILE WITH CONDUCTOR>", {view, list, here}, {params, list, here})
```

We can add a movable `master_ratio` easily like so.

```lua
conductor.set_layout_file(layout_file, {master_ratio})

-- Ok alt+l, increase master_ratio, and retile windows on screen
mez.input.add_keymap(mod, "l", {
	press = function ()
		master_ratio = master_ratio + master_ratio_step
		conductor.do_layout_file(layout_file, mez.output.get_views(0), {master_ratio})
	end
})

-- Ok alt+h, decrease master_ratio, and retile windows on screen
mez.input.add_keymap(mod, "h", {
	press = function ()
		master_ratio = master_ratio - master_ratio_step
		conductor.do_layout_file(layout_file, mez.output.get_views(0), {master_ratio})
	end
})
```
