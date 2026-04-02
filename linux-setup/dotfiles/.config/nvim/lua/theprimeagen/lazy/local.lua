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
		end,
	},
}

return local_plugins
