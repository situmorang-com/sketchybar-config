-- items/workspaces.lua
local colors = require("colors")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

-- Custom events fired by aerospace's exec-on-workspace-change /
-- on-focus-changed callbacks (see ~/.config/aerospace/aerospace.toml).
-- Registered here rather than in a standalone shell script so the whole
-- wiring lives with the item that consumes it.
sbar.add("event", "aerospace_workspace_change")
sbar.add("event", "aerospace_focus_change")

local query_workspaces =
	"aerospace list-workspaces --all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"

-- Each pill is a bracket around the workspace number plus one item per
-- window, so every app glyph is its own click target (a single label string
-- can't tell which glyph was clicked). Slots are created up front and shown
-- as needed; windows beyond the last slot fold their glyphs into it.
local MAX_SLOTS = 6
local APP_FONT = "sketchybar-app-font:Regular:16.0"
local DIM = colors.with_alpha(colors.white, 0.3)

-- Add padding to the left
local root = sbar.add("item", {
	icon = { drawing = false },
	label = { drawing = false },
	background = { drawing = false },
	padding_left = 6,
	padding_right = 0,
	-- Drives the "routine" reconcile below.
	updates = true,
	update_freq = 30,
})

-- workspace name -> { item, slots = {...}, bracket, windows = { [slot] = window-id } }
local workspaces = {}

local function trim(s)
	return (s or ""):match("^%s*(.-)%s*$")
end

local function withWindows(f)
	local open_windows = {}
	local get_windows =
		"aerospace list-windows --monitor all --format '%{workspace}%{app-name}%{window-id}' --json"
	local query_visible_workspaces =
		"aerospace list-workspaces --visible --monitor all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"
	local get_focus_workspaces = "aerospace list-workspaces --focused"
	sbar.exec(get_windows, function(workspace_and_windows)
		for _, entry in ipairs(workspace_and_windows) do
			local workspace_index = entry.workspace
			if open_windows[workspace_index] == nil then
				open_windows[workspace_index] = {}
			end
			table.insert(open_windows[workspace_index], { app = entry["app-name"], id = entry["window-id"] })
		end
		-- aerospace lists windows most-recently-focused first, so every click
		-- would reshuffle the glyphs under the pointer. Window ids only grow,
		-- which gives a stable opening order.
		for _, windows in pairs(open_windows) do
			table.sort(windows, function(a, b)
				return a.id < b.id
			end)
		end
		sbar.exec(get_focus_workspaces, function(focused_workspaces)
			sbar.exec(query_visible_workspaces, function(visible_workspaces)
				local args = {
					open_windows = open_windows,
					focused_workspace = trim(focused_workspaces),
					visible_workspaces = visible_workspaces,
				}
				f(args)
			end)
		end)
	end)
end

-- Point the number, every slot and the bracket at one display. Right after
-- wake AppKit can report a bogus screen id, and a negative/zero display value
-- corrupts the message batch, so callers only pass validated ids.
local function setDisplay(ws, monitor_id)
	ws.item:set({ display = monitor_id })
	for _, slot in ipairs(ws.slots) do
		slot:set({ display = monitor_id })
	end
	ws.bracket:set({ display = monitor_id })
end

local function hideWorkspace(ws)
	ws.item:set({ drawing = false })
	for i, slot in ipairs(ws.slots) do
		slot:set({ drawing = false })
		ws.windows[i] = nil
	end
	ws.bracket:set({ background = { drawing = false } })
end

local function updateWindow(workspace_index, args)
	local ws = workspaces[workspace_index]
	local open_windows = args.open_windows[workspace_index] or {}
	local is_focused = workspace_index == args.focused_workspace

	local visible_monitor
	for _, visible_workspace in ipairs(args.visible_workspaces) do
		if visible_workspace["workspace"] == workspace_index then
			local raw_id = visible_workspace["monitor-appkit-nsscreen-screens-id"]
			visible_monitor = (raw_id and math.floor(raw_id)) or 0
		end
	end

	if #open_windows == 0 and not is_focused and visible_monitor == nil then
		sbar.animate("tanh", 10, function()
			hideWorkspace(ws)
		end)
		return
	end

	-- One glyph per slot; overflow windows pile into the last slot.
	local glyphs, ids = {}, {}
	for i, window in ipairs(open_windows) do
		local glyph = app_icons[window.app] or app_icons["Default"]
		local slot = math.min(i, MAX_SLOTS)
		glyphs[slot] = (glyphs[slot] and (glyphs[slot] .. " ") or "") .. glyph
		ids[slot] = ids[slot] or window.id
	end
	if #open_windows == 0 then
		glyphs[1] = "—"
	end

	sbar.animate("tanh", 10, function()
		ws.item:set({ drawing = true })
		local last = #glyphs
		for i, slot in ipairs(ws.slots) do
			ws.windows[i] = ids[i]
			if glyphs[i] then
				slot:set({
					drawing = true,
					label = {
						string = glyphs[i],
						highlight = is_focused,
						padding_right = (i == last) and 10 or 3,
					},
				})
			else
				slot:set({ drawing = false })
			end
		end
		ws.bracket:set({
			background = { drawing = true, border_width = is_focused and 2 or 1 },
		})
		if visible_monitor and visible_monitor > 0 then
			setDisplay(ws, visible_monitor)
		end
	end)
end

local function updateWindows()
	withWindows(function(args)
		for workspace_index, _ in pairs(workspaces) do
			updateWindow(workspace_index, args)
		end
	end)
end

local function updateWorkspaceMonitor(retries_left)
	retries_left = retries_left or 5
	local workspace_monitor = {}
	local saw_invalid_id = false
	sbar.exec(query_workspaces, function(workspaces_and_monitors)
		for _, entry in ipairs(workspaces_and_monitors) do
			local space_index = entry.workspace
			local raw_id = entry["monitor-appkit-nsscreen-screens-id"]
			local monitor_id = raw_id and math.floor(raw_id)
			-- Right after login/wake, AppKit can briefly report a bogus
			-- screen id before displays finish enumerating; skip those
			-- rather than handing sketchybar a display domain that doesn't exist.
			if monitor_id and monitor_id > 0 then
				workspace_monitor[space_index] = monitor_id
			else
				saw_invalid_id = true
			end
		end
		for workspace_index, ws in pairs(workspaces) do
			if workspace_monitor[workspace_index] then
				setDisplay(ws, workspace_monitor[workspace_index])
			end
		end
		if saw_invalid_id and retries_left > 0 then
			sbar.delay(1, function()
				updateWorkspaceMonitor(retries_left - 1)
			end)
		end
	end)
end

local function setFocused(ws, is_focused)
	ws.item:set({ icon = { highlight = is_focused } })
	for _, slot in ipairs(ws.slots) do
		slot:set({ label = { highlight = is_focused } })
	end
	ws.bracket:set({ background = { border_width = is_focused and 2 or 1 } })
end

sbar.exec(query_workspaces, function(workspaces_and_monitors)
	for _, entry in ipairs(workspaces_and_monitors) do
		local workspace_index = entry.workspace

		local item = sbar.add("item", {
			drawing = false,
			icon = {
				color = DIM,
				highlight_color = colors.white,
				font = { family = settings.font.numbers },
				string = workspace_index,
				padding_left = 10,
				padding_right = 2,
			},
			label = { drawing = false },
			padding_left = 3,
			padding_right = 0,
			click_script = "aerospace workspace " .. workspace_index,
		})

		local ws = { item = item, slots = {}, windows = {} }
		local members = { item.name }

		for i = 1, MAX_SLOTS do
			local slot = sbar.add("item", {
				drawing = false,
				icon = { drawing = false },
				label = {
					color = DIM,
					highlight_color = colors.white,
					font = APP_FONT,
					y_offset = -1,
					padding_left = 3,
					padding_right = 3,
				},
				padding_left = 0,
				padding_right = 0,
			})
			-- Focusing the window also switches to its workspace (and monitor).
			slot:subscribe("mouse.clicked", function()
				local id = ws.windows[i]
				if id then
					sbar.exec("aerospace focus --window-id " .. id)
				else
					sbar.exec("aerospace workspace " .. workspace_index)
				end
			end)
			ws.slots[i] = slot
			table.insert(members, slot.name)
		end

		ws.bracket = sbar.add("bracket", members, {
			background = {
				drawing = false,
				color = colors.glass,
				border_width = 1,
				height = 28,
				border_color = colors.glass_border,
				corner_radius = 14,
			},
		})

		workspaces[workspace_index] = ws

		item:subscribe("aerospace_workspace_change", function(env)
			sbar.animate("tanh", 10, function()
				setFocused(ws, env.FOCUSED_WORKSPACE == workspace_index)
			end)
		end)
	end

	-- initial setup
	updateWindows()
	updateWorkspaceMonitor()

	root:subscribe("aerospace_focus_change", function()
		updateWindows()
	end)

	-- aerospace's on-focus-changed does not fire when a window is destroyed
	-- (verified: quitting an app moves focus but emits no callback, and there
	-- is no on-window-destroyed hook), so the pill would keep showing a ghost
	-- icon for the dead app. front_app_switched is a sketchybar built-in and
	-- does fire on quit, since the frontmost app changes.
	--
	-- The delayed second pass is required, not belt-and-braces: when the event
	-- arrives the dying app is still mid-quit and `aerospace list-windows`
	-- still reports its window, so the immediate pass repaints the same stale
	-- icon set. Nothing fires again afterwards, so without this the ghost icon
	-- persists until the next unrelated focus change.
	root:subscribe("front_app_switched", function()
		updateWindows()
		sbar.delay(1, function()
			updateWindows()
		end)
	end)

	-- Safety net for the one transition nothing else covers: an app quitting
	-- in a workspace that is neither focused nor frontmost. aerospace has no
	-- window-destroyed callback, its on-focus-changed does not fire on
	-- destruction, and front_app_switched does not fire because the frontmost
	-- app never changed. Verified: the pill kept a ghost icon (drawing=on with
	-- the dead app's glyph) for over 3 minutes of idle. One pass is ~70ms of
	-- `aerospace` queries, so 30s is a ~0.2% duty cycle.
	root:subscribe("routine", function()
		updateWindows()
	end)

	root:subscribe("display_change", function()
		updateWorkspaceMonitor()
		updateWindows()
	end)

	-- Highlight whichever workspace aerospace reports as focused. On a cold
	-- boot sketchybar can win the race against aerospace, in which case the
	-- query yields an empty string (or a name we have no item for) -- indexing
	-- that blind aborts the callback, so retry instead of erroring out.
	local function highlightFocusedWorkspace(retries_left)
		retries_left = retries_left or 5
		sbar.exec("aerospace list-workspaces --focused", function(focused_workspace)
			local ws = workspaces[trim(focused_workspace)]
			if not ws then
				if retries_left > 0 then
					sbar.delay(1, function()
						highlightFocusedWorkspace(retries_left - 1)
					end)
				end
				return
			end
			setFocused(ws, true)
		end)
	end

	highlightFocusedWorkspace()
end)
