-- neote.nvim/lua/neote/telescope.lua
-- 该模块实现了基于 Telescope 的笔记搜索与插入链接功能
-- 包括 NeoteFind（查找/打开笔记）、NeoteInsert（插入链接）和 NeoteSearch（全文搜索）命令

local pickers = require("telescope.pickers")           -- Telescope 弹窗选择器
local finders = require("telescope.finders")           -- Telescope 查找器
local conf = require("telescope.config").values        -- Telescope 配置
local actions = require("telescope.actions")            -- Telescope 动作
local action_state = require("telescope.actions.state") -- Telescope 状态
local scan = require("plenary.scandir")                 -- 目录扫描工具
local capturenote = require("neote.capturenote")        -- 新建笔记逻辑
local previewers = require("telescope.previewers")      -- Telescope 预览器
local utils = require("telescope.previewers.utils")     -- Telescope 工具

-- 规范化文本：将短横线、下划线和空格统一处理为空格，便于匹配
local function normalize_text(text)
    return text:gsub("[-_]", " ")
end

-- 简单模糊匹配：pattern 的每个字符都按顺序出现在 str 中即可
-- 增强版：将短横线、下划线、空格视为等价字符
local function fuzzy_match(str, pattern)
    -- 将短横线、下划线统一为空格后再比较
    str = normalize_text(str:lower())
    pattern = normalize_text(pattern:lower())
    
    local j = 1
    for i = 1, #pattern do
        local c = pattern:sub(i,i)
        j = str:find(c, j, true)
        if not j then return false end
        j = j + 1
    end
    return true
end

-- 获取所有笔记条目，包含 frontmatter 信息、文件名、可搜索内容等
local function get_note_entries()
    local notes = scan.scan_dir(_G.neote.config.notes_dir, {search_pattern = "%.md$"})
    local entries = {}
    for _, path in ipairs(notes) do
        -- 安全获取 frontmatter
        local fm = require("neote.parser").parse_frontmatter(path)
        local title = fm.title or vim.fn.fnamemodify(path, ":t:r")
        local aliases = fm.alias or {}
        if type(aliases) == "string" then aliases = {aliases} end
        local description = fm.description or ""
        local filename = vim.fn.fnamemodify(path, ":t:r")
        -- 合并所有可搜索内容
        local search_keys = {title, filename}
        -- 加入 description 内容到搜索内容
        if description and description ~= "" then
            table.insert(search_keys, description)
        end
        for _, a in ipairs(aliases) do table.insert(search_keys, a) end
        table.insert(entries, {
            value = path,           -- 文件路径
            _title = title,         -- frontmatter 标题
            _aliases = aliases,     -- frontmatter 别名
            _filename = filename,   -- 文件名（不含扩展名）
            _description = description, -- frontmatter 描述
            ordinal = table.concat(search_keys, " "), -- 用于排序/搜索的字符串
        })
    end
    return entries
end

-- 高亮显示条目标签（如 title/alias/description 命中时加标记）
local function highlight_label(entry, prompt)
    local prompt_l = vim.trim(prompt or ""):lower()
    local marks = {}
    if entry._title and entry._title ~= entry._filename then
        -- 使用规范化文本匹配
        local norm_title = normalize_text(entry._title:lower())
        local norm_prompt = normalize_text(prompt_l)
        if norm_title:find(norm_prompt, 1, true) or fuzzy_match(entry._title, prompt_l) then
            table.insert(marks, "title: "..entry._title)
        end
    end
    
    -- 添加对 description 的匹配高亮
    if entry._description and entry._description ~= "" then
        local norm_desc = normalize_text(entry._description:lower())
        local norm_prompt = normalize_text(prompt_l)
        if norm_desc:find(norm_prompt, 1, true) or fuzzy_match(entry._description, prompt_l) then
            -- 截取 description 的部分内容以避免过长
            local desc_preview = entry._description
            if #desc_preview > 30 then
                desc_preview = desc_preview:sub(1, 27) .. "..."
            end
            table.insert(marks, "desc: "..desc_preview)
        end
    end
    
    for _, a in ipairs(entry._aliases or {}) do
        -- 使用规范化文本匹配
        local norm_alias = normalize_text(a:lower())
        local norm_prompt = normalize_text(prompt_l)
        if norm_alias:find(norm_prompt, 1, true) or fuzzy_match(a, prompt_l) then
            table.insert(marks, "alias: "..a)
        end
    end
    
    if #marks > 0 then
        return entry._filename .. " [" .. table.concat(marks, ", ") .. "]"
    else
        return entry._filename
    end
