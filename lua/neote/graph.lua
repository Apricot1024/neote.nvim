local M = {}

function M.generate_graph(args)
    local index = require("neote.links").build_index()
    local parser = require("neote.parser")
    local nodes, edges = {}, {}
    for title, path in pairs(index.titles) do
        local fm = parser.parse_frontmatter(path)
        table.insert(nodes, {
            id = title,
            label = fm.title or title,
            tags = fm.tags or {},
            type = fm.type or "",
        })
        for _, to in ipairs(index.outlinks[fm.title or title] or {}) do
            table.insert(edges, {source = title, target = to})
        end
    end
    -- 支持 tag/type 筛选
    if args and args ~= "" then
        local filter = args:lower()
        nodes = vim.tbl_filter(function(n)
            return tostring(n.tags):lower():find(filter) or tostring(n.type):lower():find(filter)
        end, nodes)
        -- 只保留相关边
        local node_ids = {}
        for _, n in ipairs(nodes) do node_ids[n.id] = true end
        edges = vim.tbl_filter(function(e) return node_ids[e.source] and node_ids[e.target] end, edges)
    end
    -- 写入临时 json 文件
    local tmp = vim.fn.tempname()..".json"
    vim.fn.writefile({vim.json.encode({nodes=nodes, links=edges})}, tmp)
    -- 打开本地 html 并传递 json 路径
    vim.fn.jobstart({"xdg-open", _G.neote.config.assets_dir.."/graph.html?data="..tmp}, {detach=true})
end

function M.setup()
    vim.api.nvim_create_user_command("NeoteGraph", function(opts)
        M.generate_graph(opts.args)
    end, {nargs = "?"})
end

return M