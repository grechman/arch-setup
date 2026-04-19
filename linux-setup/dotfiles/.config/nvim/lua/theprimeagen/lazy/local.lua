local local_plugins = {
	--{
	--    "cockpit",
	--    dir = "~/personal/cockpit",
	--    config = function()
	--        require("cockpit")
	--        vim.keymap.set("n", "<leader>ct", "<cmd>CockpitTest<CR>")
	--        vim.keymap.set("n", "<leader>cr", "<cmd>CockpitRefresh<CR>")
	--    end,
	--},

	-- {
	-- 	"the-stru",
	-- 	dir = "~/personal/the-stru",
	-- },

	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		config = function()
			local harpoon = require("harpoon")

			harpoon:setup()

			vim.keymap.set("n", "<leader>A", function()
				harpoon:list():prepend()
			end)
			vim.keymap.set("n", "<leader>a", function()
				harpoon:list():add()
			end)
			vim.keymap.set("n", "<C-e>", function()
				harpoon.ui:toggle_quick_menu(harpoon:list())
			end)

			vim.keymap.set("n", "<M-1>", function()
				harpoon:list():select(1)
			end)
			vim.keymap.set("n", "<M-2>", function()
				harpoon:list():select(2)
			end)
			vim.keymap.set("n", "<M-3>", function()
				harpoon:list():select(3)
			end)
			vim.keymap.set("n", "<M-4>", function()
				harpoon:list():select(4)
			end)

			local function transparent_harpoon()
				local function strip_bg(g)
					local hl = vim.api.nvim_get_hl(0, { name = g, link = false }) or {}
					hl.bg = nil
					hl.ctermbg = nil
					vim.api.nvim_set_hl(0, g, hl)
				end
				for _, g in ipairs({ "NormalFloat", "NormalNC", "FloatBorder", "FloatTitle" }) do
					strip_bg(g)
				end
				vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#403d52", bg = "NONE" })
				vim.api.nvim_set_hl(0, "FloatTitle", { fg = "#6e6a86", bg = "NONE", italic = true })
			end

			local function force_win_transparent(win)
				if not win or win == -1 or not vim.api.nvim_win_is_valid(win) then
					return
				end
				vim.api.nvim_set_option_value(
					"winhighlight",
					"Normal:Normal,NormalNC:Normal,NormalFloat:Normal,FloatBorder:FloatBorder,FloatTitle:FloatTitle,EndOfBuffer:Normal",
					{ win = win }
				)
			end

			local group = vim.api.nvim_create_augroup("HarpoonTransparent", { clear = true })

			transparent_harpoon()

			vim.api.nvim_create_autocmd("ColorScheme", {
				group = group,
				callback = transparent_harpoon,
			})

			vim.api.nvim_create_autocmd("FileType", {
				group = group,
				pattern = "harpoon",
				callback = function(args)
					transparent_harpoon()
					force_win_transparent(vim.fn.bufwinid(args.buf))
				end,
			})
		end,
	},
}

return local_plugins
