local M = {}
-- package.cpath = package.cpath
-- 	.. ";/nix/store/pb55r4xamynlf4n4k15qfxzggm0vx2lc-lua5.2-luasql-sqlite3-2.7.0-1/lib/lua/5.2/?.so"
local sqlite3 = require("luasql.sqlite3")
local env = nil
local conn = nil
local db_path = "/home/ash/timekeeper/test.db"

function M.setup(opts)
	opts = opts or {}
end

local timer = nil
local total_timetable = {}
local inactivity_timer = nil
local inactivity_limit = 20000
local saving_interval = 10000
local idle_mode = false
-- TODO: add saving current date for statistics

local function turn_idle_mode()
	print("the idle mode was turned on")
	idle_mode = true
end
local function reset_inactivity_timer()
	print("The inactivity_timer was reset")
	if inactivity_timer then
		inactivity_timer:stop()
		inactivity_timer:start(inactivity_limit, 0, vim.schedule_wrap(turn_idle_mode))
		idle_mode = false
	end
end

-- returns the total time from the database
function M.load_data_db(filename)
	conn = env:connect(db_path)
	local query = string.format("select total_time from timetable where filename = '%s';", filename)
	local curr = conn:execute(query)
	local row_ = curr:fetch({}, "a")
	local res = 0
	if row_ then
		-- print("Data base loaded with total time:", row_.total_time)
		res = row_.total_time
	else
		print("No entry for", filename)
	end
	curr:close()
	return res
end

-- saves total_time to the database
function M.save_data_db(filename)
	print("in the save db function")
	local time_from_db = M.load_data_db(filename)
	local time_passed = time_from_db + (saving_interval / 1000) -- in seconds
	local query = string.format(
		[[
	  INSERT INTO timetable (filename, total_time)
	  VALUES ('%s', %d)
	  ON CONFLICT(filename) DO UPDATE SET total_time = excluded.total_time;
		]],
		filename,
		time_passed
	)
	if conn then
		if not idle_mode then
			conn:execute(query)
			print("Saving to database", time_passed)
		else
			print("Cannot save, idle mode")
		end
	end
end

function M.start_tracking()
	local filename = vim.api.nvim_buf_get_name(0)
	local unstored_filenames = { "^$", "^oil://" }
	for _, pattern in ipairs(unstored_filenames) do
		if filename:match(pattern) then
			return
		end
	end
	env = sqlite3.sqlite3()
	conn = env:connect(db_path)

	print("Started tracking: " .. filename)
	if timer then
		timer:stop()
		timer:close()
	end
	timer = vim.uv.new_timer()
	timer:start(
		saving_interval,
		saving_interval,
		vim.schedule_wrap(function()
			M.save_data_db(filename)
		end)
	)
	inactivity_timer = vim.loop.new_timer()
	inactivity_timer:start(
		inactivity_limit,
		0,
		vim.schedule_wrap(function()
			turn_idle_mode()
		end)
	)
end

function M.format_time(seconds)
	local time = {}
	time.total_hours = math.floor(seconds / 3600)
	time.total_minutes = math.floor((seconds - (time.total_hours * 3600)) / 60)
	time.total_seconds = seconds - (time.total_hours * 3600 + time.total_minutes * 60)
	return time
end

function M.stop_tracking()
	if timer then
		timer:stop()
		timer:close()
		timer = nil
		print("Stopped tracking")
	end
	if conn then
		conn:close()
	end
	if env then
		env:close()
	end
end

local function get_db_content()
	local query = string.format([[
		select * from timetable
		]])
	env = sqlite3.sqlite3()
	conn = env:connect(db_path)
	local curr = conn:execute(query)
	local row = curr:fetch({}, "a")
	local res = {}
	while row do
		table.insert(res, { filename = row.filename, total_time = row.total_time })
		row = curr:fetch({}, "a")
	end
	curr:close()
	return res
end

local function get_current_project()
	local cwd = vim.loop.cwd() -- gets current working directory
	local query = [[select * from timetable where filename like ?]]
	local param = cwd .. "%"
	env = sqlite3.sqlite3()
	conn = env:connect(db_path)
	local curr = conn:execute(query, param)
	local row = curr:fetch({}, "a")
	local project_lines = {}
	while row do
		table.insert(project_lines, { filename = row.filename, total_time = row.total_time })
		row = curr:fetch({}, "a")
	end
	curr:close()
	print("The res given is", vim.inspect(project_lines))
end

vim.api.nvim_set_hl(0, "Header", { fg = "#00ff00", bold = true })
function M.open()
	-- get_current_project()
	local buf = vim.api.nvim_create_buf(false, true) -- [listed=false, scratch=true]
	local opts = {
		relative = "editor",
		width = 100,
		height = 30,
		row = 5,
		col = 10,
		style = "minimal",
		border = "rounded",
	}
	local win = vim.api.nvim_open_win(buf, true, opts)
	local content_lines = get_db_content()
	-- print(vim.inspect(content_lines))
	local lines = {}
	table.insert(lines, "All files")
	for _, dict in ipairs(content_lines) do
		local format_time_table = M.format_time(dict.total_time)
		table.insert(
			lines,
			string.format(
				"filename : %stotal_hours : %s, total_minutes: %s, total_seconds: %s",
				dict.filename,
				format_time_table.total_hours,
				format_time_table.total_minutes,
				format_time_table.total_seconds
			)
		)
	end
	vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)
	local ns = vim.api.nvim_create_namespace("Timekeeper")
	vim.api.nvim_buf_add_highlight(buf, ns, "Header", 0, 0, -1)
end

vim.api.nvim_create_user_command("Ta", M.start_tracking, {})
vim.api.nvim_create_user_command("Tb", M.stop_tracking, {})
vim.api.nvim_create_user_command("Timekeeper", M.open, {})
-- TODO: tab like mechanism for headers

vim.api.nvim_create_autocmd("BufLeave", {
	callback = function()
		M.stop_tracking()
	end,
})
vim.api.nvim_create_autocmd("BufEnter", {
	callback = function()
		M.start_tracking()
	end,
})
vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter" }, {
	callback = reset_inactivity_timer,
})

-- require(something) gives the M table
return M
