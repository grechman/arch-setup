-- Grechman Hyprland config.
-- Hyprland 0.55+ loads this file instead of hyprland.conf when it exists.

require("monitors")

local themes = require("themes")

local terminal = "ghostty"
local file_manager = "ghostty -e yazi"
local menu = [[rofi -show drun -p "Search> "]]
local main_mod = "SUPER"

local function bind(keys, dispatcher, opts)
    hl.bind(keys, dispatcher, opts)
end

local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

local function bind_exec(keys, cmd, opts)
    bind(keys, exec(cmd), opts)
end

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 5,
        border_size = 0,
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 7,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },

        blur = {
            enabled = true,
            size = 8,
            ignore_opacity = false,
            passes = 3,
            noise = 0.01,
            vibrancy = 0.1696,
            popups = true,
            popups_ignorealpha = 0.2,
        },
    },

    animations = {
        enabled = false,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        focus_on_activate = false,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },

    input = {
        kb_layout = "us,ru",
        kb_options = "ctrl:nocaps,grp:alt_shift_toggle",
    },
})

themes.apply_hyprland()
hl.on("hyprland.start", themes.apply_apps)

local startup = {
    "hyprlock",
    "waybar",
    "hyprpaper",
    "nm-applet",
    "gnome-keyring-daemon --start --components=secrets",
}

hl.on("hyprland.start", function()
    for _, cmd in ipairs(startup) do
        hl.exec_cmd(cmd)
    end
end)

-- Screenshots
bind_exec(main_mod .. " + S", "hyprshot -m region --clipboard-only")
bind_exec(main_mod .. " + SHIFT + S", "hyprshot -m window --clipboard-only")

-- Session utilities
bind_exec(main_mod .. " + W", "pkill waybar && waybar &")
bind_exec(main_mod .. " + SHIFT + L", "hyprlock")
bind_exec(main_mod .. " + R", [[name=$(basename "$(readlink "$HOME/.config/themes/active" 2>/dev/null || printf kanagawa-dragon)"); "$HOME/.local/bin/theme-apply" "$name" && hyprctl reload]])

-- Workspace and monitor movement
bind(main_mod .. " + SHIFT + M", hl.dsp.workspace.move({ monitor = "+1" }))
bind(main_mod .. " + M", hl.dsp.workspace.move({ monitor = "+1" }))

-- Apps and window control
bind_exec(main_mod .. " + Q", terminal)
bind_exec(main_mod .. " + Return", "kitty")
bind(main_mod .. " + C", hl.dsp.window.close())
bind(main_mod .. " + SHIFT + E", hl.dsp.exit())
bind_exec(main_mod .. " + E", file_manager)
bind(main_mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
bind_exec("CTRL + ALT + V", "/home/grechman/grechman/klim/latex/show-linux.py --source auto")
bind_exec(main_mod .. " + D", menu)
bind(main_mod .. " + P", hl.dsp.window.pseudo())
bind(main_mod .. " + SHIFT + J", hl.dsp.layout("togglesplit"))
bind(main_mod .. " + F", hl.dsp.window.fullscreen())

local focus_dirs = {
    h = "l",
    l = "r",
    k = "u",
    j = "d",
}

for key, direction in pairs(focus_dirs) do
    bind(main_mod .. " + " .. key, hl.dsp.focus({ direction = direction }))
end

for workspace = 1, 10 do
    local key = tostring(workspace % 10)
    bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

for workspace = 1, 5 do
    hl.workspace_rule({
        workspace = tostring(workspace),
        persistent = true,
    })
end

-- Mouse window control
bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume
bind_exec("XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", { locked = true, repeating = true })
bind_exec("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", { locked = true, repeating = true })
bind_exec("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", { locked = true, repeating = true })
bind_exec("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", { locked = true, repeating = true })

-- Brightness
bind_exec("XF86MonBrightnessUp", "brightnessctl s 10%+", { locked = true, repeating = true })
bind_exec("XF86MonBrightnessDown", "brightnessctl s 10%-", { locked = true, repeating = true })

-- Media
bind_exec("XF86AudioNext", "playerctl next", { locked = true })
bind_exec("XF86AudioPause", "playerctl play-pause", { locked = true })
bind_exec("XF86AudioPlay", "playerctl play-pause", { locked = true })
bind_exec("XF86AudioPrev", "playerctl previous", { locked = true })

for _, namespace in ipairs({ "waybar", "rofi" }) do
    hl.layer_rule({
        name = namespace .. "-blur",
        match = { namespace = namespace },
        blur = true,
        ignore_alpha = 0.3,
    })
end

hl.window_rule({ name = "ghostty-no-blur", match = { class = "com.mitchellh.ghostty" }, no_blur = true })
hl.window_rule({ name = "kitty-no-blur", match = { class = "kitty" }, no_blur = true })

hl.window_rule({
    name = "nemo-opacity",
    match = { class = "^(Nemo|nemo)$" },
    opacity = "0.85 0.85",
})

for _, selector in ipairs({ "w[tv1]", "f[1]" }) do
    local name = selector:gsub("[^%w]+", "-")

    hl.workspace_rule({
        workspace = selector,
        gaps_out = 0,
        gaps_in = 0,
    })

    hl.window_rule({
        name = "no-gaps-" .. name,
        match = {
            float = false,
            workspace = selector,
        },
        border_size = 0,
        rounding = 0,
    })
end
