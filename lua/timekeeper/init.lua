local M = {}

function M.setup(opts)
	opts = opts or {}
end

local timer = nil
local start_time = nil
local total_timetable = {}
local total_time = 0
local data_file = vim.fn.stdpath("data") .. "/timekeeper.json"

local function save_data()
	local content = vim.json.encode(total_timetable)
	vim.uv.fs_open(data_file, "w", 438, function(err, fd)
		if err or not fd then
			return
		end

		vim.uv.fs_write(fd, content, 0, function(err)
			vim.uv.fs_close(fd, function() end)
		end)
	end)
end

local function save_time()
	if start_time then
		local filename = vim.api.nvim_buf_get_name(0)
		total_time = total_time + 60
		total_timetable[filename] = total_time
		local time_table = M.format_time(total_time)
		save_data()
		print(
			string.format(
				"Total time: %dh %dm %ds",
				time_table.total_hours,
				time_table.total_minutes,
				time_table.remaining_seconds
			)
		)
	end
end

local function load_data(callback)
	vim.uv.fs_open(data_file, "r", 438, function(err, fd)
		if err or not fd then
			if callback then
				callback({})
			end
			return
		end

		vim.uv.fs_fstat(fd, function(err, stat)
			if err or not stat then
				vim.uv.fs_close(fd, function() end)
				if callback then
					callback({})
				end
				return
			end

			vim.uv.fs_read(fd, stat.size, 0, function(err, content)
				vim.uv.fs_close(fd, function() end)
				if err or not content then
					if callback then
						callback({})
					end
					return
				end

				local data = {}
				if content and content ~= "" then
					local ok, decoded = pcall(vim.json.decode, content)
					data = ok and decoded or {}
				end
				if callback then
					callback(data)
				end
			end)
		end)
	end)
end

function M.start_tracking()
	local filename = vim.api.nvim_buf_get_name(0)
	start_time = os.time()
	load_data()
	if total_timetable[filename] then
		total_time = total_timetable[filename]
	else
		total_time = 0
	end
	print("Started tracking: " .. filename)
	if timer then
		timer:stop()
		timer:close()
	end
	timer = vim.uv.new_timer()
	timer:start(60000, 60000, vim.schedule_wrap(save_time))
end

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
		local time = M.format_time(total_time)
		print("Stopped tracking", print(time.total_hours, time.total_minutes, time.remaining_seconds))
	end
	start_time = nil
	total_time = 0
end

vim.api.nvim_create_user_command("Ta", M.start_tracking, {})
vim.api.nvim_create_user_command("Tb", M.stop_tracking, {})

return M
