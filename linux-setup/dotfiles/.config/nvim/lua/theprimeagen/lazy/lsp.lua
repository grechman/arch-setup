return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "stevearc/conform.nvim",
        "mason-org/mason.nvim",
        "mason-org/mason-lspconfig.nvim",
        "saghen/blink.cmp",
        "j-hui/fidget.nvim",
    },

    config = function()
        require("conform").setup({
            formatters_by_ft = {},
        })

        require("fidget").setup({
            notification = {
                window = {
                    winblend = 0,
                    normal_hl = "Normal",
                    border = "none",
                },
            },
        })
        require("mason").setup()
        require("mason-lspconfig").setup({
            ensure_installed = {
                "lua_ls",
                "rust_analyzer",
                "gopls",
                "vtsls",
                "tailwindcss",
                "clangd",
                "pyright",
                "ruff",
            },
        })

        vim.lsp.config("*", {
            capabilities = require("blink.cmp").get_lsp_capabilities(),
        })

        vim.lsp.config("lua_ls", {
            settings = {
                Lua = {
                    runtime = { version = "LuaJIT" },
                    diagnostics = { globals = { "vim" } },
                    workspace = {
                        library = vim.api.nvim_get_runtime_file("", true),
                        checkThirdParty = false,
                    },
                    format = {
                        enable = true,
                        defaultConfig = {
                            indent_style = "space",
                            indent_size = "2",
                        },
                    },
                },
            },
        })

        vim.lsp.config("zls", {
            root_markers = { ".git", "build.zig", "zls.json" },
            settings = {
                zls = {
                    enable_inlay_hints = true,
                    enable_snippets = true,
                    warn_style = true,
                },
            },
        })
        vim.g.zig_fmt_parse_errors = 0
        vim.g.zig_fmt_autosave = 0

        vim.lsp.config("tailwindcss", {
            filetypes = {
                "html", "css", "scss",
                "javascript", "javascriptreact",
                "typescript", "typescriptreact",
                "vue", "svelte", "heex",
            },
        })

        vim.lsp.config("lexical", {
            cmd = { vim.fn.expand("~/.local/bin/expert"), "--stdio" },
            filetypes = { "elixir", "eelixir", "heex" },
            root_markers = { "mix.exs", ".git" },
        })
        vim.lsp.enable("lexical")

        vim.diagnostic.config({
            float = {
                focusable = false,
                style = "minimal",
                border = "rounded",
                source = "always",
                header = "",
                prefix = "",
            },
        })

        local TRANSPARENT_WINHL = "Normal:Normal,NormalNC:Normal,NormalFloat:Normal,FloatBorder:FloatBorder,EndOfBuffer:Normal,Search:None"

        local function strip_float_bg()
            for _, g in ipairs({ "NormalFloat", "NormalNC", "FloatBorder", "FloatTitle" }) do
                local hl = vim.api.nvim_get_hl(0, { name = g, link = false }) or {}
                hl.bg = nil
                hl.ctermbg = nil
                vim.api.nvim_set_hl(0, g, hl)
            end
            vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#403d52", bg = "NONE" })
        end
        strip_float_bg()
        vim.api.nvim_create_autocmd("ColorScheme", {
            group = vim.api.nvim_create_augroup("LspFloatTransparent", { clear = true }),
            callback = strip_float_bg,
        })

        local orig_open_floating_preview = vim.lsp.util.open_floating_preview
        vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
            opts = opts or {}
            opts.border = opts.border or "rounded"
            opts.max_width = opts.max_width or 100
            local bufnr, winid = orig_open_floating_preview(contents, syntax, opts, ...)
            if winid and vim.api.nvim_win_is_valid(winid) then
                strip_float_bg()
                vim.api.nvim_set_option_value("winhighlight", TRANSPARENT_WINHL, { win = winid })
            end
            return bufnr, winid
        end

        local orig_open_float = vim.diagnostic.open_float
        vim.diagnostic.open_float = function(opts, ...)
            opts = opts or {}
            local bufnr, winid = orig_open_float(opts, ...)
            if winid and vim.api.nvim_win_is_valid(winid) then
                strip_float_bg()
                vim.api.nvim_set_option_value("winhighlight", TRANSPARENT_WINHL, { win = winid })
            end
            return bufnr, winid
        end
    end,
}
