return {
    "saghen/blink.cmp",
    version = "1.*",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = { "L3MON4D3/LuaSnip" },

    opts = {
        snippets = { preset = "luasnip" },

        keymap = {
            preset = "default",
            ["<C-p>"] = { "select_prev", "fallback" },
            ["<C-n>"] = { "select_next", "fallback" },
            ["<C-y>"] = { "select_and_accept", "fallback" },
            ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        },

        appearance = {
            nerd_font_variant = "mono",
        },

        completion = {
            list = {
                selection = { preselect = false, auto_insert = false },
            },

            menu = {
                border = "rounded",
                winblend = 0,
                winhighlight = "Normal:Normal,NormalNC:Normal,NormalFloat:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
                draw = {
                    columns = {
                        { "kind_icon" },
                        { "label", "label_description", gap = 1 },
                        { "source_name" },
                    },
                    components = {
                        kind_icon = {
                            text = function(ctx) return " " .. ctx.kind_icon .. " " end,
                            highlight = function(ctx) return "BlinkCmpKind" .. ctx.kind end,
                        },
                        source_name = {
                            width = { max = 8 },
                            text = function(ctx)
                                local map = {
                                    LSP = "[LSP]",
                                    Snippets = "[Snip]",
                                    Buffer = "[Buf]",
                                    Path = "[Path]",
                                }
                                return map[ctx.source_name] or ("[" .. ctx.source_name .. "]")
                            end,
                            highlight = "BlinkCmpSource",
                        },
                    },
                },
            },

            documentation = {
                auto_show = true,
                auto_show_delay_ms = 200,
                window = {
                    border = "rounded",
                    winblend = 0,
                    winhighlight = "Normal:Normal,NormalNC:Normal,FloatBorder:FloatBorder,EndOfBuffer:Normal,Search:None",
                },
            },

            ghost_text = { enabled = false },
        },

        sources = {
            default = { "lsp", "snippets", "buffer", "path" },
        },

        signature = {
            enabled = true,
            window = {
                border = "rounded",
                winblend = 0,
                winhighlight = "Normal:Normal,NormalNC:Normal,FloatBorder:FloatBorder,Search:None",
            },
        },

        cmdline = {
            keymap = { preset = "inherit" },
            completion = { menu = { auto_show = true } },
        },

        fuzzy = { implementation = "prefer_rust_with_warning" },
    },

    config = function(_, opts)
        require("blink.cmp").setup(opts)

        local function transparent_blink()
            local function strip_bg(group)
                local hl = vim.api.nvim_get_hl(0, { name = group, link = false }) or {}
                hl.bg = nil
                hl.ctermbg = nil
                vim.api.nvim_set_hl(0, group, hl)
            end

            for _, group in ipairs({
                "NormalFloat",
                "NormalNC",
                "Pmenu",
                "PmenuExtra",
                "PmenuKind",
                "PmenuSbar",
                "BlinkCmpMenu",
                "BlinkCmpDoc",
                "BlinkCmpDocSeparator",
                "BlinkCmpSignatureHelp",
                "BlinkCmpScrollBarThumb",
                "BlinkCmpScrollBarGutter",
                "BlinkCmpKind",
                "BlinkCmpLabel",
                "BlinkCmpLabelMatch",
                "BlinkCmpLabelDetail",
                "BlinkCmpLabelDescription",
                "BlinkCmpLabelDeprecated",
            }) do
                strip_bg(group)
            end

            local ok, types = pcall(require, "blink.cmp.types")
            if ok and types.CompletionItemKind then
                for _, kind in ipairs(types.CompletionItemKind) do
                    strip_bg("BlinkCmpKind" .. kind)
                end
            end

            vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#403d52", bg = "NONE" })

            for _, group in ipairs({
                "BlinkCmpMenuBorder",
                "BlinkCmpDocBorder",
                "BlinkCmpSignatureHelpBorder",
            }) do
                vim.api.nvim_set_hl(0, group, { link = "FloatBorder" })
            end

            vim.api.nvim_set_hl(0, "BlinkCmpMenuSelection", {
                bg = "#403d52",
                bold = true,
            })

            vim.api.nvim_set_hl(0, "BlinkCmpSource", {
                fg = "#6e6a86",
                italic = true,
            })
        end

        local group = vim.api.nvim_create_augroup("BlinkCmpTransparent", { clear = true })

        transparent_blink()
        vim.schedule(transparent_blink)
        vim.defer_fn(transparent_blink, 200)

        vim.api.nvim_create_autocmd("ColorScheme", {
            group = group,
            callback = transparent_blink,
        })

        vim.api.nvim_create_autocmd("User", {
            group = group,
            pattern = "BlinkCmpMenuOpen",
            callback = transparent_blink,
        })
    end,
}
