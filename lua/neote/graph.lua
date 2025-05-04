local M = {}

local scan = require("plenary.scandir")
local parser = require("neote.parser")

-- 去掉标题中的双引号
local function strip_quotes(title)
    if type(title) == "string" then
        -- 去掉开头和结尾的双引号
        return title:gsub('^%s*"(.-)"%s*$', '%1')
    end
    return title
end

local function build_graph_data(filter)
    local notes = scan.scan_dir(_G.neote.config.notes_dir, {search_pattern = "%.md$"})
    local nodes, links = {}, {}
    local id_map = {}
    local idx = 1
    
    -- 创建索引映射，用于解析链接
    local titles_map = {}
    local aliases_map = {}
    
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
        -- 添加文件名映射
        titles_map[filename:lower()] = title
        -- 添加标题映射（带引号和不带引号版本）
        titles_map[title:lower()] = title
        local stripped_title = strip_quotes(title)
        if stripped_title ~= title then
            titles_map[stripped_title:lower()] = title
        end
        
        -- 添加别名映射
        if fm.alias then
            for _, a in ipairs(fm.alias) do
                aliases_map[a:lower()] = title
                -- 处理别名中的引号
                local stripped_alias = strip_quotes(a)
                if stripped_alias ~= a then
                    aliases_map[stripped_alias:lower()] = title
                end
            end
        end
        
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
                -- 提取链接的实际部分（忽略自定义显示文本）
                local link_key = vim.trim((link:match("^([^|#]+)") or link))
                -- 移除 .md 扩展名（如果有）
                if link_key:sub(-3) == ".md" then
                    link_key = link_key:sub(1, -4)
                end
                
                -- 查找目标笔记的标题
                local target_title = titles_map[link_key:lower()] or 
                                     titles_map[strip_quotes(link_key):lower()] or
                                     aliases_map[link_key:lower()] or
                                     aliases_map[strip_quotes(link_key):lower()]
                
                -- 如果找到目标，并且源和目标都有ID，则添加链接
                if target_title and id_map[target_title] and id_map[title] then
                    table.insert(links, {
                        source = id_map[title],
                        target = id_map[target_title]
                    })
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
    stroke-width: 1.8px;
    stroke-opacity: 0.7;
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
.particle {
    fill: #fff;
    stroke: none;
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
// 阻止浏览器默认的拖拽和文本选择行为
document.addEventListener('dragstart', function(e) { e.preventDefault(); });
document.addEventListener('selectstart', function(e) { 
    if (dragInProgress) e.preventDefault(); 
});

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
const particlesGroup = g.append("g").attr("class", "particles");

const color = d3.scaleOrdinal()
    .domain(["default"])
    .range(["#8aadf4", "#a6da95", "#f5bde6", "#f5a97f", "#eed49f", "#7dc4e4", "#c6a0f6", "#f6c177", "#e0af68", "#b7bdf8"]);

// 优化参数，更紧凑，且减少计算
const NODE_RADIUS = 16;
const COLLISION_RADIUS = NODE_RADIUS * 1.2;
const TICK_LIMIT = 120; // 减少更多初始tick次数
const LINK_DISTANCE = 40;
const LINK_STRENGTH = 0.4;
const CHARGE_STRENGTH = -80;
const CENTER_STRENGTH = 0.1;

// 记录当前布局状态
let dragInProgress = false;
let simulationActive = true;
let initialLayoutComplete = false;

// 优化级别常量
const MAX_NODES_BASIC = 50;      // 超过这个数量开始简化计算
const MAX_NODES_INTERMEDIATE = 100; // 超过这个数量更简化计算
const MAX_NODES_EXTREME = 200;   // 超过这个数量极度简化计算

// 根据节点数量确定优化级别
const optimizationLevel = data.nodes.length > MAX_NODES_EXTREME ? 3 : 
                          data.nodes.length > MAX_NODES_INTERMEDIATE ? 2 :
                          data.nodes.length > MAX_NODES_BASIC ? 1 : 0;

// 初始化节点位置 - 紧凑圆形分布
const nodeCount = data.nodes.length;
const radius = Math.min(width, height) * 0.1;

data.nodes.forEach((node, i) => {
    const angle = (i / nodeCount) * 2 * Math.PI;
    node.x = width / 2 + radius * Math.cos(angle);
    node.y = height / 2 + radius * Math.sin(angle);
});

// 连接线容器
const linkContainer = g.append("g");

// 创建连接线
const link = linkContainer
    .selectAll("line")
    .data(data.links)
    .join("line")
    .attr("stroke", "#888")
    .attr("stroke-opacity", 0.7)
    .attr("stroke-width", 1.8);

// 创建节点容器
const nodeContainer = g.append("g");

// 创建节点
const node = nodeContainer
    .selectAll("circle")
    .data(data.nodes)
    .join("circle")
    .attr("r", NODE_RADIUS)
    .attr("fill", d => color(d.type || (d.tags && d.tags[0]) || 'default'))
    .attr("class", "node")
    .attr("cx", d => d.x)
    .attr("cy", d => d.y)
    .style("cursor", "grab");

// 创建标签容器
const labelContainer = g.append("g");

// 创建文本标签
const label = labelContainer
    .selectAll("text")
    .data(data.nodes)
    .join("text")
    .attr("text-anchor", "middle")
    .attr("dy", ".35em")
    .attr("x", d => d.x)
    .attr("y", d => d.y)
    .text(d => d.label);

// 悬停提示
node.append("title")
    .text(d => d.label + (d.tags && d.tags.length > 0 ? " ["+d.tags.join(",")+"]" : ""));

// 双击事件
node.on("dblclick", function(event, d) {
    alert("Note: " + d.filename);
});

// 拖动节点记录
const draggedNodes = new Set();

// 记录所有节点位置的备份，用于性能优化
const nodePositions = new Map();
data.nodes.forEach(node => {
    nodePositions.set(node.id, { x: node.x, y: node.y });
});

// 粒子动画部分
let particles = [];
let particlesActive = false;
let lastAnimationTime = 0;
const ANIMATION_INTERVAL = optimizationLevel > 1 ? 50 : 30;

// 设置粒子
function setupParticles() {
    if (particlesActive) return; // 避免重复初始化

    particles = [];
    const maxParticlesPerLink = optimizationLevel > 1 ? 1 : 2;
    
    data.links.forEach((link, i) => {
        // 对于大型图谱，随机选择只有部分链接有粒子
        if (optimizationLevel > 2 && Math.random() > 0.4) return;
        if (optimizationLevel > 1 && Math.random() > 0.7) return;
        
        const particleCount = 1 + Math.floor(Math.random() * (maxParticlesPerLink - 0.1));
        for (let j = 0; j < particleCount; j++) {
            particles.push({
                linkIndex: i,
                position: Math.random(),
                speed: 0.003 + Math.random() * 0.003,
                size: 2.5 + Math.random() * 1.5,
                brightness: 0.6 + Math.random() * 0.4
            });
        }
    });
    
    // 创建粒子元素
    particlesGroup.selectAll("circle")
        .data(particles)
        .join("circle")
        .attr("r", d => d.size)
        .attr("class", "particle")
        .attr("opacity", d => d.brightness);
    
    particlesActive = true;
    requestAnimationFrame(updateParticles);
}

// 更新粒子动画，使用防抖控制更新频率
function updateParticles(timestamp) {
    if (!particlesActive) return;
    
    // 如果正在拖动，不更新粒子，节省性能
    if (dragInProgress && optimizationLevel > 0) {
        requestAnimationFrame(updateParticles);
        return;
    }
    
    // 控制更新频率
    if (timestamp - lastAnimationTime < ANIMATION_INTERVAL) {
        requestAnimationFrame(updateParticles);
        return;
    }
    lastAnimationTime = timestamp;
    
    // 更新粒子位置
    particles.forEach(p => {
        p.position = (p.position + p.speed) % 1;
    });
    
    // 更新粒子DOM
    particlesGroup.selectAll("circle")
        .data(particles)
        .attr("cx", d => {
            const l = data.links[d.linkIndex];
            if (!l || !l.source || !l.target || !l.source.x || !l.target.x) return 0;
            return l.source.x + (l.target.x - l.source.x) * d.position;
        })
        .attr("cy", d => {
            const l = data.links[d.linkIndex];
            if (!l || !l.source || !l.target || !l.source.y || !l.target.y) return 0;
            return l.source.y + (l.target.y - l.source.y) * d.position;
        });
    
    requestAnimationFrame(updateParticles);
}

// 拖动相关的性能优化
let usingForceSimulation = true;
let forceSimulation = null;

// 创建和配置力模拟
function createForceSimulation() {
    // 如果已停止的模拟，不再使用
    if (!usingForceSimulation) return null;
    
    // 创建新模拟
    const sim = d3.forceSimulation(data.nodes)
        .force("link", d3.forceLink(data.links)
            .id(d => d.id)
            .distance(LINK_DISTANCE)
            .strength(LINK_STRENGTH))
        .force("charge", d3.forceManyBody()
            .strength(CHARGE_STRENGTH)
            .distanceMax(optimizationLevel > 1 ? 150 : 300))
        .force("center", d3.forceCenter(width / 2, height / 2)
            .strength(CENTER_STRENGTH))
        .force("collision", d3.forceCollide()
            .radius(COLLISION_RADIUS)
            .strength(optimizationLevel > 1 ? 0.2 : 0.65))
        .alphaDecay(optimizationLevel > 1 ? 0.04 : 0.02)
        .velocityDecay(optimizationLevel > 1 ? 0.6 : 0.4)
        .on("tick", onSimulationTick)
        .on("end", () => {
            initialLayoutComplete = true;
            simulationActive = false;
            
            // 备份节点位置
            data.nodes.forEach(node => {
                nodePositions.set(node.id, { x: node.x, y: node.y });
            });
            
            // 启动粒子动画
            setupParticles();
        });
    
    return sim;
}

// 自定义的直接拖动处理器
function directDragHandler() {
    let startX, startY;
    let draggedNode = null;
    
    // 拖动开始
    function directDragStart(event, d) {
        event.stopPropagation();
        
        // 记录初始位置和被拖动节点
        startX = event.x;
        startY = event.y;
        draggedNode = d;
        
        // 设置拖动状态
        dragInProgress = true;
        draggedNodes.add(d.id);
        
        // 停止粒子动画，提高性能
        if (optimizationLevel > 0) {
            particlesActive = false;
        }
        
        // 可视反馈
        d3.select(this)
            .attr("stroke", "#f5a97f")
            .style("cursor", "grabbing");
    }
    
    // 拖动进行中
    function directDragMove(event, d) {
        if (!draggedNode) return;
        
        // 计算移动距离 - 直接使用鼠标位置
        const dx = event.x - startX;
        const dy = event.y - startY;
        startX = event.x;
        startY = event.y;
        
        // 限制边界
        d.x = Math.max(NODE_RADIUS, Math.min(width - NODE_RADIUS, d.x + dx));
        d.y = Math.max(NODE_RADIUS, Math.min(height - NODE_RADIUS, d.y + dy));
        
        // 同时更新 fx/fy (修复结束后仍能随动)
        d.fx = d.x;
        d.fy = d.y;
        
        // 直接更新拖动节点位置（不使用fx/fy，避免力模拟计算）
        d3.select(this)
            .attr("cx", d.x)
            .attr("cy", d.y);
            
        // 更新相关文本标签
        labelContainer.selectAll("text")
            .filter(n => n.id === d.id)
            .attr("x", d.x)
            .attr("y", d.y);
        
        // 更新相关连线
        linkContainer.selectAll("line")
            .filter(l => l.source.id === d.id || l.target.id === d.id)
            .attr("x1", l => l.source.id === d.id ? d.x : l.source.x)
            .attr("y1", l => l.source.id === d.id ? d.y : l.source.y)
            .attr("x2", l => l.target.id === d.id ? d.x : l.target.x)
            .attr("y2", l => l.target.id === d.id ? d.y : l.target.y);
        
        // 备份新位置
        nodePositions.set(d.id, { x: d.x, y: d.y });
    }
    
    // 拖动结束
    function directDragEnd(event, d) {
        // 清除固定位置，允许节点重新随动 (关键修复)
        d.fx = null;
        d.fy = null;
        
        draggedNode = null;
        draggedNodes.delete(d.id);
        
        // 如果没有节点被拖动，解除拖动状态
        if (draggedNodes.size === 0) {
            dragInProgress = false;
            
            // 如果这是个大图谱且模拟已暂停，重新启动一小段时间的模拟以让节点重新调整
            if (optimizationLevel > 1 && !simulationActive && forceSimulation) {
                simulationActive = true;
                forceSimulation.alpha(0.3).restart();
                
                // 稍微运行一会儿，然后停止
                setTimeout(() => {
                    forceSimulation.alphaTarget(0);
                }, 2000);
            }
            
            // 重启粒子动画
            if (!particlesActive && initialLayoutComplete) {
                particlesActive = true;
                requestAnimationFrame(updateParticles);
            }
        }
        
        // 还原节点样式
        d3.select(this)
            .attr("stroke", "#fff")
            .style("cursor", "grab");
    }
    
    return d3.drag()
        .on("start", directDragStart)
        .on("drag", directDragMove)
        .on("end", directDragEnd);
}

// 模拟步进
function onSimulationTick() {
    // 如果正在拖动，且是大型图谱，则跳过更新
    if (dragInProgress && optimizationLevel > 0) return;
    
    // 限制节点位置
    data.nodes.forEach(d => {
        d.x = Math.max(NODE_RADIUS, Math.min(width - NODE_RADIUS, d.x));
        d.y = Math.max(NODE_RADIUS, Math.min(height - NODE_RADIUS, d.y));
    });
    
    // 更新所有视觉元素
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
    
    // 备份节点位置
    data.nodes.forEach(node => {
        nodePositions.set(node.id, { x: node.x, y: node.y });
    });
}

// 选择拖动实现方式
if (optimizationLevel > 1) {
    // 大图谱使用直接拖动而不是力模拟驱动拖动
    node.call(directDragHandler());
    
    // 初始布局完成后，放弃力模拟
    forceSimulation = createForceSimulation();
    
    // 设置模拟重启的点击处理
    svg.on("dblclick.sim", function(event) {
        if (event.target === this && !simulationActive) {
            // 重置布局
            if (forceSimulation) {
                forceSimulation.alpha(1).restart();
                simulationActive = true;
            } else {
                forceSimulation = createForceSimulation();
                if (forceSimulation) {
                    simulationActive = true;
                }
            }
        }
    });
} else {
    // 小图谱使用正常的D3力模拟拖动
    forceSimulation = createForceSimulation();
    
    // 正常D3拖动 - 适用于小型图谱
    node.call(d3.drag()
        .on("start", function(event, d) {
            dragInProgress = true;
            draggedNodes.add(d.id);
            
            if (!event.active && forceSimulation) {
                if (!simulationActive) {
                    forceSimulation.alpha(0.3).restart();
                    simulationActive = true;
                } else {
                    forceSimulation.alphaTarget(0.1);
                }
            }
            
            // 固定被拖动节点位置
            d.fx = d.x;
            d.fy = d.y;
            
            d3.select(this)
                .attr("stroke", "#f5a97f")
                .style("cursor", "grabbing");
        })
        .on("drag", function(event, d) {
            // 直接使用event的位置
            d.fx = Math.max(NODE_RADIUS, Math.min(width - NODE_RADIUS, event.x));
            d.fy = Math.max(NODE_RADIUS, Math.min(height - NODE_RADIUS, event.y));
        })
        .on("end", function(event, d) {
            // 释放节点，允许随动，关键修复
            if (optimizationLevel < 2) {
                // 对于小型图谱，完全释放节点
                d.fx = null;
                d.fy = null;
            } else {
                // 对于大型图谱，延迟释放
                setTimeout(() => {
                    d.fx = null;
                    d.fy = null;
                }, 1000);
            }
            
            draggedNodes.delete(d.id);
            
            if (draggedNodes.size === 0) {
                dragInProgress = false;
                
                if (forceSimulation) {
                    // 设置一个短暂的冷却时间
                    setTimeout(() => {
                        forceSimulation.alphaTarget(0);
                    }, 1500);
                }
            }
            
            // 保持固定位置
            d3.select(this)
                .attr("stroke", "#fff")
                .style("cursor", "grab");
        })
    );
}

// 添加双击背景重置所有节点随动功能
svg.on("dblclick.reset", function(event) {
    // 只有当点击在背景上时才响应
    if (event.target === svg.node() || event.target === g.node()) {
        // 释放所有节点
        data.nodes.forEach(node => {
            node.fx = null;
            node.fy = null;
        });
        
        // 重启模拟
        if (forceSimulation) {
            simulationActive = true;
            forceSimulation.alpha(0.5).restart();
            setTimeout(() => forceSimulation.alphaTarget(0), 3000);
        }
    }
});
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
