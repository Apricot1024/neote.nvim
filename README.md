# Neote.nvim - Neovim Markdown 笔记管理插件 | Neovim Markdown Note Management Plugin

完全出于个人需求，希望有一款简单的 Neovim Markdown 笔记系统管理。笔记系统简单，只需要按模板创建笔记、搜索笔记、链接笔记、有 frontmatter 即可。个人需求驱动开发，仍需开发。

*Purely for personal needs, I wanted a simple markdown note management system in Neovim. The system is simple: just create notes from templates, search notes, link notes, and support frontmatter. Development is driven by personal needs and is still ongoing.*

---

## 反馈 | Feedback

纯个人需求，请假定我不会响应任何请求！

*Purely personal needs, please assume I won't respond to any requests!*

---

## 简介 | Introduction

Neote 是一个为 Neovim 设计的 Markdown 笔记管理插件，支持高效的笔记搜索、双向链接、graph 视图、模板新建、智能补全等功能。

*Neote is a Markdown note management plugin for Neovim. It supports efficient note searching, bidirectional links, graph view, template-based note creation, smart completion, and more.*

---

## 主要特性 | Features

- 通过文件名、frontmatter 的 title/alias/description 搜索和打开笔记  
  *Search and open notes by filename, frontmatter title/alias/description*
- 支持 `[[链接]]` 语法，自动补全和跳转  
  *`[[link]]` syntax with auto-completion and jump*
- 支持 `[[filename#heading|custom name]]` 跳转到指定标题（严格匹配大小写和空格）  
  *Jump to specific heading with `[[filename#heading|custom name]]` (case and space sensitive)*
- Obsidian 风格的双向链接和 Graph 视图  
  *Obsidian-style bidirectional links and graph view*
- 新建笔记时可选择模板，自动避免重名  
  *Create notes from templates, auto-avoid duplicate names*
- 智能高亮未链接内容，辅助知识网络构建  
  *Smart highlight for unlinked content, helping knowledge network building*
- 支持 tags、description、alias 等 frontmatter 字段  
  *Support for tags, description, alias and other frontmatter fields*

---

## 安装 | Installation

建议使用 [lazy.nvim](https://github.com/folke/lazy.nvim) 管理插件：

```lua
return {
	dir = "~/neote.nvim/",
	name = "neote",
	dependencies = {
		"nvim-telescope/telescope.nvim",
		"nvim-lua/plenary.nvim",
		"saghen/blink.cmp",
	},
	event = "VeryLazy",
	opts = {
		notes_dir = "~/neote_note/notes",
		templates_dir = "~/neote_note/templates",
	},
	keys = {
		{ "<leader>nf", "<cmd>NeoteFind<cr>", desc = "Find notes" },
		{ "<leader>nc", "<cmd>NeoteCapture<cr>", desc = "Capture note" },
	},
	config = function(_, opts)
		require("neote").setup(opts)
		vim.keymap.set("i", "[[", function()
			vim.cmd("stopinsert")
			vim.schedule(function()
				vim.cmd("NeoteInsert")
			end)
		end, { noremap = true, desc = "Neote Insert Link" })
	end,
}

```

---

## 快速上手 | Quick Start

1. `:NeoteFind` 搜索/打开笔记，支持模糊匹配 title/alias/description  
   *Use `:NeoteFind` to search/open notes (fuzzy match title/alias/description)*
2. `:NeoteCapture` 新建笔记，支持模板选择  
   *Use `:NeoteCapture` to create notes with template selection*
3. `:NeoteInsert` 插入链接，支持自动补全  
   *Use `:NeoteInsert` to insert links with auto-completion*
4. 在 `[[name]]` 上按 `gf` 跳转到对应笔记  
   *Press `gf` on `[[name]]` to jump to the note*
4. `:NeoteLinks` 查看当前笔记所有出链/入链并跳转  
   *Use `:NeoteLinks` to view all outlinks/inlinks and jump*
5. `:NeoteGraph` 查看笔记网络关系图  
   *Use `:NeoteGraph` to view the note network graph*

---

## 链接语法 | Link Syntax

- `[[filename]]` 跳转到 filename.md  
  *Jump to filename.md*
- `[[filename|custom name]]` 跳转到 filename.md，显示自定义名  
  *Jump to filename.md, display custom name*
- `[[filename#heading|custom name]]` 跳转到 filename.md 的指定 heading（严格匹配大小写和空格）  
  *Jump to a specific heading in filename.md (case and space sensitive)*

---

## Frontmatter 规则 | Frontmatter Rules

每个笔记文件建议包含如下 frontmatter：

```yaml
---
title: "My Note Title"
alias: alias1, alias2, another alias
tags: tag1, tag2
type: note/task
---
```

- `title`：引号内内容整体为标题，允许空格  
  *The quoted string is the full title, spaces allowed*
- `alias`：用英文逗号分隔，逗号之间的空格属于 alias 内容本身，不会分割为多个 alias。例如 `alias: foo, bar baz` 解析为 `{"foo", "bar baz"}`  
  *Comma-separated, spaces between commas are part of the alias, e.g. `alias: foo, bar baz` parses as `{"foo", "bar baz"}`*

---

## 目录结构 | Directory Structure

```
lua/neote/
    capturenote.lua   -- 新建笔记逻辑 | Note creation logic
    graph.lua         -- graph 视图 | Graph view
    highlight.lua     -- 智能高亮 | Smart highlight
    init.lua          -- 插件入口 | Entry point
    links.lua         -- 链接索引与跳转 | Link index & jump
    parser.lua        -- frontmatter 解析 | Frontmatter parser
    telescope.lua     -- 搜索与 UI | Search & UI
    ...
```

---