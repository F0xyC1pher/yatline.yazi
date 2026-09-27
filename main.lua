--- @since 25.12.29
--- @diagnostic disable: undefined-global, undefined-field
--- @alias Mode Mode Comes from Yazi.
--- @alias Rect Rect Comes from Yazi.
--- @alias Paragraph Paragraph Comes from Yazi.
--- @alias Line Line Comes from Yazi.
--- @alias Span Span Comes from Yazi.
--- @alias Color Color Comes from Yazi.

--==================--
-- Localized Globals --
--==================--

local ui_Span = ui.Span
local ui_Line = ui.Line
local ui_Text = ui.Text
local ui_Layout = ui.Layout
local ui_Constraint = ui.Constraint
local ui_Align = ui.Align
local ui_truncate = ui.truncate
local ui_redraw = ui.redraw

local string_format = string.format
local string_sub = string.sub
local string_rep = string.rep
local table_insert = table.insert
local table_concat = table.concat
local table_unpack = table.unpack -- don't do (or unpack)
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local utf8_len = utf8 and utf8.len
local utf8_offset = utf8 and utf8.offset
local os_date = os.date

--==================--
-- Fast Unpack Helper --
--==================--

local function call_getter(getter, self_arg, params)
	if not params or #params == 0 then
		return getter(self_arg)
	elseif #params == 1 then
		return getter(self_arg, params[1])
	elseif #params == 2 then
		return getter(self_arg, params[1], params[2])
	elseif #params == 3 then
		return getter(self_arg, params[1], params[2], params[3])
	end
	return getter(self_arg, table_unpack(params))
end

--==================--
-- Type Declaration --
--==================--

--- @enum Side
local Side = {
	LEFT = 0,
	RIGHT = 1,
}

--- @enum SeparatorType
local SeparatorType = {
	OUTER = 0,
	INNER = 1,
}

--- @enum ComponentType
local ComponentType = {
	A = 0,
	B = 1,
	C = 2,
}

--- @class Yatline
Yatline = {}

Yatline.config = {
	section_separator = { open = "", close = "" },
	part_separator = { open = "", close = "" },
	inverse_separator = { open = "", close = "" },

	padding = { inner = 1, outer = 1 },

	style_a = {
		bg = "white",
		fg = "black",
		bg_mode = {
			normal = "white",
			select = "brightyellow",
			un_set = "brightred",
		},
	},
	style_b = { bg = "brightblack", fg = "brightwhite" },
	style_c = { bg = "black", fg = "brightwhite" },

	permissions_t_fg = "green",
	permissions_r_fg = "yellow",
	permissions_w_fg = "red",
	permissions_x_fg = "cyan",
	permissions_s_fg = "white",

	tab_width = 20,

	selected = { icon = "󰻭", fg = "yellow" },
	copied = { icon = "", fg = "green" },
	cut = { icon = "", fg = "red" },

	files = { icon = "", fg = "blue" },
	filtereds = { icon = "", fg = "magenta" },

	total = { icon = "󰮍", fg = "yellow" },
	success = { icon = "", fg = "green" },
	failed = { icon = "", fg = "red" },

	show_background = true,

	display_header_line = true,
	display_status_line = true,

	component_positions = { "header", "tab", "status" },

	header_line = {
		left = {
			section_a = {
				{ type = "line", name = "tabs" },
			},
			section_b = {},
			section_c = {},
		},
		right = {
			section_a = {
				{ type = "string", name = "date", params = { "%A, %d %B %Y" } },
			},
			section_b = {
				{ type = "string", name = "date", params = { "%X" } },
			},
			section_c = {},
		},
	},

	status_line = {
		left = {
			section_a = {
				{ type = "string", name = "tab_mode" },
			},
			section_b = {
				{ type = "string", name = "hovered_size" },
			},
			section_c = {
				{ type = "string",   name = "hovered_path" },
				{ type = "coloreds", name = "count" },
			},
		},
		right = {
			section_a = {
				{ type = "string", name = "cursor_position" },
			},
			section_b = {
				{ type = "string", name = "cursor_percentage" },
			},
			section_c = {
				{ type = "string",   name = "hovered_file_extension", params = { true } },
				{ type = "coloreds", name = "permissions" },
			},
		},
	},
}

--=================--
-- Cached Padding  --
--=================--

local pad_inner_str = " "
local pad_outer_str = " "

