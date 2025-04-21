local M = {}

local scan = require("plenary.scandir")
local parser = require("neote.parser")

local function build_graph_data(filter)
    local notes = scan.scan_dir(_G.neote.config.notes_dir, {search_pattern = "%.md$"})
    local nodes, links = {}, {}
    local id_map = {}
    local idx = 1
    -- 先收集所有节点
    for _, path in ipairs(notes) do
        local fm = parser.parse_frontmatter(path)
        local filename = vim.fn.fnamemodify(path, ":t:r")
        local title = fm.title or filename
        local tags = fm.tags or {}
        local type_ = fm.type or ""
        -- 过滤
        if filter then
            if filter.tags then
                local has_tag = false
                for _, t in ipairs(tags) do
                    for _, want in ipairs(filter.tags) do
                        if t == want then has_tag = true end
                    end
                end
                if not has_tag then goto continue end
            end
            if filter.type and filter.type ~= "" and type_ ~= filter.type then
                goto continue
            end
        end
        id_map[title] = idx
        table.insert(nodes, {
            id = idx,
            label = title,
            filename = filename,
            tags = tags,
            type = type_,
        })
        idx = idx + 1
        ::continue::
    end
    -- 收集所有链接
    for _, path in ipairs(notes) do
        local fm = parser.parse_frontmatter(path)
        local filename = vim.fn.fnamemodify(path, ":t:r")
        local title = fm.title or filename
        if not id_map[title] then goto continue end
        local lines = vim.fn.readfile(path)
        for _, line in ipairs(lines) do
            for link in line:gmatch("%[%[([^%[%]]+)%]%]") do
                local link_key = vim.trim((link:match("^([^|]+)") or link))
                if id_map[link_key] then
                    table.insert(links, {source = id_map[title], target = id_map[link_key]})
                end
            end
        end
        ::continue::
    end
    return {nodes = nodes, links = links}
end

