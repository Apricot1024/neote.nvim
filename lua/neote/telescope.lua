-- neote.nvim/lua/neote/telescope.lua
-- 该模块实现了基于 Telescope 的笔记搜索与插入链接功能
-- 包括 NeoteFind（查找/打开笔记）和 NeoteInsert（插入链接）命令

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
        local fm = require("neote.parser").parse_frontmatter(path)
        local title = fm.title or vim.fn.fnamemodify(path, ":t:r")
        local aliases = fm.alias or {}
        if type(aliases) == "string" then aliases = {aliases} end
        local description = fm.description or ""
        local filename = vim.fn.fnamemodify(path, ":t:r")
        -- 合并所有可搜索内容
        local search_keys = {title, description, filename}
        for _, a in ipairs(aliases) do table.insert(search_keys, a) end
        table.insert(entries, {
            value = path,           -- 文件路径
            _title = title,         -- frontmatter 标题
            _aliases = aliases,     -- frontmatter 别名
            _filename = filename,   -- 文件名（不含扩展名）
            ordinal = table.concat(search_keys, " "), -- 用于排序/搜索的字符串
        })
    end
    return entries
end

-- 高亮显示条目标签（如 title/alias 命中时加标记）
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
                    actions.close(prompt_bufnr)
                    -- 没有匹配项时可新建笔记
                    vim.ui.input({prompt = "No match. Create new note? (y/n): "}, function(answer)
                        if answer and answer:lower():sub(1,1) == "y" then
                            capturenote.create(action_state.get_current_line())
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
    }):find()
end

-- 导出接口，注册命令
return {
    setup = function()
        -- 注册 NeoteFind 命令
        vim.api.nvim_create_user_command("NeoteFind", find_notes, {})
        -- 注册 NeoteInsert 命令
        vim.api.nvim_create_user_command("NeoteInsert", insert_link_at_cursor, {})
    end,
    search_notes = find_notes
}