local function update_padding_cache()
	pad_inner_str = string_rep(" ", Yatline.config.padding.inner or 1)
	pad_outer_str = string_rep(" ", Yatline.config.padding.outer or 1)
end

--=================--
-- Component Setup --
--=================--

local function set_mode_style(mode)
	if not mode then return end
	if mode.is_select then
		Yatline.config.style_a.bg = Yatline.config.style_a.bg_mode.select
	elseif mode.is_unset then
		Yatline.config.style_a.bg = Yatline.config.style_a.bg_mode.un_set
	else
		Yatline.config.style_a.bg = Yatline.config.style_a.bg_mode.normal
	end
end

local function apply_style_table(component, style)
	if not style then
		return component
	end
	if style.fg then component:fg(style.fg) end
	if style.bg then component:bg(style.bg) end
	if style.bold then component:bold() end
	if style.dim then component:dim() end
	if style.italic then component:italic() end
	if style.underline then component:underline() end
	if style.blink then component:blink() end
	if style.blink_rapid then component:blink_rapid() end
	if style.reverse then component:reverse() end
	if style.hidden then component:hidden() end
	if style.crossed then component:crossed() end
	return component
end

local function set_component_style(component, component_type)
	if component_type == ComponentType.A then
		apply_style_table(component, Yatline.config.style_a):bold()
	elseif component_type == ComponentType.B then
		apply_style_table(component, Yatline.config.style_b)
	else
		apply_style_table(component, Yatline.config.style_c)
	end
end

local function connect_padding(component, component_type, in_side)
	local inner = ui_Span(pad_inner_str)
	local outer = ui_Span(pad_outer_str)

	set_component_style(inner, component_type)
	set_component_style(outer, component_type)

	if in_side == Side.LEFT then
		return ui_Line({ outer, component, inner })
	else
		return ui_Line({ inner, component, outer })
	end
end

local function connect_separator(component, in_side, separator_type, separator_style)
	local open, close
	if
		separator_type == SeparatorType.OUTER and not (separator_style.bg == "reset" and separator_style.fg == "reset")
	then
		open = ui_Span(Yatline.config.section_separator.open)
		close = ui_Span(Yatline.config.section_separator.close)

		if separator_style.fg == "reset" then
			if separator_style.bg ~= "" then
				open = ui_Span(Yatline.config.inverse_separator.open)
				close = ui_Span(Yatline.config.inverse_separator.close)

				separator_style.fg, separator_style.bg = separator_style.bg, separator_style.fg
			else
				return ui_Line({ component })
			end
		end
	else
		open = ui_Span(Yatline.config.part_separator.open)
		close = ui_Span(Yatline.config.part_separator.close)
	end

	apply_style_table(open, separator_style)
	apply_style_table(close, separator_style)

	if in_side == Side.LEFT then
		return ui_Line({ component, close })
	else
		return ui_Line({ open, component })
	end
end

--==================--
-- Helper Functions --
--==================--

local function get_file_extension(file_name)
	if not file_name then return "---" end
	local extension = file_name:match("^.+%.(.+)$")
	if not extension or extension == "" then
		return "---"
	end
	return extension
end

local function utf8len_fast(s)
	if not s or s == "" then return 0 end
	return utf8_len and utf8_len(s) or #s
end

local function utf8sub_fast(s, i, j)
	if not s or s == "" then return "" end
	local len = utf8len_fast(s)

	if i < 0 then i = len + i + 1 end
	if j and j < 0 then j = len + j + 1 end
	i = math_max(1, i)
	j = math_min(len, j or len)

	if i > j then return "" end

	if utf8_offset then
		local start_byte = utf8_offset(s, i)
		if not start_byte then return "" end
		local end_byte = (j < len and utf8_offset(s, j + 1)) and (utf8_offset(s, j + 1) - 1) or #s
		return string_sub(s, start_byte, end_byte)
	end

	return string_sub(s, i, j)
end

local function trim_filename(filename, max_length, trim_length)
	if not max_length or not trim_length then
		return filename
	end

	local len = utf8len_fast(filename)
	if len <= max_length or len <= trim_length * 2 then
		return filename
	end

	local head = utf8sub_fast(filename, 1, trim_length)
	local tail = utf8sub_fast(filename, -trim_length, -1)

	return head .. "..." .. tail
end

--========================--
-- Component String Group --
--========================--