local function write_html(graph_data, outfile)
    local json = vim.fn.json_encode(graph_data)
    local html = [[
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<title>Neote Graph</title>
<style>
html,body {margin:0;padding:0;width:100vw;height:100vh;background:#181825;}
#graph {width:100vw;height:100vh;}
.node {
    stroke: #fff;
    stroke-width: 2px;
    cursor: grab;
    filter: drop-shadow(0 2px 8px #0008);
    transition: filter 0.2s, stroke 0.2s;
}
.node:hover {
    stroke: #ffb86c;
    filter: drop-shadow(0 4px 16px #ffb86c88);
}
.link {
    stroke: #888;
    stroke-opacity: 0.5;
    transition: stroke 0.2s;
}
text {
    font-family: 'Segoe UI', 'Arial', sans-serif;
    font-size: 15px;
    fill: #f5f5fa;
    pointer-events: none;
    paint-order: stroke fill;
    stroke: #181825;
    stroke-width: 4px;
    stroke-linejoin: round;
}
#tip {
    position: absolute;
    top: 10px; left: 10px;
    color: #fff; background: #333a; padding: 6px 14px; border-radius: 8px;
    font-size: 14px; z-index: 10;
    box-shadow: 0 2px 8px #0006;
    user-select: none;
}
</style>
</head>
<body>
<div id="tip">🖱️ 拖动节点可重新布局，滚轮缩放，双击节点显示文件名</div>
<div id="graph"></div>
<script src="https://cdn.jsdelivr.net/npm/d3@7"></script>
<script>
const data = ]] .. json .. [[;
const width = window.innerWidth, height = window.innerHeight;
const svg = d3.select("#graph").append("svg")
    .attr("width", width).attr("height", height)
    .call(d3.zoom()
        .scaleExtent([0.2, 4])
        .on("zoom", function(event) {
            g.attr("transform", event.transform);
        })
    );

const g = svg.append("g");

const color = d3.scaleOrdinal()
    .domain(["default"])
    .range(["#8aadf4", "#a6da95", "#f5bde6", "#f5a97f", "#eed49f", "#7dc4e4", "#c6a0f6", "#f6c177", "#e0af68", "#b7bdf8"]);

// 更加紧凑的参数，性能优化：减少 tick 次数，节点半径减小，linkDistance 更短
const NODE_RADIUS = 16;
const COLLISION_RADIUS = 20;
const TICK_LIMIT = 400;

const simulation = d3.forceSimulation(data.nodes)
    .force("link", d3.forceLink(data.links).id(d=>d.id).distance(38).strength(0.32))
    .force("charge", d3.forceManyBody().strength(-80))
    .force("center", d3.forceCenter(width/2, height/2))
    .force("collision", d3.forceCollide().radius(COLLISION_RADIUS))
    .alphaDecay(0.09);

const link = g.append("g")
    .attr("stroke", "#888").attr("stroke-opacity", 0.5)
    .selectAll("line")
    .data(data.links)
    .join("line")
    .attr("stroke-width", 1.3);

const node = g.append("g")
    .selectAll("circle")
    .data(data.nodes)
    .join("circle")
    .attr("r", NODE_RADIUS)
    .attr("fill", d => color(d.type || (d.tags && d.tags[0]) || 'default'))
    .attr("class", "node")
    .call(drag(simulation));

const label = g.append("g")
    .selectAll("text")
    .data(data.nodes)
    .join("text")
    .attr("text-anchor", "middle")
    .attr("dy", ".35em")
    .text(d => d.label);

node.append("title")
    .text(d => d.label + (d.tags && d.tags.length > 0 ? " ["+d.tags.join(",")+"]" : ""));

node.on("dblclick", function(event, d) {
    alert("Note: " + d.filename);
});

// 性能优化：tick 限制
let tickCount = 0;
simulation.on("tick", () => {
    link
        .attr("x1", d => d.source.x)
        .attr("y1", d => d.source.y)
        .attr("x2", d => d.target.x)
        .attr("y2", d => d.target.y);
    node
        .attr("cx", d => d.x)
        .attr("cy", d => d.y);
    label
        .attr("x", d => d.x)
        .attr("y", d => d.y);
    tickCount++;
    if (tickCount > TICK_LIMIT) simulation.stop();
});

function drag(simulation) {
    function dragstarted(event, d) {
        if (!event.active) simulation.alphaTarget(0.04).restart();
        d.fx = d.x; d.fy = d.y;
        d3.select(this).attr("stroke", "#f5a97f");
    }
    function dragged(event, d) {
        d.fx = event.x; d.fy = event.y;
    }
    function dragended(event, d) {
        if (!event.active) simulation.alphaTarget(0);
        d.fx = null; d.fy = null;
        d3.select(this).attr("stroke", "#fff");
    }
    return d3.drag()
        .on("start", dragstarted)
        .on("drag", dragged)
        .on("end", dragended);
}
</script>
</body>
</html>
]]
    local f = io.open(outfile, "w")
    f:write(html)
    f:close()
end

function M.open_graph(opts)
    opts = opts or {}
    local filter = {}
    if opts.tags then
        filter.tags = vim.split(opts.tags, ",")
        for i, t in ipairs(filter.tags) do filter.tags[i] = vim.trim(t) end
    end
    if opts.type then filter.type = opts.type end
    local graph_data = build_graph_data(filter)
    local tmpfile = vim.fn.stdpath("data").."/neote_graph.html"
    write_html(graph_data, tmpfile)
    -- 打开浏览器
    local open_cmd
    if vim.fn.has("mac") == 1 then
        open_cmd = "open"
    elseif vim.fn.has("unix") == 1 then
        open_cmd = "xdg-open"
    elseif vim.fn.has("win32") == 1 then
        open_cmd = "start"
    else
        vim.notify("Cannot detect OS to open browser", vim.log.levels.ERROR)
        return
    end
    vim.fn.jobstart({open_cmd, tmpfile}, {detach=true})
end

function M.setup()
    vim.api.nvim_create_user_command("NeoteGraph", function(opts)
        -- 支持 :NeoteGraph tags=tag1,tag2 type=xxx
        local args = {}
        for _, arg in ipairs(opts.fargs) do
            local k, v = arg:match("^(%w+)%=(.+)$")
            if k and v then args[k] = v end
        end
        M.open_graph(args)
    end, {nargs="*", complete=nil})
end

return M
