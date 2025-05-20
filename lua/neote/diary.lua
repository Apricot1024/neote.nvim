local M = {}
local scan = require("plenary.scandir")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local utils = require("telescope.previewers.utils")

-- 获取当前日期相关格式
local function get_date_formats()
    local today = os.date("*t")
    
    -- 格式化日期为 "YYYY-MM-DD"
    local daily_fmt = string.format("%04d-%02d-%02d", today.year, today.month, today.day)
    
    -- 计算当前周的周一日期
    local day_of_week = today.wday
    -- 根据星期几计算到本周一的偏移 (1 是星期天, 2 是星期一)
    local days_to_monday = (day_of_week == 1) and 6 or (day_of_week - 2)
    local monday = os.time{year=today.year, month=today.month, day=today.day} - days_to_monday * 86400
    local monday_date = os.date("*t", monday)
    local weekly_fmt = string.format("%04d-W%02d", monday_date.year, os.date("%V", monday))
    
    -- 月度格式 "YYYY-MM"
    local monthly_fmt = string.format("%04d-%02d", today.year, today.month)
    
    return {
        daily = daily_fmt,
        weekly = weekly_fmt,
        monthly = monthly_fmt
    }
end

-- 创建日记条目
function M.create_diary(type)
    local valid_types = {daily = true, weekly = true, monthly = true}
    type = type or "daily" -- 默认为每日日记
    
    if not valid_types[type] then
        vim.notify("无效的日记类型: " .. type .. "。有效类型: daily, weekly, monthly", vim.log.levels.ERROR)
        return
    end
    
    local date_formats = get_date_formats()
    local date_str = date_formats[type]
    
    -- 文件名格式: [类型]-[日期].md，例如 daily-2023-01-01.md
    local filename = type .. "-" .. date_str .. ".md"
    local path = _G.neote.config.diary.dir .. "/" .. filename
    
    -- 检查是否已存在，如果存在则直接打开
    if vim.fn.filereadable(path) == 1 then
        vim.cmd("edit " .. path)
        vim.notify("Opening existed " .. type .. " diary", vim.log.levels.INFO)
        return
    end
    
    -- 获取对应模板
    local template_name = _G.neote.config.diary.templates[type]
    local template_path = _G.neote.config.templates_dir .. "/" .. template_name
    
    -- 如果模板存在，则读取模板内容
    local content = ""
    if template_name and vim.fn.filereadable(template_path) == 1 then
        content = table.concat(vim.fn.readfile(template_path), "\n")
        -- 替换模板变量
        content = content:gsub("{{title}}", type .. " " .. date_str)
        content = content:gsub("{{date}}", os.date("%Y-%m-%d"))
        content = content:gsub("{{type}}", "diary-" .. type)
        
        -- 特别替换
        if type == "daily" then
            content = content:gsub("{{day}}", date_str)
        elseif type == "weekly" then
            content = content:gsub("{{week}}", date_str)
        elseif type == "monthly" then
            content = content:gsub("{{month}}", date_str)
        end
    else
        -- 如果模板不存在，创建基本内容
        content = string.format([[
---
title: "%s"
date: %s
type: diary-%s
tags: diary, %s
---

# %s

]], 
        type .. " " .. date_str, 
        os.date("%Y-%m-%d"), 
        type, 
        type,
        type .. " " .. date_str)
    end
    
    -- 写入文件并打开
    vim.fn.writefile(vim.split(content, "\n"), path)
    vim.cmd("edit " .. path)
    vim.notify("已创建" .. type .. "日记: " .. filename, vim.log.levels.INFO)
end

-- 日记预览器
local function diary_previewer()
    return previewers.new_buffer_previewer({
        define_preview = function(self, entry, status)
            local path = entry.path
            if not path or vim.fn.filereadable(path) == 0 then
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"无文件"})
                return
            end
            local lines = vim.fn.readfile(path)
            -- 只显示前 50 行，防止大文件卡顿
            if #lines > 50 then
                lines = vim.list_slice(lines, 1, 50)
                table.insert(lines, "...(已截断)")
            end
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            utils.highlighter(self.state.bufnr, path)
        end,
    })
end

-- 查找日记
function M.find_diary(opts)
    opts = opts or {}
    local type_filter = opts.type or nil
    
    -- 扫描日记目录
    local diary_entries = {}
    local files = scan.scan_dir(_G.neote.config.diary.dir, {search_pattern = "%.md$"})
    
    for _, path in ipairs(files) do
        local filename = vim.fn.fnamemodify(path, ":t")
        local file_type = filename:match("^([^-]+)-")
        
        -- 应用类型过滤
        if not type_filter or file_type == type_filter then
            -- 解析 frontmatter 获取标题
            local fm = require("neote.parser").parse_frontmatter(path)
            local title = fm.title or vim.fn.fnamemodify(path, ":t:r")
            local date_str = fm.date or ""
            
            table.insert(diary_entries, {
                filename = filename,
                title = title,
                date = date_str,
                path = path,
                type = file_type or "unknown",
                display = string.format("%s [%s]", title, file_type or "")
            })
        end
    end
    
    -- 按日期排序（降序）
    table.sort(diary_entries, function(a, b)
        return a.filename > b.filename
    end)
    
    -- 使用 Telescope 显示结果
    pickers.new({}, {
        prompt_title = "查找日记",
        finder = finders.new_table({
            results = diary_entries,
            entry_maker = function(entry)
                return {
                    value = entry.path,
                    display = entry.display,
                    ordinal = entry.filename .. " " .. entry.title,
                    path = entry.path,
                    filename = entry.filename,
                    title = entry.title
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = diary_previewer(),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if selection and selection.value then
                    vim.cmd("edit " .. selection.value)
                end
            end)
            return true
        end,
        layout_strategy = "horizontal",
        layout_config = {
            width = 0.9,
            height = 0.8,
            preview_width = 0.6,
        },
    }):find()
end

-- 设置命令和键映射
function M.setup()
    -- 创建日记命令
    vim.api.nvim_create_user_command("NeoteDiaryDaily", function()
        M.create_diary("daily")
    end, {})
    
    vim.api.nvim_create_user_command("NeoteDiaryWeekly", function()
        M.create_diary("weekly")
    end, {})
    
    vim.api.nvim_create_user_command("NeoteDiaryMonthly", function()
        M.create_diary("monthly")
    end, {})
    
    -- 查找日记命令
    vim.api.nvim_create_user_command("NeoteDiaryFind", function(opts)
        local args = {}
        for _, arg in ipairs(opts.fargs) do
            local k, v = arg:match("^(%w+)%=(.+)$")
            if k and v then args[k] = v end
        end
        M.find_diary(args)
    end, {nargs="*", complete=function(_, _, _)
        return {"type=daily", "type=weekly", "type=monthly"}
    end})
    
    -- 通用日记创建命令
    vim.api.nvim_create_user_command("NeoteDiary", function(opts)
        local diary_type = opts.args
        if diary_type == "" then
            -- 如果没有指定类型，提供选择菜单
            vim.ui.select({"daily", "weekly", "monthly"}, {
                prompt = "选择日记类型:"
            }, function(choice)
                if choice then
                    M.create_diary(choice)
                end
            end)
        else
            M.create_diary(diary_type)
        end
    end, {nargs="?", complete=function(_, _, _)
        return {"daily", "weekly", "monthly"}
    end})
end

return M