end

-- 自定义预览器：显示文件内容
local function note_previewer()
    return previewers.new_buffer_previewer({
        define_preview = function(self, entry, status)
            local path = entry.value or entry.path
            if not path or vim.fn.filereadable(path) == 0 then
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"No file"})
                return
            end
            local lines = vim.fn.readfile(path)
            -- 只显示前 50 行，防止大文件卡顿
            if #lines > 50 then
                lines = vim.list_slice(lines, 1, 50)
                table.insert(lines, "...(truncated)")
            end
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            utils.highlighter(self.state.bufnr, path)
        end,
    })
end

-- NeoteFind：Telescope 搜索并打开笔记
local function find_notes()
    local entries = get_note_entries()
    local last_prompt = ""
    for _, entry in ipairs(entries) do
        entry.display = highlight_label(entry, last_prompt)
    end
    pickers.new({}, {
        prompt_title = "Find Notes", -- 弹窗标题
        finder = finders.new_table({
            results = entries,
            entry_maker = function(entry)
                return entry
            end
        }),
        -- 使用 fzf 排序器（如可用），否则用默认排序
        sorter = (require("telescope").extensions and require("telescope").extensions.fzf and require("telescope").extensions.fzf.native_fzf_sorter and require("telescope").extensions.fzf.native_fzf_sorter()) or conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                -- 若有 selection.value，直接打开文件
                if selection and selection.value then
                    actions.close(prompt_bufnr)
                    vim.cmd("tabnew " .. selection.value)
                else
                    local current_line = action_state.get_current_line()
                    actions.close(prompt_bufnr)
                    
                    -- 没有匹配项时使用居中输入框询问是否新建笔记
                    -- 使用 vim.schedule 确保 Telescope 关闭后再显示输入框
                    vim.schedule(function()
                        local create_centered_floating_input = require("neote.capturenote").create_centered_floating_input
                        if create_centered_floating_input then
                            create_centered_floating_input({
                                prompt = "No match. Create new note? (y/n): ",
                                default = "y"  -- 默认为 y, 方便用户直接按回车确认
                            }, function(answer)
                                if answer and answer:lower():sub(1,1) == "y" then
                                    capturenote.create(current_line)
                                end
                            end)
                        else
                            -- 降级到默认输入
                            vim.ui.input({prompt = "No match. Create new note? (y/n): "}, function(answer)
                                if answer and answer:lower():sub(1,1) == "y" then
                                    capturenote.create(current_line)
                                end
                            end)
                        end
                    end)
                end
            end)
            return true
        end,
        previewer = note_previewer(), -- 启用内容预览
        entry_display = function(entry)
            return entry.display or entry._filename or ""
        end,
        on_input_filter_cb = function(prompt)
            last_prompt = prompt or ""
            for _, entry in ipairs(entries) do
                entry.display = highlight_label(entry, last_prompt)
            end
            return {prompt = prompt}
        end,
        -- 添加布局配置，使预览窗口更宽
        layout_strategy = "horizontal",
        layout_config = {
            width = 0.9,
            height = 0.8,
            preview_width = 0.6, -- 预览窗口占总宽度的60%
        },
    }):find()
end

