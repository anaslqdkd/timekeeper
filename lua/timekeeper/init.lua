local M = {}
package.cpath = package.cpath
	.. ";/nix/store/pb55r4xamynlf4n4k15qfxzggm0vx2lc-lua5.2-luasql-sqlite3-2.7.0-1/lib/lua/5.2/?.so"
local sqlite3 = require("luasql.sqlite3")
local env = nil
local conn = nil
local db_path = "test.db"

function M.setup(opts)
	opts = opts or {}
end

local timer = nil
local total_timetable = {}

-- returns the total time from the database
function M.load_data_db(filename)
	conn = env:connect(db_path)
	local query = string.format("select total_time from timetable where filename = '%s';", filename)
	local curr = conn:execute(query)
	local row_ = curr:fetch({}, "a")
	local res = 0
	if row_ then
		print("Data base loaded with total time:", row_.total_time)
		res = row_.total_time
	else
		print("No entry for", filename)
	end
	curr:close()
	return res
end

-- saves total_time to the database
function M.save_data_db(filename)
	local time_from_db = M.load_data_db(filename)
	local time_passed = time_from_db + 10
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
		conn:execute(query)
		print("Saving to database", time_passed)
	end
end

function M.start_tracking()
	-- TODO: have a variable called session_time, but it will be rewritten?
	local filename = vim.api.nvim_buf_get_name(0)
	if filename == "" then
		return
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
		10000,
		10000,
		vim.schedule_wrap(function()
			M.save_data_db(filename)
		end)
	)
end
-- TODO: add events to call the stop tracking function

function M.format_time(seconds)
	local time = {}
	time.total_minutes = math.floor(seconds / 60)
	time.total_hours = math.floor(time.total_minutes / 60)
	time.remaining_seconds = time.total_minutes % 60
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

vim.api.nvim_create_user_command("Ta", M.start_tracking, {})
vim.api.nvim_create_user_command("Tb", M.stop_tracking, {})

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

-- require(something) gives the M table
return M
