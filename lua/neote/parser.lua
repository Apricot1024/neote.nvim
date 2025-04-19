return {
    parse_frontmatter = function(path)
        local content = table.concat(vim.fn.readfile(path), "\n")
        local frontmatter = content:match("^%-%-%-%s*(.-)%s*%-%-%-")
        local result = {}
        if frontmatter then
            for line in frontmatter:gmatch("[^\n]+") do
                local key, value = line:match("^([%w_]+):%s*(.*)$")
                if key and value then
                    value = value:gsub('^%s+', ''):gsub('%s+$', '')
                    if key == "alias" or key == "tags" then
                        local t = {}
                        for v in value:gmatch("[^,%s]+") do
                            table.insert(t, v)
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