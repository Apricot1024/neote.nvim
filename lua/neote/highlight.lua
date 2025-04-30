-- 智能高亮未链接内容的模块
local M = {}

local ns = vim.api.nvim_create_namespace("neote_highlight")

-- 规范化文本：将短横线、下划线和空格统一处理为空格，便于匹配
local function normalize_text(text)
    return text:gsub("[-_]", " ")
end

-- 去掉标题中的双引号
local function strip_quotes(title)
    if type(title) == "string" then
        -- 去掉开头和结尾的双引号
        return title:gsub('^%s*"(.-)"%s*$', '%1')
    end
    return title
end

-- 判断某个区间是否在 [[...]] 内
local function is_in_bracket(line, s, e)
    local left = nil
    local i = s
    while i > 1 do
        if line:sub(i-1, i) == '[[' then left = i-1; break end
        i = i - 1
    end
    local right = nil
    i = e
    while i < #line do
        if line:sub(i+1, i+2) == ']]' then right = i+2; break end
        i = i + 1
    end
    if left and right and left < s and right > e then
        return true
    end
    return false
end

function M.setup()
    vim.api.nvim_create_autocmd({"BufWritePost", "TextChanged", "BufEnter"}, {
        pattern = "*.md",
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local path = vim.api.nvim_buf_get_name(bufnr)
            
            -- Skip processing if file doesn't exist or isn't readable
            if not path or path == "" or vim.fn.filereadable(path) ~= 1 then
                return
            end
            
            -- Protection against errors during index building
            local idx
            local status, result = pcall(function()
                return require("neote.links").build_index()
            end)
            if not status then
                return
            end
            idx = result
            
            local fm = require("neote.parser").parse_frontmatter(path)
            local filename = vim.fn.fnamemodify(path, ":t:r")
            -- 当前笔记的所有key（文件名、title、alias），全部小写
            local skip_keys = {}
            skip_keys[filename:lower()] = true
            -- 确保去掉title中的引号
            if fm.title then 
                local clean_title = strip_quotes(fm.title)
                skip_keys[clean_title:lower()] = true 
            end
            if fm.alias then
                for _, a in ipairs(fm.alias) do
                    skip_keys[a:lower()] = true
                end
            end
            -- 合并所有 title/alias，避免重复
            local keys = {}
            -- 处理所有标题，确保去掉引号
            for k, _ in pairs(idx.titles) do
                local clean_key = strip_quotes(k)
                if not skip_keys[clean_key:lower()] then 
                    keys[clean_key] = true 
                end
            end
            for k, _ in pairs(idx.aliases) do
                if not skip_keys[k] then keys[k] = true end
            end
            
            -- Get buffer lines safely
            local lines
            status, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, 0, -1, false)
            if not status or not lines then
                return
            end
            
            -- 跳过 frontmatter 区域
            local fm_start, fm_end = nil, nil
            for i, line in ipairs(lines) do
                if not fm_start and line:match("^%-%-%-") then
                    fm_start = i
                elseif fm_start and not fm_end and line:match("^%-%-%-") then
                    fm_end = i
                    break
                end
            end
            
            for lnum, line in ipairs(lines) do
                -- 跳过 frontmatter 区域
                if fm_start and fm_end and lnum >= fm_start and lnum <= fm_end then
                    vim.api.nvim_buf_clear_namespace(bufnr, ns, lnum-1, lnum)
                    goto continue
                end
                vim.api.nvim_buf_clear_namespace(bufnr, ns, lnum-1, lnum)
                local lower_line = line:lower()
                local normalized_line = normalize_text(lower_line)
                
                for key, _ in pairs(keys) do
                    if key ~= "" then
                        local search_start = 1
                        local lower_key = key:lower()
                        local normalized_key = normalize_text(lower_key)
                        
                        while true do
                            -- 使用规范化后的文本进行匹配
                            local s, e = normalized_line:find(normalized_key, search_start, true)
                            if not s then break end
                            
                            -- 判断原始文本中的等效位置是否已经在 [[...]] 中
                            if not is_in_bracket(line, s, e) then
                                pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, lnum-1, s-1, {
                                    virt_text = {{"💡 [["..key.."]]", "Comment"}},
                                    virt_text_pos = "inline"
                                })
                            end
                            search_start = e + 1
                        end
                    end
                end
                ::continue::
            end
        end
    })
end

return M