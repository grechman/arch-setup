local M = {}

local dark_default = "rose-pine-moon"
local dark_zig = "tokyonight-night"

local function theme_name()
    local active = vim.fn.resolve(vim.fn.expand("~/.config/themes/active"))
    if active == "" then
        return ""
    end
    return vim.fn.fnamemodify(active, ":t")
end

local function theme_base()
    local name = theme_name()
    if name == "" then
        return "dark"
    end

    local path = vim.fn.expand("~/.config/themes/" .. name .. "/base")
    local file = io.open(path, "r")
    if not file then
        return "dark"
    end

    local base = file:read("*l") or "dark"
    file:close()
    return base:match("^%s*light%s*$") and "light" or "dark"
end

local function clear_dark_backgrounds()
    for _, group in ipairs({
        "Normal",
        "NormalNC",
        "NormalFloat",
        "QuickFixLine",
    }) do
        vim.api.nvim_set_hl(0, group, { bg = "none" })
    end
end

function M.apply(filetype, color)
    if theme_base() == "light" then
        vim.o.background = "light"
        pcall(vim.cmd.colorscheme, "bright-sun")
        return
    end

    vim.o.background = "dark"
    local dark_color = color or (filetype == "zig" and dark_zig or dark_default)
    pcall(vim.cmd.colorscheme, dark_color)
    clear_dark_backgrounds()
end

return M