Yatline.string = {}
Yatline.string.get = {}
Yatline.string.has_separator = true

function Yatline.string.create(str, component_type)
	local span = ui_Span(str)
	set_component_style(span, component_type)
	return ui_Line({ span })
end

function Yatline.string.get:hovered_name(trimmed, max_length, trim_length, show_symlink)
	trimmed = trimmed or false
	max_length = max_length or 24
	trim_length = trim_length or 10
	show_symlink = show_symlink or false

	local hovered = cx.active.current.hovered
	if not hovered then
		return ""
	end

	local link_delimiter = " -> "
	local linked = (show_symlink and hovered.link_to ~= nil) and (link_delimiter .. tostring(hovered.link_to)) or ""

	if trimmed then
		local trimmed_name = trim_filename(hovered.name, max_length, trim_length)
		local trimmed_linked = #linked ~= 0
			and link_delimiter .. trim_filename(
				string_sub(linked, #link_delimiter + 1),
				max_length,
				trim_length
			)
			or ""
		return trimmed_name .. trimmed_linked
	else
		return hovered.name .. linked
	end
end

function Yatline.string.get:hovered_path(trimmed, max_length, trim_length)
	trimmed = trimmed or false
	max_length = max_length or 24
	trim_length = trim_length or 10

	local hovered = cx.active.current.hovered
	if not hovered then
		return ""
	end

	local path = ya.readable_path(tostring(hovered.url))
	if trimmed then
		return trim_filename(path, max_length, trim_length)
	else
		return path
	end
end

function Yatline.string.get:hovered_size()
	local hovered = cx.active.current.hovered
	if hovered then
		return ya.readable_size(hovered:size() or hovered.cha.len)
	else
		return ""
	end
end

function Yatline.string.get:hovered_mime()
	local hovered = cx.active.current.hovered
	if hovered then
		return hovered:mime()
	else
		return ""
	end
end

function Yatline.string.get:hovered_ownership()
	local hovered = cx.active.current.hovered
	if not hovered or not hovered.cha.uid or not hovered.cha.gid then
		return ""
	end

	local username = ya.user_name(hovered.cha.uid) or tostring(hovered.cha.uid)
	local groupname = ya.group_name(hovered.cha.gid) or tostring(hovered.cha.gid)

	return username .. ":" .. groupname
end

function Yatline.string.get:hovered_file_extension(show_icon)
	local hovered = cx.active.current.hovered
	if not hovered then
		return ""
	end

	local name = hovered.cha.is_dir and "dir" or get_file_extension(hovered.name)

	if show_icon then
		local icon = th and th.icon and th.icon:match(hovered)
		local icon_text = (icon and icon.text) or ""
		return (icon_text ~= "" and (icon_text .. " " .. name)) or name
	end

	return name
end

function Yatline.string.get:tab_path(trimmed, max_length, trim_length)
	trimmed = trimmed or false
	max_length = max_length or 24
	trim_length = trim_length or 10

	local cwd = cx.active.current.cwd
	local filter = cx.active.current.files.filter
	local finder = cx.active.finder

	local suffix = ""
	if cwd.spec.is_search or filter or finder then
		local t = {}
		if cwd.spec.is_search then
			t[#t + 1] = string_format("search: %s", cwd.domain)
		end
		if filter then
			t[#t + 1] = string_format("filter: %s", filter)
		end
		if finder then
			t[#t + 1] = string_format("find: %s", finder)
		end
		suffix = " (" .. table_concat(t, ", ") .. ")"
	end

	local path = ya.readable_path(tostring(cwd))
	if trimmed then
		return trim_filename(path, max_length, trim_length) .. suffix
	else
		return path .. suffix
	end
end

function Yatline.string.get:filter_query(key)
	key = key or "filter:"
	local filter = cx.active.current.files.filter

	if filter then
		return string_format("%s %s", key, tostring(filter))
	else
		return ""
	end
end

function Yatline.string.get:search_query(key)
	key = key or "search:"
	local cwd = cx.active.current.cwd

	if cwd.spec.is_search then
		return string_format("%s %s", key, cwd.domain)
	else
		return ""
	end
end

function Yatline.string.get:finder_query(key)
	key = key or "find:"
	local finder = cx.active.finder

	if finder then
		return string_format("%s %s", key, tostring(finder))
	else
		return ""
	end
end

function Yatline.string.get:tab_mode()
	local mode = tostring(cx.active.mode):upper()
	if mode == "UNSET" then
		mode = "UN-SET"
	end
	return mode
end

function Yatline.string.get:tab_num_files()
	return tostring(#cx.active.current.files)
end

function Yatline.string.get:cursor_position()
	local cursor = cx.active.current.cursor
	local length = #cx.active.current.files

	if length ~= 0 then
		return string_format("%d/%d", cursor + 1, length)
	else
		return "0"
	end
end

function Yatline.string.get:cursor_percentage()
	local percentage = 0
	local cursor = cx.active.current.cursor
	local length = #cx.active.current.files
	if cursor ~= 0 and length ~= 0 then
		percentage = math_floor((cursor + 1) * 100 / length)
	end

	if percentage == 0 then
		return "Top"
	elseif percentage == 100 then
		return "Bot"
	else
		return string_format("%d%%", percentage)
	end
end

function Yatline.string.get:date(format)
	return tostring(os_date(format))
end

--======================--
-- Component Line Group --
--======================--

Yatline.line = {}
Yatline.line.get = {}
Yatline.line.has_separator = false

function Yatline.line.create(line, component_type)
	return line
end

function Yatline.line.get:tabs(side)
	side = side or "left"

	local tabs = #cx.tabs
	local lines = {}

	local in_side = (side == "left") and Side.LEFT or Side.RIGHT
	local sep_style = { bg = nil, fg = nil }

	for i = 1, tabs do
		local text = tostring(i)
		if Yatline.config.tab_width > 2 then
			text = ui_truncate(text .. " " .. cx.tabs[i].name, { max = Yatline.config.tab_width })
		end

		sep_style.bg = nil
		sep_style.fg = nil

		if i == cx.tabs.idx then
			local tab = connect_padding(ui_Span(text), ComponentType.A, in_side)
			set_mode_style(cx.tabs[i].mode)
			set_component_style(tab, ComponentType.A)

			if Yatline.config.style_a.bg ~= "reset" or Yatline.config.show_background then
				sep_style.fg = Yatline.config.style_a.bg
				if Yatline.config.show_background then
					sep_style.bg = Yatline.config.style_c.bg
				end

				lines[#lines + 1] = connect_separator(tab, in_side, SeparatorType.OUTER, sep_style)
			else
				sep_style.fg = Yatline.config.style_a.fg

				lines[#lines + 1] = connect_separator(tab, in_side, SeparatorType.INNER, sep_style)
			end
		else
			local tab = ui_Span(text)
			local inner = ui_Span(pad_inner_str)
			local outer = ui_Span(pad_outer_str)

			if Yatline.config.show_background then
				set_component_style(inner, ComponentType.C)
				set_component_style(outer, ComponentType.C)
				set_component_style(tab, ComponentType.C)
			else
				if Yatline.config.style_c.fg then
					tab:fg(Yatline.config.style_c.fg)
				end
			end

			if in_side == Side.LEFT then
				tab = ui_Line({ outer, tab, inner })
			else
				tab = ui_Line({ inner, tab, outer })
			end

			if i == cx.tabs.idx - 1 then
				set_mode_style(cx.tabs[i + 1].mode)

				local open, close
				if
					Yatline.config.style_a.bg ~= "reset"
					or (Yatline.config.show_background and Yatline.config.style_c.bg ~= "reset")
				then
					if
						not Yatline.config.show_background
						or (Yatline.config.show_background and Yatline.config.style_c.bg == "reset")
					then
						sep_style.fg = Yatline.config.style_a.bg
						if Yatline.config.show_background then
							sep_style.bg = Yatline.config.style_c.bg
						end

						open = ui_Span(Yatline.config.inverse_separator.open)
						close = ui_Span(Yatline.config.inverse_separator.close)
					else
						sep_style.bg = Yatline.config.style_a.bg
						if Yatline.config.show_background then
							sep_style.fg = Yatline.config.style_c.bg
						end

						open = ui_Span(Yatline.config.section_separator.open)
						close = ui_Span(Yatline.config.section_separator.close)
					end
				else
					sep_style.fg = Yatline.config.style_c.fg

					open = ui_Span(Yatline.config.part_separator.open)
					close = ui_Span(Yatline.config.part_separator.close)
				end

				apply_style_table(open, sep_style)
				apply_style_table(close, sep_style)

				if in_side == Side.LEFT then
					lines[#lines + 1] = ui_Line({ tab, close })
				else
					lines[#lines + 1] = ui_Line({ open, tab })
				end
			else
				sep_style.fg = Yatline.config.style_c.fg
				if Yatline.config.show_background then
					sep_style.bg = Yatline.config.style_c.bg
				end

				lines[#lines + 1] = connect_separator(tab, in_side, SeparatorType.INNER, sep_style)
			end
		end
	end

	if in_side == Side.RIGHT then
		local rev = {}
		local n = #lines
		for i = 1, n do
			rev[i] = lines[n - i + 1]
		end
		return ui_Line(rev)
	else
		return ui_Line(lines)
	end
end

--==========================--
-- Component Coloreds Group --
--==========================--

Yatline.coloreds = {}
Yatline.coloreds.get = {}
Yatline.coloreds.has_separator = true

function Yatline.coloreds.create(coloreds, component_type)
	local spans = {}
	for i = 1, #coloreds do
		local colored = coloreds[i]
		local span = ui_Span(colored[1])
		set_component_style(span, component_type)
		span:fg(colored[2])

		spans[i] = span
	end

	return ui_Line(spans)
end

local PERM_COLORS = {}

local function refresh_perm_colors()
	PERM_COLORS = {
		["-"] = Yatline.config.permissions_s_fg,
		["r"] = Yatline.config.permissions_r_fg,
		["w"] = Yatline.config.permissions_w_fg,
		["x"] = Yatline.config.permissions_x_fg,
		["s"] = Yatline.config.permissions_x_fg,
		["S"] = Yatline.config.permissions_x_fg,
		["t"] = Yatline.config.permissions_x_fg,
		["T"] = Yatline.config.permissions_x_fg,
	}
end

local function get_perm_color(char)
	return PERM_COLORS[char] or Yatline.config.permissions_t_fg
end

function Yatline.coloreds.get:permissions()
	local hovered = cx.active.current.hovered
	if not hovered then return nil end

	local perm = hovered.cha:perm()
	if not perm then return nil end

	local coloreds = {}
	local idx = 1
	for c in perm:gmatch(".") do
		coloreds[idx] = { c, get_perm_color(c) }
		idx = idx + 1
	end

	return coloreds
end

function Yatline.coloreds.get:count(filter, zero_check)
	filter = filter or false
	zero_check = zero_check or false

	local num_yanked = #cx.yanked
	local num_selected = #cx.active.selected
	local num_files = #cx.active.current.files

	local coloreds = {}

	if filter then
		local files_count_fg, files_count_icon
		if cx.active.current.files.filter or cx.active.current.cwd.spec.is_search then
			files_count_fg = Yatline.config.filtereds.fg
			files_count_icon = Yatline.config.filtereds.icon
		else
			files_count_fg = Yatline.config.files.fg
			files_count_icon = Yatline.config.files.icon
		end

		if (zero_check and num_files > 0) or not zero_check then
			coloreds[#coloreds + 1] = { string_format("%s %d", files_count_icon, num_files), files_count_fg }
		end
	end

	if (zero_check and num_selected > 0) or not zero_check then
		if #coloreds > 0 then
			coloreds[#coloreds + 1] = { " ", Yatline.config.selected.fg }
		end

		coloreds[#coloreds + 1] = { string_format("%s %d", Yatline.config.selected.icon, num_selected), Yatline.config
			.selected.fg }
	end

	if (zero_check and num_yanked > 0) or not zero_check then
		local yanked_fg, yanked_icon
		if cx.yanked.is_cut then
			yanked_fg = Yatline.config.cut.fg
			yanked_icon = Yatline.config.cut.icon
		else
			yanked_fg = Yatline.config.copied.fg
			yanked_icon = Yatline.config.copied.icon
		end

		if #coloreds > 0 then
			coloreds[#coloreds + 1] = { " ", yanked_fg }
		end

		coloreds[#coloreds + 1] = { string_format("%s %d", yanked_icon, num_yanked), yanked_fg }
	end

	if #coloreds > 0 then
		return coloreds
	else
		return nil
	end
end

function Yatline.coloreds.get:task_states(zero_check)
	zero_check = zero_check or false

	local summary = cx.tasks.summary
	local coloreds = {}

	if (zero_check and summary.total > 0) or not zero_check then
		coloreds[#coloreds + 1] = { string_format("%s %d", Yatline.config.total.icon, summary.total), Yatline.config
			.total.fg }
	end

	if (zero_check and summary.success > 0) or not zero_check then
		if #coloreds > 0 then
			coloreds[#coloreds + 1] = { " ", Yatline.config.success.fg }
		end

		coloreds[#coloreds + 1] = { string_format("%s %d", Yatline.config.success.icon, summary.success), Yatline.config
			.success.fg }
	end

	if (zero_check and summary.failed > 0) or not zero_check then
		if #coloreds > 0 then
			coloreds[#coloreds + 1] = { " ", Yatline.config.failed.fg }
		end

		coloreds[#coloreds + 1] = { string_format("%s %d", Yatline.config.failed.icon, summary.failed), Yatline.config
			.failed.fg }
	end

	if #coloreds > 0 then
		return coloreds
	else
		return nil
	end
end

function Yatline.coloreds.get:string_based_component(component_name, fg, params)
	local getter = Yatline.string.get[component_name]

	if getter then
		local output = call_getter(getter, Yatline.string.get, params)

		if output ~= nil and output ~= "" then
			return { { output, fg } }
		end
	end

	return nil
end

--===============--
-- Configuration --
--===============--

local tmp_sep_style = { bg = nil, fg = nil }

local function config_components_separators(
	comps,
	seps,
	num_section_components,
	component_type,
	in_side,
	num_section_b_components,
	num_section_c_components
)
	local section_line_components = {}
	for i = 1, num_section_components do
		local comp = comps[i]
		if seps[i] then
			tmp_sep_style.bg = nil
			tmp_sep_style.fg = nil
			local separator_style = tmp_sep_style
			local separator_type

			if i ~= num_section_components then
				separator_type = SeparatorType.INNER

				if component_type == ComponentType.A then
					separator_style = Yatline.config.style_a
				elseif component_type == ComponentType.B then
					separator_style = Yatline.config.style_b
				else
					separator_style = Yatline.config.style_c
				end
			else
				separator_type = SeparatorType.OUTER

				if component_type == ComponentType.A then
					separator_style.fg = Yatline.config.style_a.bg
				elseif component_type == ComponentType.B then
					separator_style.fg = Yatline.config.style_b.bg
				else
					separator_style.fg = Yatline.config.style_c.bg
				end

				if component_type == ComponentType.A and num_section_b_components ~= 0 then
					separator_style.bg = Yatline.config.style_b.bg
				elseif num_section_c_components == 0 or component_type == ComponentType.C then
					if Yatline.config.show_background then
						separator_style.bg = Yatline.config.style_c.bg
					end
				else
					separator_style.bg = Yatline.config.style_c.bg
				end
			end

			comp = connect_padding(comp, component_type, in_side)
			section_line_components[i] = connect_separator(comp, in_side, separator_type, separator_style)
		else
			section_line_components[i] = comp
		end
	end

	return section_line_components
end

local function config_section(section, component_type)
	local comps = {}
	local seps = {}
	local count = 0

	for i = 1, #section do
		local component = section[i]
		local component_group = Yatline[component.type]

		if component_group then
			local output, ok = nil, false
			if component.custom then
				if component.name and component.name ~= "" then
					output = component.name
					ok = true
				end
			else
				local getter = component_group.get[component.name]

				if getter then
					output = call_getter(getter, component_group.get, component.params)

					if output ~= nil and output ~= "" then
						ok = true
					end
				end
			end

			if ok then
				count = count + 1
				comps[count] = component_group.create(output, component_type)
				seps[count] = component_group.has_separator
			end
		end
	end

	return comps, seps, count
end

local function config_line(side, in_side)
	local comps_a, seps_a, num_a = config_section(side.section_a, ComponentType.A)
	local comps_b, seps_b, num_b = config_section(side.section_b, ComponentType.B)
	local comps_c, seps_c, num_c = config_section(side.section_c, ComponentType.C)

	local section_a = config_components_separators(comps_a, seps_a, num_a, ComponentType.A, in_side, num_b, num_c)
	local section_b = config_components_separators(comps_b, seps_b, num_b, ComponentType.B, in_side, num_b, num_c)
	local section_c = config_components_separators(comps_c, seps_c, num_c, ComponentType.C, in_side, num_b, num_c)

	if in_side == Side.RIGHT then
		local reversed = {}
		local idx = 1

		for i = #section_c, 1, -1 do reversed[idx] = section_c[i]; idx = idx + 1 end
		for i = #section_b, 1, -1 do reversed[idx] = section_b[i]; idx = idx + 1 end
		for i = #section_a, 1, -1 do reversed[idx] = section_a[i]; idx = idx + 1 end

		return ui_Line(reversed)
	else
		return ui_Line({ ui_Line(section_a), ui_Line(section_b), ui_Line(section_c) })
	end
end

local function show_line(line)
	for _, side in pairs(line) do
		for _, section in pairs(side) do
			if #section ~= 0 then
				return true
			end
		end
	end

	return false
end

local function config_paragraph(area, line)
	local txt = ui_Text({ line }):area(area)
	if Yatline.config.show_background then
		return apply_style_table(txt, Yatline.config.style_c)
	end
	return txt
end

local function merge_tables(target, source)
	for k, v in pairs(source) do
		if type(v) == "table" and type(target[k]) == "table" then
			merge_tables(target[k], v)
		else
			target[k] = v
		end
	end
end

return {
	setup = function(_, config, pre_theme)
		if config then
			local active_theme = (rt and rt.term and rt.term.light and config.theme_light)
				or config.theme_dark
				or config.theme

			if active_theme then
				for key, value in pairs(active_theme) do
					if config[key] == nil then
						config[key] = value
					end
				end
			end

			merge_tables(Yatline.config, config)
		end

		if pre_theme then
			merge_tables(Yatline.config, pre_theme)
		end

		update_padding_cache()
		refresh_perm_colors()

		if Yatline.config.display_header_line then
			if show_line(Yatline.config.header_line) then
				Header._left = {}
				Header._right = {}

				Header.redraw = function(self)
					set_mode_style(cx.active.mode)
					local right = self:children_redraw(self.RIGHT)
					self._right_width = right:width()
					local left = self:children_redraw(self.LEFT)

					local left_line = config_line(Yatline.config.header_line.left, Side.LEFT)
					local right_line = config_line(Yatline.config.header_line.right, Side.RIGHT)

					return {
						config_paragraph(self._area, ui_Line({ left_line, left })),
						ui_Line({ right, right_line }):area(self._area):align(ui_Align.RIGHT),
					}
				end
			end
		else
			Header.redraw = function()
				return {}
			end
		end

		if Yatline.config.display_status_line then
			if show_line(Yatline.config.status_line) then
				Status._left = {}
				Status._right = {}

				Status.redraw = function(self)
					set_mode_style(cx.active.mode)
					local left = self:children_redraw(self.LEFT)
					local right = self:children_redraw(self.RIGHT)

					local left_line = config_line(Yatline.config.status_line.left, Side.LEFT)
					local right_line = config_line(Yatline.config.status_line.right, Side.RIGHT)

					local sum_right = ui_Line({ right, right_line })
					return {
						config_paragraph(self._area, ui_Line({ left_line, left })),
						sum_right:area(self._area):align(ui_Align.RIGHT),
						table_unpack(ui_redraw(Progress:new(self._area, sum_right:width()))),
					}
				end
			end
		else
			Status.redraw = function()
				return {}
			end
		end

		Root.layout = function(self)
			local constraints = {}
			for _, component in ipairs(Yatline.config.component_positions) do
				if
					(component == "header" and Yatline.config.display_header_line)
					or (component == "status" and Yatline.config.display_status_line)
				then
					table_insert(constraints, ui_Constraint.Length(1))
				elseif component == "tab" then
					table_insert(constraints, ui_Constraint.Fill(1))
				end
			end

			self._chunks = ui_Layout():direction(ui_Layout.VERTICAL):constraints(constraints):split(self._area)
		end

		Root.build = function(self)
			local childrens = {}
			local i = 1
			for _, component in ipairs(Yatline.config.component_positions) do
				if component == "header" and Yatline.config.display_header_line then
					table_insert(childrens, Header:new(self._chunks[i], cx.active))
					i = i + 1
				elseif component == "tab" then
					table_insert(childrens, Tab:new(self._chunks[i], cx.active))
					i = i + 1
				elseif component == "status" and Yatline.config.display_status_line then
					table_insert(childrens, Status:new(self._chunks[i], cx.active))
					i = i + 1
				end
			end

			table_insert(childrens, Modal:new(self._area))

			self._children = childrens
		end
	end,
}
