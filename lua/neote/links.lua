-- neote.nvim/lua/neote/links.lua
-- Link indexing and navigation
local M = {}
local scan = require("plenary.scandir")
local parser = require("neote.parser")

local function build_index()
    -- always rebuild for up-to-date links
    local notes = scan.scan_dir(_G.neote.config.notes_dir, {search_pattern = "%.md$"})
    local titles, aliases, outlinks, backlinks, file2title, all_links = {}, {}, {}, {}, {}, {}
    for _, path in ipairs(notes) do
        local fm = parser.parse_frontmatter(path)
        local filename = vim.fn.fnamemodify(path, ":t:r")
        local title = fm.title or filename
        file2title[path] = title
        -- 标准化所有可用key
        titles[title:lower()] = path
        titles[filename:lower()] = path
        if fm.alias then
            for _, a in ipairs(fm.alias) do
                aliases[a:lower()] = path
            end
        end
    end
    -- 存储所有链接的指向关系
    for _, path in ipairs(notes) do
        local lines = vim.fn.readfile(path)
        local fm = parser.parse_frontmatter(path)
        local filename = vim.fn.fnamemodify(path, ":t:r")
        local title = fm.title or filename
        local outs = {}
        for _, line in ipairs(lines) do
            for link in line:gmatch("%[%[([^%[%]]+)%]%]") do
                local link_key = vim.trim((link:match("^([^|]+)") or link)):lower()
                table.insert(outs, link_key)
                -- 存储所有链接的指向关系
                all_links[path] = all_links[path] or {}
                table.insert(all_links[path], link_key)
            end
        end
        outlinks[title:lower()] = outs
    end
    -- 重新计算backlinks，遍历所有笔记和所有链接
    for from_path, links in pairs(all_links) do
        for _, link_key in ipairs(links) do
            -- link_key 可能是title/filename/alias
            local to_path = titles[link_key] or aliases[link_key]
            if to_path then
                local to_title = file2title[to_path]:lower()
                backlinks[to_title] = backlinks[to_title] or {}
                local from_title = file2title[from_path]:lower()
                -- 避免重复
                local exists = false
                for _, v in ipairs(backlinks[to_title]) do
                    if v == from_title then exists = true break end
                end
                if not exists then
                    table.insert(backlinks[to_title], from_title)
                end
            end
        end
    end
    return {titles = titles, aliases = aliases, outlinks = outlinks, backlinks = backlinks, file2title = file2title, all_links = all_links}
end
M.build_index = build_index

local function get_title_for_buf(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local path = vim.api.nvim_buf_get_name(bufnr)
    if not path or path == '' then return nil end
    local fm = parser.parse_frontmatter(path)
    local filename = vim.fn.fnamemodify(path, ":t:r")
    return (fm.title or filename):lower()
end

function M.show_links()
    local idx = build_index()
    local title = get_title_for_buf()
    if not title then
        vim.notify("No note detected in current buffer", vim.log.levels.WARN)
        return
    end
    local outs = idx.outlinks[title] or {}
    local backs = idx.backlinks[title] or {}
    local opts = {}
    if #outs > 0 then
        table.insert(opts, {group = 'Outlinks', items = outs})
    end
    if #backs > 0 then
        table.insert(opts, {group = 'Backlinks', items = backs})
    end
    if #opts == 0 then
        vim.notify("无链接 (No links)", vim.log.levels.INFO)
        return
    end
    local select_items = {}
    local seen = {}
    for _, group in ipairs(opts) do
        table.insert(select_items, '--- '..group.group..' ---')
        for _, k in ipairs(group.items) do
            local file = k:match("^([^#|]+)") or k
            file = vim.trim(file)
            if not seen[file] then
                local path = idx.titles[file:lower()] or idx.aliases[file:lower()]
                table.insert(select_items, (file or "")..(path and (" ("..vim.fn.fnamemodify(path, ":t")..")") or ""))
                seen[file] = true
            end
        end
    end
    vim.ui.select(select_items, {prompt = "Links (选择跳转):"}, function(choice)
        if not choice or choice:match('^%-%-%-') then return end
        local link = choice:match("^([^%s%(]+)")
        if not link then return end
        local path = idx.titles[link:lower()] or idx.aliases[link:lower()]
        if path then vim.cmd("edit "..path) end
    end)
end

function M.pick_link(type)
    local idx = build_index()
    local title = get_title_for_buf()
    local list = (type == 'out') and (idx.outlinks[title] or {}) or (idx.backlinks[title] or {})
    if #list == 0 then vim.notify("No links", vim.log.levels.INFO) return end
    vim.ui.select(list, {prompt = (type=='out' and 'Outlinks' or 'Backlinks')..' jump'}, function(choice)
        if not choice then return end
        local path = idx.titles[choice] or idx.aliases[choice]
        if path then vim.cmd("edit "..path) end
    end)
end

function M.jump_link()
    local cur = vim.api.nvim_get_current_line()
    local col = vim.fn.col('.')
    local left, right
    for i = col, 1, -1 do
        if cur:sub(i, i+1) == '[[ ' or cur:sub(i, i+1) == '[[' then left = i; break end
    end
    for i = col, #cur-1 do
        if cur:sub(i, i+1) == ']]' then right = i+1; break end
    end
    if not right and col > 2 and cur:sub(col-1, col) == ']]' then
        for i = col-2, 1, -1 do
            if cur:sub(i, i+1) == '[[' then left = i; right = col; break end
        end
    end
    if not left or not right then return end
    local link = cur:sub(left+2, right-2)
    link = vim.trim(link)
    if link == '' then return end
    local real_link = link:match("^([^|]+)") or link
    real_link = vim.trim(real_link)
    local filename, heading = real_link:match("^([^#]+)#(.+)$")
    filename = filename or real_link
    local idx = build_index()
    local path = idx.titles[filename:lower()] or idx.aliases[filename:lower()]
    if path then
        vim.cmd("edit "..path)
        if heading then
            -- 严格匹配 heading（不忽略大小写和空格）
            local lines = vim.fn.getbufline(path, 1, '$')
            for i, line in ipairs(lines) do
                if line:match("^#+%s*"..vim.pesc(heading).."%s*$") then
                    vim.api.nvim_win_set_cursor(0, {i, 0})
                    break
                end
            end
        end
    else
        -- 若未找到笔记则创建
        vim.cmd("NeoteCapture "..filename)
    end
end

function M.setup()
    vim.api.nvim_set_keymap('n', 'gf', [[:lua require('neote.links').jump_link()<CR>]], {noremap=true, silent=true})
    vim.api.nvim_create_user_command('NeoteLinks', function() M.show_links() end, {})
end

return M
