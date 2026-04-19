return {
    "nvim-telescope/telescope.nvim",

    tag = "0.2.0",

    dependencies = {
        "nvim-lua/plenary.nvim",
    },

    config = function()
        local telescope = require("telescope")

        telescope.setup({
            defaults = {
                winblend = 0,
                border = true,
                borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
            },
        })

        local builtin = require("telescope.builtin")
        vim.keymap.set("n", "<leader>pf", builtin.find_files, {})
        vim.keymap.set("n", "<C-p>", builtin.git_files, {})
        vim.keymap.set("n", "<leader>pws", function()
            local word = vim.fn.expand("<cword>")
            builtin.grep_string({ search = word })
        end)
        vim.keymap.set("n", "<leader>pWs", function()
            local word = vim.fn.expand("<cWORD>")
            builtin.grep_string({ search = word })
        end)
        vim.keymap.set("n", "<leader>ps", function()
            builtin.grep_string({ search = vim.fn.input("Grep > ") })
        end)
        vim.keymap.set("n", "<leader>vh", builtin.help_tags, {})

        local function transparent_telescope()
            local function strip_bg(group)
                local hl = vim.api.nvim_get_hl(0, { name = group, link = false }) or {}
                hl.bg = nil
                hl.ctermbg = nil
                vim.api.nvim_set_hl(0, group, hl)
            end

            for _, group in ipairs({
                "NormalFloat",
                "NormalNC",
                "TelescopeNormal",
                "TelescopePromptNormal",
                "TelescopeResultsNormal",
                "TelescopePreviewNormal",
                "TelescopePromptCounter",
                "TelescopePromptPrefix",
                "TelescopeMatching",
                "TelescopeSelectionCaret",
            }) do
                strip_bg(group)
            end

            for _, group in ipairs({
                "TelescopeBorder",
                "TelescopePromptBorder",
                "TelescopeResultsBorder",
                "TelescopePreviewBorder",
                "TelescopeTitle",
                "TelescopePromptTitle",
                "TelescopeResultsTitle",
                "TelescopePreviewTitle",
            }) do
                vim.api.nvim_set_hl(0, group, { fg = "#6e6a86", bg = "NONE" })
            end

            vim.api.nvim_set_hl(0, "TelescopeSelection", {
                bg = "#403d52",
                bold = true,
            })

            vim.api.nvim_set_hl(0, "TelescopeMatching", {
                fg = "#ebbcba",
                bold = true,
            })
        end

        local group = vim.api.nvim_create_augroup("TelescopeTransparent", { clear = true })

        transparent_telescope()
        vim.schedule(transparent_telescope)

        vim.api.nvim_create_autocmd("ColorScheme", {
            group = group,
            callback = transparent_telescope,
        })

        vim.api.nvim_create_autocmd("User", {
            group = group,
            pattern = "TelescopeFindPre",
            callback = transparent_telescope,
        })

        local function force_win_transparent(win)
            if not win or win == -1 or not vim.api.nvim_win_is_valid(win) then return end
            vim.api.nvim_set_option_value(
                "winhighlight",
                "Normal:Normal,NormalNC:Normal,NormalFloat:Normal,FloatBorder:FloatBorder,EndOfBuffer:Normal",
                { win = win }
            )
        end

        vim.api.nvim_create_autocmd("FileType", {
            group = group,
            pattern = { "TelescopePrompt", "TelescopeResults" },
            callback = function(args)
                transparent_telescope()
                force_win_transparent(vim.fn.bufwinid(args.buf))
            end,
        })

        vim.api.nvim_create_autocmd("User", {
            group = group,
            pattern = "TelescopePreviewerLoaded",
            callback = function()
                transparent_telescope()
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                    local cfg = vim.api.nvim_win_get_config(win)
                    if cfg.relative ~= "" then
                        force_win_transparent(win)
                    end
                end
            end,
        })
    end,
}
