local M = {}
local ns = vim.api.nvim_create_namespace("neote_links")

-- 解析一段内容中的所有 [[note#heading]] 链接，返回 {note=..., heading=...} 的表
local function parse_links(content)
    local links = {}
    for link in content:gmatch("%[%[(.-)%]%]") do
        local note, heading = link:match("([^#]+)#?(.*)")
        table.insert(links, {note = note, heading = heading})
    end
    return links
end

-- 构建全局索引：包括所有笔记的 title、alias、正向/反向链接
function M.build_index()
    local scan = require("plenary.scandir")
    local parser = require("neote.parser")
    -- 扫描所有笔记文件
    local notes = scan.scan_dir(_G.neote.config.notes_dir, {search_pattern = "%.md$"})
    -- 索引结构
    local index = {
        titles = {},    -- title:lower() -> path
        aliases = {},   -- alias:lower() -> path
        backlinks = {}, -- note名 -> {被哪些title链接}
        outlinks = {}   -- title -> {本笔记链接到哪些note}
    }
    for _, path in ipairs(notes) do
        local fm = parser.parse_frontmatter(path)
        local title = fm.title or vim.fn.fnamemodify(path, ":t:r")
        -- 标题映射
        index.titles[title:lower()] = path
        -- alias 映射
        if fm.alias then
            local aliases = fm.alias
            if type(aliases) == "string" then aliases = {aliases} end
            for _, a in ipairs(aliases) do
                index.aliases[a:lower()] = path
            end
        end
        -- 解析正向链接
        local content = table.concat(vim.fn.readfile(path), "\n")
        local out = {}
        for _, l in ipairs(parse_links(content)) do
            if l.note and l.note ~= "" then
                table.insert(out, l.note)
                -- 反向链接：被哪些title链接
                index.backlinks[l.note] = index.backlinks[l.note] or {}
                table.insert(index.backlinks[l.note], title)
            end
        end
        -- 本笔记的正向链接
        index.outlinks[title] = out
    end
    return index
end

-- 设置 gf 跳转：在 [[xxx]] 上按 gf 跳转到对应笔记
function M.setup()
    vim.keymap.set("n", "gf", function()
        local line = vim.api.nvim_get_current_line()
        local link = line:match("%[%[(.-)%]%]")
        if link then
            local note = link:match("([^#]+)")
            local idx = M.build_index()
            local path = idx.titles[note:lower()] or idx.aliases[note:lower()]
            if path then vim.cmd("edit "..path) end
        end
    end, { buffer = true })
end

return M