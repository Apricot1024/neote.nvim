local M = {}

-- 创建居中的浮动窗口
local function create_centered_floating_input(opts, on_confirm)
    -- 计算窗口尺寸和位置
    local width = math.max(40, opts.prompt and #opts.prompt + 10 or 40)
    local height = 1
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    
    -- 创建缓冲区和窗口
    local bufnr = vim.api.nvim_create_buf(false, true)
    
    -- 设置窗口选项
    local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = opts.prompt or "Input",
        title_pos = "center",
    }
    
    local winid = vim.api.nvim_open_win(bufnr, true, win_opts)
    
    -- 设置缓冲区选项
    vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    
    -- 设置初始内容
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {opts.default or ""})
    
    -- 设置映射
    local map_opts = { noremap = true, silent = true }
    
    -- 确认输入
    vim.api.nvim_buf_set_keymap(bufnr, "i", "<CR>", "", {
        noremap = true,
        silent = true,
        callback = function()
            local text = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
            vim.api.nvim_win_close(winid, true)
            if on_confirm then
                on_confirm(text)
            end
        end
    })
    
    -- 取消输入
    vim.api.nvim_buf_set_keymap(bufnr, "i", "<Esc>", "", {
        noremap = true,
        silent = true,
        callback = function()
            vim.api.nvim_win_close(winid, true)
            if on_confirm then
                on_confirm(nil)
            end
        end
    })
    
    vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "", {
        noremap = true,
        silent = true,
        callback = function()
            vim.api.nvim_win_close(winid, true)
            if on_confirm then
                on_confirm(nil)
            end
        end
    })
    
    -- 进入插入模式
    vim.cmd("startinsert")
end

-- 导出函数，使其他模块可访问
M.create_centered_floating_input = create_centered_floating_input

function M.create(filename)
    local notes_dir = _G.neote.config.notes_dir
    local function get_unique_filename(base)
        local name = base
        local filename = notes_dir.."/"..name..".md"
        local i = 1
        while vim.fn.filereadable(filename) == 1 do
            name = base .. "_" .. i
            filename = notes_dir.."/"..name..".md"
            i = i + 1
        end
        return name, filename
    end
    local function do_create(name)
        local unique_name, filename = get_unique_filename(name)
        vim.ui.select(vim.fn.glob(_G.neote.config.templates_dir.."/*.md", true, true), {
            prompt = "Select template: (q to cancel, <Enter> for empty)"
        }, function(template)
            if template == nil or template == "q" then
                return -- 用户输入q，放弃新建
            end
            local content = ""
            if template and template ~= "" then
                content = table.concat(vim.fn.readfile(template), "\n")
                content = content:gsub("{{title}}", unique_name)
                content = content:gsub("{{date}}", os.date("%Y-%m-%d"))
            end
            vim.fn.writefile(vim.split(content, "\n"), filename)
            vim.cmd("edit "..filename)
        end)
    end
    if filename and filename ~= "" then
        if filename == "q" then return end -- 用户输入q放弃
        do_create(filename)
    else
        -- 替换原来的 vim.ui.input 为居中的输入窗口
        create_centered_floating_input({
            prompt = "New note filename: (q to cancel)"
        }, function(input)
            if not input or input == "" or input == "q" then
                return -- 用户取消或输入q，放弃新建
            end
            do_create(input)
        end)
    end
end

return M
