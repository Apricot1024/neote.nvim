# Neote - Neovim Markdown 笔记管理插件 | Neovim Markdown Note Management Plugin

完全出于个人需求，希望有一款简单的neovim中markdown笔记系统管理。笔记系统简单，只需要按模板创建笔记、搜索笔记、链接笔记、有frontmatter即可。个人需求驱动开发，仍需开发。

Purely for personal needs, I wanted a simple markdown note management system in Neovim. The system is simple: just create notes from templates, search notes, link notes, and support frontmatter. Development is driven by personal needs and is still ongoing.

## 简介 | Introduction

Neote 是一个为 Neovim 设计的 Markdown 笔记管理插件，支持高效的笔记搜索、双向链接、graph 视图、模板新建、智能补全等功能。

Neote is a Markdown note management plugin for Neovim. It supports efficient note searching, bidirectional links, graph view, template-based note creation, smart completion, and more.

---

## 主要特性 | Features

- 通过文件名、frontmatter 的 title/alias/description 搜索和打开笔记  
  Search and open notes by filename, frontmatter title/alias/description
- 支持 [[链接]] 语法，（可能）自动补全和跳转  
  [[link]] syntax with (maybe) auto-completion and jump
- （可能）支持 Obsidian 风格的双向链接和 graph 视图（可按 tag/type 筛选）  
  (Maybe) Obsidian-style bidirectional links and graph view (filterable by tag/type)
- 新建笔记时可选择模板，自动避免重名  
  Create notes from templates, auto-avoid duplicate names
- 智能高亮未链接内容，辅助知识网络构建  
  Smart highlight for unlinked content, helping knowledge network building

---

## 正在调整 | In Progress
**这些特性尚不可完全使用。**

**These features are not yet fully available.**
- 链接跳转bug  
  Link jump bug
- 链接补全  
  Link completion
- 新建模板  
  New template

---

## 安装 | Installation

建议使用 [lazy.nvim](https://github.com/folke/lazy.nvim)管理插件：  
It is recommended to use [lazy.nvim](https://github.com/folke/lazy.nvim) to manage plugins:

**lazy.nvim 配置示例 | Example for lazy.nvim:**

```lua
{
    dir = "/your/path/to/neote", -- 本地开发路径 | Local development path
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
        "nvim-telescope/telescope-fzf-native.nvim",
    },
    config = function()
        require("neote").setup({
            notes_dir = "~/Documents/neote_notes",
            templates_dir = "~/Documents/neote_notes/templates",
        })
    end,
}
```

---

## 快速上手 | Quick Start

1. `:NeoteFind` 搜索/打开笔记，支持模糊匹配 title/alias/description  
   Use `:NeoteFind` to search/open notes (fuzzy match title/alias/description)
2. `:NeoteCapture` 或 `<leader>nn` 新建笔记，支持模板选择  
   Use `:NeoteCapture` or `<leader>nn` to create notes with template selection
3. 在 markdown 文件中输入 `[[` 可补全现有笔记名、title、alias  
   In markdown, type `[[` to auto-complete note name/title/alias
4. 在 `[[name]]` 上按 `gf` 跳转到对应笔记  
   Press `gf` on `[[name]]` to jump to the note
5. `:NeoteGraph` 查看笔记网络关系图  
   Use `:NeoteGraph` to view the note network graph

---

## 目录结构 | Directory Structure

```
lua/neote/
    capturenote.lua   -- 新建笔记逻辑 | Note creation logic
    completion.lua    -- 补全与 bracket 替换 | Completion & bracket replace
    graph.lua         -- graph 视图 | Graph view
    highlight.lua     -- 智能高亮 | Smart highlight
    init.lua          -- 插件入口 | Entry point
    links.lua         -- 链接索引与跳转 | Link index & jump
    parser.lua        -- frontmatter 解析 | Frontmatter parser
    telescope.lua     -- 搜索与 UI | Search & UI
    ...
templates/
    default.md        -- 默认模板 | Default template
```

---

## 贡献与反馈 | Contribution & Feedback

欢迎 issue、PR 或建议！  
Feel free to open issues, pull requests, or suggestions!

<!-- ---

## License

MIT -->
