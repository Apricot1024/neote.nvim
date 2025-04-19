local M = {}
local ns = vim.api.nvim_create_namespace("neote_highlight")

function M.setup()
    vim.api.nvim_create_autocmd({"BufWritePost", "TextChanged", "BufEnter"}, {
        pattern = "*.md",
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local idx = require("neote.links").build_index()
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            for lnum, line in ipairs(lines) do
                vim.api.nvim_buf_clear_namespace(bufnr, ns, lnum-1, lnum)
                for word in line:gmatch("%w[%w%-_]+") do
                    if (idx.titles[word:lower()] or idx.aliases[word:lower()])
                        and not line:find("%[%["..word.."%]%]") then
                        local start_col = line:find(word)
                        if start_col then
                            vim.api.nvim_buf_set_extmark(bufnr, ns, lnum-1, start_col-1, {
                                virt_text = {{"💡 [["..word.."]]", "Comment"}},
                                virt_text_pos = "inline"
                            })
                        end
                    end
                end
            end
        end
    })
end

return M