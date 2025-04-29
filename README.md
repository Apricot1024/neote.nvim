# Neote.nvim - Neovim 笔记管理插件 | Neovim Note Management Plugin

完全出于个人需求，希望有一款简单的 Neovim 的 Markdown 笔记系统管理。笔记系统简单，只需要按模板创建笔记、搜索笔记、链接笔记、有 frontmatter 即可。个人需求驱动开发，仍需开发。

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
- 日记功能，支持创建和管理每日、每周和每月日记  
  *Diary functionality with daily, weekly and monthly entries*

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
	},
	event = "VeryLazy",
	opts = {
		notes_dir = "~/neote_note/notes",
		templates_dir = "~/neote_note/templates",
		diary = {
            dir = "~/neote_note/diary", -- 日记目录
            templates = {
                daily = "daily.md",     -- 每日日记模板
                weekly = "weekly.md",   -- 每周日记模板
                monthly = "monthly.md", -- 每月日记模板
            }
        }
	},
	keys = {
		{ "<leader>nf", "<cmd>NeoteFind<cr>", desc = "Find notes" },
		{ "<leader>nc", "<cmd>NeoteCapture<cr>", desc = "Capture note" },
        { "<leader>nd", "<cmd>NeoteDiary<cr>", desc = "Create diary entry" },
        { "<leader>ndf", "<cmd>NeoteDiaryFind<cr>", desc = "Find diary entries" },
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
5. `:NeoteLinks` 查看当前笔记所有出链/入链并跳转  
   *Use `:NeoteLinks` to view all outlinks/inlinks and jump*
6. `:NeoteGraph` 查看笔记网络关系图  
   *Use `:NeoteGraph` to view the note network graph*
7. `:NeoteDiary` 创建日记，可选择每日/每周/每月  
   *Use `:NeoteDiary` to create diary entries (daily/weekly/monthly)*
8. `:NeoteDiaryFind` 搜索浏览所有日记  
   *Use `:NeoteDiaryFind` to search all diary entries*

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

## 日记功能 | Diary Functionality

日记功能让你可以在单独的目录中创建和管理日记条目。

*The diary functionality allows you to create and manage diary entries in a separate directory.*

### 日记命令 | Diary Commands

- `:NeoteDiary` - 创建日记（会提示选择类型）  
  *Create a diary entry (prompts for type)*
- `:NeoteDiaryDaily` - 创建/打开今日日记  
  *Create/open today's daily diary*
- `:NeoteDiaryWeekly` - 创建/打开本周周报  
  *Create/open this week's report*
- `:NeoteDiaryMonthly` - 创建/打开本月月报  
  *Create/open this month's report*
- `:NeoteDiaryFind` - 搜索所有日记条目  
  *Search all diary entries*
  - 可以使用参数过滤：`:NeoteDiaryFind type=daily`  
    *Can filter by type: `:NeoteDiaryFind type=daily`*

### 日记模板 | Diary Templates

默认情况下，日记功能会查找以下模板文件：

*By default, the diary functionality looks for the following template files:*

- `daily.md` - 每日日记模板  
  *Daily diary template*
- `weekly.md` - 每周日记模板  
  *Weekly diary template*
- `monthly.md` - 每月日记模板  
  *Monthly diary template*

这些模板支持以下变量：

*These templates support the following variables:*

- `{{title}}` - 日记标题  
  *Diary title*
- `{{date}}` - 当前日期（YYYY-MM-DD 格式）  
  *Current date (YYYY-MM-DD format)*
- `{{type}}` - 日记类型（diary-daily/diary-weekly/diary-monthly）  
  *Diary type (diary-daily/diary-weekly/diary-monthly)*
- `{{day}}` - 每日日记特有，日期格式 YYYY-MM-DD  
  *Daily diary specific, date in YYYY-MM-DD format*
- `{{week}}` - 每周日记特有，格式 YYYY-WXX（XX 为周数）  
  *Weekly diary specific, in YYYY-WXX format (XX is week number)*
- `{{month}}` - 每月日记特有，格式 YYYY-MM  
  *Monthly diary specific, in YYYY-MM format*

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