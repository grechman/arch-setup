local M = {}

M.default = "kanagawa-dragon"

M.palette = {
    ["rose-pine"] = {
        active_border = "rgb(c4a7e7)",
        inactive_border = "rgb(26233a)",
    },
    ["rose-pine-moon"] = {
        active_border = "rgb(c4a7e7)",
        inactive_border = "rgb(393552)",
    },
    gruvbox = {
        active_border = "rgb(d79921)",
        inactive_border = "rgb(3c3836)",
    },
    ["kanagawa-wave"] = {
        active_border = "rgb(7E9CD8)",
        inactive_border = "rgb(363646)",
    },
    ["kanagawa-dragon"] = {
        active_border = "rgb(658594)",
        inactive_border = "rgb(393836)",
    },
    ["everforest-dark"] = {
        active_border = "rgb(a7c080)",
        inactive_border = "rgb(414b50)",
    },
    ["ayu-mirage"] = {
        active_border = "rgb(ffa759)",
        inactive_border = "rgb(2d4054)",
    },
    ["iceberg-dark"] = {
        active_border = "rgb(84a0c6)",
        inactive_border = "rgb(2e313f)",
    },
    carbonfox = {
        active_border = "rgb(78a9ff)",
        inactive_border = "rgb(232323)",
    },
    ["bright-sun"] = {
        active_border = "rgb(005bd3)",
        inactive_border = "rgb(746b58)",
    },
}

local home = os.getenv("HOME") or "/home/grechman"

local function readlink(path)
    local handle = io.popen(("readlink %q 2>/dev/null"):format(path))
    if not handle then
        return nil
    end

    local target = handle:read("*l")
    handle:close()

    if not target or target == "" then
        return nil
    end

    return target:match("([^/]+)$") or target
end

function M.active_name()
    local name = readlink(home .. "/.config/themes/active")

    if name and M.palette[name] then
        return name
    end

    return M.default
end

function M.apply_hyprland()
    local name = M.active_name()
    local colors = M.palette[name]

    hl.config({
        general = {
            col = {
                active_border = colors.active_border,
                inactive_border = colors.inactive_border,
            },
        },
    })

    return name
end

function M.apply_apps()
    local name = M.active_name()
    hl.exec_cmd(home .. "/.local/bin/theme-apply " .. name)
end

return M
