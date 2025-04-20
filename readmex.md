# Neote.nvim - Neovim Markdown 笔记管理插件 | Neovim Markdown Note Management Plugin

完全出于个人需求，希望有一款简单的neovim中markdown笔记系统管理。笔记系统简单，只需要按模板创建笔记、搜索笔记、链接笔记、有frontmatter即可。个人需求驱动开发，仍需开发。

Purely for personal needs, I wanted a simple markdown note management system in Neovim. The system is simple: just create notes from templates, search notes, link notes, and support frontmatter. Development is driven by personal needs and is still ongoing.

## 简介 | Introduction

Neote 是一个为 Neovim 设计的 Markdown 笔记管理插件，支持高效的笔记搜索、双向链接、graph 视图、模板新建、智能补全等功能。

Neote is a Markdown note management plugin for Neovim. It supports efficient note searching, bidirectional links, graph view, template-based note creation, smart completion, and more.

---

## 主要特性 | Features

- 通过文件名、frontmatter 的 title/alias/description 搜索和打开笔记  
  Search and open notes by filename, frontmatter title/alias/description
- 支持 `[[链接]]` 语法，自动补全和跳转  
  `[[link]]` syntax with auto-completion and jump
- 支持 `[[filename#heading|custom name]]` 跳转到指定标题（严格匹配大小写和空格）
- Obsidian 风格的双向链接和 Graph 视图  
  Obsidian-style bidirectional links and graph view
- 新建笔记时可选择模板，自动避免重名  
  Create notes from templates, auto-avoid duplicate names
- 智能高亮未链接内容，辅助知识网络构建  
  Smart highlight for unlinked content, helping knowledge network building

---

## 安装 | Installation

建议使用 [lazy.nvim](https://github.com/folke/lazy.nvim) 管理插件：

```lua
{
    dir = "/your/path/to/neote.nvim",
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
5. `:NeoteLinks` 查看当前笔记所有出链/入链并跳转  
   Use `:NeoteLinks` to view all outlinks/inlinks and jump
6. `:NeoteGraph` 查看笔记网络关系图  
   Use `:NeoteGraph` to view the note network graph

---

## 链接语法 | Link Syntax

- `[[filename]]` 跳转到 filename.md
- `[[filename|custom name]]` 跳转到 filename.md，显示自定义名
- `[[filename#heading|custom name]]` 跳转到 filename.md 的指定 heading（严格匹配大小写和空格）

---

## Frontmatter 规则 | Frontmatter Rules

每个笔记文件建议包含如下 frontmatter：

```yaml
---
title: "My Note Title"
alias: alias1, alias2, another alias
tags: tag1, tag2
description: 简要描述
---
```

- `title`：引号内内容整体为标题，允许空格
- `alias`：用英文逗号分隔，逗号之间的空格属于 alias 内容本身，不会分割为多个 alias。例如 `alias: foo, bar baz` 解析为 `{"foo", "bar baz"}`

---

## 主要命令 | Main Commands

- `:NeoteFind` 搜索并打开笔记
- `:NeoteCapture [name]` 新建笔记
- `:NeoteLinks` 查看当前笔记所有出链/入链并跳转
- `:NeoteGraph` 打开笔记网络关系图
- 在 `[[link]]` 上按 `gf` 跳转（支持 `#heading`）

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

纯个人需求，请假定我不会相应任何请求！

Purely personal needs, please assume I won't respond to any requests!