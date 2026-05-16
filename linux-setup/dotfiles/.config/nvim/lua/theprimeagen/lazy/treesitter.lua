return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		lazy = false,
		config = function()
			-- New API: setup() only takes install_dir. Everything else is Neovim-native now.
			require("nvim-treesitter").setup()

			-- Install parsers
			require("nvim-treesitter").install({
				"vimdoc",
				"javascript",
				"typescript",
				"c",
				"lua",
				"rust",
				"jsdoc",
				"bash",
				"go",
				"elixir",
				"heex",
				"markdown",
				"markdown_inline",
			})

			-- Highlighting is now built into Neovim via vim.treesitter.start()
			vim.api.nvim_create_autocmd("FileType", {
				callback = function(args)
					local buf = args.buf
					if vim.bo[buf].buftype ~= "" then
						return
					end
					-- Skip large files
					local max_filesize = 100 * 1024
					local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
					if ok and stats and stats.size > max_filesize then
						vim.notify(
							"File larger than 100KB treesitter disabled for performance",
							vim.log.levels.WARN,
							{ title = "Treesitter" }
						)
						return
					end
					pcall(vim.treesitter.start, buf)
				end,
			})

			vim.treesitter.language.register("templ", "templ")
		end,
	},

	{
		"nvim-treesitter/nvim-treesitter-context",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		config = function()
			require("treesitter-context").setup({
				enable = true,
				multiwindow = false,
				max_lines = 0,
				min_window_height = 0,
				line_numbers = true,
				multiline_threshold = 20,
				trim_scope = "outer",
				mode = "cursor",
				separator = nil,
				zindex = 20,
				on_attach = function(buf)
					return vim.bo[buf].buftype == ""
				end,
			})
		end,
	},
}
