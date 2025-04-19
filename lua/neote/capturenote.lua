local M = {}

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
            prompt = "Select template:"
        }, function(template)
            local content = ""
            if template then
                content = table.concat(vim.fn.readfile(template), "\n")
                content = content:gsub("{{title}}", unique_name)
                content = content:gsub("{{date}}", os.date("%Y-%m-%d"))
            end
            vim.fn.writefile(vim.split(content, "\n"), filename)
            vim.cmd("tabnew "..filename)
        end)
    end
    if filename and filename ~= "" then
        do_create(filename)
    else
        vim.ui.input({prompt = "New note filename: "}, function(input)
            if input and input ~= "" then
                do_create(input)
            end
        end)
    end
end

return M
