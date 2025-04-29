local M = {}

M.config = {
    notes_dir = vim.fn.expand("~/notes"),
    templates_dir = vim.fn.expand("~/notes/templates"),
    assets_dir = vim.fn.expand(vim.fn.stdpath("data").."/neote.nvim/assets"),
    diary = {
        dir = vim.fn.expand("~/notes/diary"),
        templates = {
            daily = "daily.md",
            weekly = "weekly.md",
            monthly = "monthly.md",
        }
    }
}

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    -- 自动创建目录
    for _, dir in ipairs({M.config.notes_dir, M.config.templates_dir, M.config.assets_dir, M.config.diary.dir}) do
        if vim.fn.isdirectory(dir) == 0 then
            vim.fn.mkdir(dir, "p")
        end
    end
    -- 全局可用
    _G.neote = M
    require("neote.telescope").setup()
    require("neote.links").setup()
    require("neote.highlight").setup()
    vim.api.nvim_create_user_command("NeoteCapture", function(opts)
        require("neote.capturenote").create(opts.args)
    end, {nargs = "?"})
    require("neote.graph").setup()
    -- 初始化日记模块
    require("neote.diary").setup()
end

return M