-- NeoteInsert：Telescope 搜索后在光标处插入 [[filename]] 链接
local function insert_link_at_cursor()
    local entries = get_note_entries()
    local last_prompt = ""
    for _, entry in ipairs(entries) do
        entry.display = highlight_label(entry, last_prompt)
    end
    pickers.new({}, {
        prompt_title = "Insert Note Link",
        finder = finders.new_table({
            results = entries,
            entry_maker = function(entry)
                return entry
            end
        }),
        sorter = (require("telescope").extensions and require("telescope").extensions.fzf and require("telescope").extensions.fzf.native_fzf_sorter and require("telescope").extensions.fzf.native_fzf_sorter()) or conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                if selection and selection._filename then
                    actions.close(prompt_bufnr)
                    -- 构造链接文本
                    local link = string.format("[[%s]]", selection._filename)
                    -- 获取当前光标位置
                    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
                    local line = vim.api.nvim_get_current_line()
                    local before = line:sub(1, col)
                    local after = line:sub(col + 1)
                    local new_line = before .. link .. after
                    vim.api.nvim_set_current_line(new_line)
                    -- 移动光标到插入后
                    vim.api.nvim_win_set_cursor(0, {row, col + #link})
                else
                    actions.close(prompt_bufnr)
                end
            end)
            return true
        end,
        previewer = note_previewer(), -- 启用内容预览
        entry_display = function(entry)
            return entry.display or entry._filename or ""
        end,
        on_input_filter_cb = function(prompt)
            last_prompt = prompt or ""
            for _, entry in ipairs(entries) do
                entry.display = highlight_label(entry, last_prompt)
            end
            return {prompt = prompt}
        end,
        -- 添加布局配置，使预览窗口更宽
        layout_strategy = "horizontal",
        layout_config = {
            width = 0.9,
            height = 0.8,
            preview_width = 0.6, -- 预览窗口占总宽度的60%
        },
    }):find()
end

-- NeoteSearch: 全文搜索笔记内容
local function search_note_content()
    local notes = scan.scan_dir(_G.neote.config.notes_dir, {search_pattern = "%.md$"})
    
    -- 创建带有进度信息的辅助函数
    local function get_content_entries(update_progress)
        local entries = {}
        for i, path in ipairs(notes) do
            -- 更新进度条
            if update_progress and i % 5 == 0 then
                update_progress("读取笔记内容...", i, #notes)
            end
            
            -- 安全读取文件内容
            local ok, lines = pcall(vim.fn.readfile, path)
            if not ok or not lines then goto continue end
            
            -- 读取frontmatter信息作为辅助信息
            local fm = require("neote.parser").parse_frontmatter(path)
            local title = fm.title or vim.fn.fnamemodify(path, ":t:r")
            local filename = vim.fn.fnamemodify(path, ":t:r")
            
            -- 完整文本内容
            local content = table.concat(lines, "\n")
            
            -- 跳过空文件
            if vim.trim(content) == "" then goto continue end
            
            -- 构建条目
            table.insert(entries, {
                value = path,          -- 文件路径
                _title = title,        -- frontmatter标题
                _filename = filename,  -- 文件名
                _content = content,    -- 完整文本内容
                ordinal = content,     -- 用于匹配的文本
            })
            
            ::continue::
        end
        return entries
    end
    
    -- 定制预览器，高亮匹配内容
    local function content_previewer()
        return previewers.new_buffer_previewer({
            define_preview = function(self, entry, status)
                local path = entry.value
                if not path or vim.fn.filereadable(path) ~= 1 then
                    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"无文件"})
                    return
                end
                
                -- 读取文件内容
                local lines = vim.fn.readfile(path)
                if #lines > 500 then
                    lines = vim.list_slice(lines, 1, 500)
                    table.insert(lines, "...(内容过长，已截断)")
                end
                
                -- 显示内容
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                utils.highlighter(self.state.bufnr, path)
                
                -- Fix for prompt window access - safely get the search text
                local search_text = ""
                local ok, prompt_bufnr = pcall(function()
                    -- Different versions of telescope have different picker.prompt_win structures
                    if status.picker and type(status.picker) == "table" then
                        if status.picker.prompt_bufnr then
                            return status.picker.prompt_bufnr
                        elseif type(status.picker.prompt_win) == "table" and status.picker.prompt_win.buf then
                            return status.picker.prompt_win.buf
                        end
                    end
                    return nil
                end)
                
                if ok and prompt_bufnr then
                    -- Safely get the text from the prompt buffer
                    search_text = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, 1, false)[1] or ""
                end
                
                if search_text and search_text ~= "" then
                    -- 创建不区分大小写的模式
                    local pattern = vim.fn.escape(search_text, "\\[]^$.*")
                    -- 标记所有匹配项
                    for i, line in ipairs(lines) do
                        -- 使用 vim 的 matchadd() 高亮匹配
                        pcall(function()
                            vim.fn.matchadd("Search", pattern, 11, -1, {window = self.state.winid})
                        end)
                    end
                end
            end,
        })
    end
    
    -- 创建带有进度条的picker
    local function with_progress_bar(fn)
        local progress_win = nil
        local progress_buf = nil
        
        -- 创建进度条窗口
        local function create_progress()
            progress_buf = vim.api.nvim_create_buf(false, true)
            local width = 60
            local height = 1
            local row = math.floor((vim.o.lines - height) / 2)
            local col = math.floor((vim.o.columns - width) / 2)
            
            vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, {"加载笔记内容..."})
            
            progress_win = vim.api.nvim_open_win(progress_buf, false, {
                relative = "editor",
                width = width,
                height = height,
                row = row,
                col = col,
                style = "minimal",
                border = "rounded",
            })
        end
        
        -- 更新进度条
        local function update_progress(msg, current, total)
            if not progress_win or not vim.api.nvim_win_is_valid(progress_win) then return end
            
            local percent = math.floor(current / total * 100)
            local text = string.format("%s (%d%%)", msg, percent)
            vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, {text})
        end
        
        -- 清理进度条
        local function clear_progress()
            if progress_win and vim.api.nvim_win_is_valid(progress_win) then
                vim.api.nvim_win_close(progress_win, true)
            end
            progress_win = nil
            
            if progress_buf and vim.api.nvim_buf_is_valid(progress_buf) then
                vim.api.nvim_buf_delete(progress_buf, {force = true})
            end
            progress_buf = nil
        end
        
        -- 执行带有进度条的函数
        create_progress()
        local ok, result = pcall(fn, update_progress)
        clear_progress()
        
        if not ok then
            vim.notify("搜索出错: " .. tostring(result), vim.log.levels.ERROR)
            return nil
        end
        
        return result
    end
    
    -- 获取带有进度条的条目列表
    local entries = with_progress_bar(get_content_entries)
    if not entries then return end
    
    -- 创建picker
    pickers.new({}, {
        prompt_title = "搜索笔记内容",
        finder = finders.new_table({
            results = entries,
            entry_maker = function(entry)
                return {
                    value = entry.value,
                    display = entry._filename .. " [" .. entry._title .. "]",
                    ordinal = entry.ordinal,
                    _filename = entry._filename,
                    _title = entry._title,
                }
            end
        }),
        sorter = conf.generic_sorter({}),
        previewer = content_previewer(),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if selection and selection.value then
                    -- 获取当前搜索文本，用于跳转定位
                    local search_text = action_state.get_current_line()
                    vim.cmd("tabnew " .. selection.value)
                    
                    -- 如果有搜索文本，尝试跳转到第一个匹配位置
                    if search_text and search_text ~= "" then
                        vim.schedule(function()
                            -- 第一次尝试精确搜索
                            vim.cmd("normal! gg")
                            local pattern = vim.fn.escape(search_text, "/\\.*$^[]")
                            local cmd = "/" .. pattern .. "\\c"
                            pcall(function() vim.cmd("normal! " .. cmd .. "\\<CR>") end)
                        end)
                    end
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

-- 导出接口，注册命令
return {
    setup = function()
        -- 注册 NeoteFind 命令
        vim.api.nvim_create_user_command("NeoteFind", find_notes, {})
        -- 注册 NeoteInsert 命令
        vim.api.nvim_create_user_command("NeoteInsert", insert_link_at_cursor, {})
        -- 注册 NeoteSearch 命令 - 全文搜索
        vim.api.nvim_create_user_command("NeoteSearch", search_note_content, {})
    end,
    search_notes = find_notes,
    search_content = search_note_content  -- 导出全文搜索函数
}