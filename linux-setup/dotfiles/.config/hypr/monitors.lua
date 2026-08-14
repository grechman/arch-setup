local monitors = {
    {
        output = "",
        mode = "preferred",
        position = "auto",
        scale = 1,
    },
}

for _, monitor in ipairs(monitors) do
    hl.monitor(monitor)
end

return monitors
