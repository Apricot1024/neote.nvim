local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local scan = require("plenary.scandir")
local capturenote = require("neote.capturenote")

local function fuzzy_match(str, pattern)
    -- 简单模糊匹配：pattern 的每个字符都按顺序出现在 str 中即可
    str, pattern = str:lower(), pattern:lower()
    local j = 1
    for i = 1, #pattern do
        local c = pattern:sub(i,i)
        j = str:find(c, j, true)
        if not j then return false end
        j = j + 1
    end
    return true
end

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
            value = path,
            _title = title,
            _aliases = aliases,
            _filename = filename,
            ordinal = table.concat(search_keys, " "),
        })
    end
    return entries
end

local function highlight_label(entry, prompt)
    local prompt_l = vim.trim(prompt or ""):lower()
    local marks = {}
    if entry._title and entry._title ~= entry._filename then
        if entry._title:lower():find(prompt_l, 1, true) or fuzzy_match(entry._title, prompt_l) then
            table.insert(marks, "title: "..entry._title)
        end
    end
    for _, a in ipairs(entry._aliases or {}) do
        if a:lower():find(prompt_l, 1, true) or fuzzy_match(a, prompt_l) then
            table.insert(marks, "alias: "..a)
        end
    end
    if #marks > 0 then
        return entry._filename .. " [" .. table.concat(marks, ", ") .. "]"
    else
        return entry._filename
    end
end

local function find_notes()
    local entries = get_note_entries()
    local last_prompt = ""
    for _, entry in ipairs(entries) do
        entry.display = highlight_label(entry, last_prompt)
    end
    pickers.new({}, {
        prompt_title = "Find Notes",
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
                -- 修复：如果有 selection.value 就直接打开，不管输入内容
                if selection and selection.value then
                    actions.close(prompt_bufnr)
                    vim.cmd("tabnew " .. selection.value)
                else
                    actions.close(prompt_bufnr)
                    vim.ui.input({prompt = "No match. Create new note? (y/n): "}, function(answer)
                        if answer and answer:lower():sub(1,1) == "y" then
                            capturenote.create(action_state.get_current_line())
                        end
                    end)
                end
            end)
            return true
        end,
        previewer = false,
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

return {
    setup = function()
        vim.api.nvim_create_user_command("NeoteFind", find_notes, {})
    end,
    search_notes = find_notes
}