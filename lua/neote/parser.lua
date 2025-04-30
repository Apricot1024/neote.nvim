return {
    parse_frontmatter = function(path)
        -- Check if file exists and is readable
        if not path or vim.fn.filereadable(path) ~= 1 then
            return {}
        end
        
        local status, content = pcall(function()
            return table.concat(vim.fn.readfile(path), "\n")
        end)
        
        if not status or not content then
            return {}
        end
        
        local frontmatter = content:match("^%-%-%-%s*(.-)%s*%-%-%-")
        local result = {}
        if frontmatter then
            for line in frontmatter:gmatch("[^\n]+") do
                local key, value = line:match("^([%w_]+):%s*(.*)$")
                if key and value then
                    value = value:gsub('^%s+', ''):gsub('%s+$', '')
                    if key == "alias" or key == "tags" then
                        local t = {}
                        for v in value:gmatch("([^,]+)") do
                            table.insert(t, vim.trim(v))
                        end
                        result[key] = t
                    else
                        result[key] = value
                    end
                end
            end
        end
        return result
    end
}