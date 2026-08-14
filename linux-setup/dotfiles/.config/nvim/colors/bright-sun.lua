vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
end

vim.o.background = "light"
vim.g.colors_name = "bright-sun"

local c = {
    bg = "#fdf6e3",
    bg_alt = "#eee8d5",
    bg_line = "#f7f0dd",
    border = "#7b7260",
    fg = "#111111",
    fg_alt = "#3b352d",
    muted = "#6b6458",
    blue = "#0b67b2",
    cyan = "#2a8a9e",
    green = "#6b8e00",
    orange = "#cb4b16",
    purple = "#6c71c4",
    red = "#b0302f",
    yellow = "#8a6a00",
    pink = "#a52b6b",
    white = "#ffffff",
}

local function hl(group, spec)
    vim.api.nvim_set_hl(0, group, spec)
end

hl("Normal", { fg = c.fg, bg = c.bg })
hl("NormalNC", { fg = c.fg, bg = c.bg })
hl("EndOfBuffer", { fg = c.bg_alt, bg = c.bg })
hl("SignColumn", { fg = c.muted, bg = c.bg })
hl("LineNr", { fg = c.muted, bg = c.bg })
hl("CursorLine", { bg = c.bg_line })
hl("CursorLineNr", { fg = c.blue, bg = c.bg_line, bold = true })
hl("ColorColumn", { bg = c.bg_alt })
hl("Visual", { fg = c.white, bg = c.blue })
hl("Search", { fg = c.white, bg = c.orange, bold = true })
hl("IncSearch", { fg = c.white, bg = c.red, bold = true })
hl("CurSearch", { fg = c.white, bg = c.red, bold = true })
hl("MatchParen", { fg = c.red, bg = c.bg_alt, bold = true })

hl("NormalFloat", { fg = c.fg, bg = c.bg_alt })
hl("FloatBorder", { fg = c.blue, bg = c.bg_alt })
hl("FloatTitle", { fg = c.blue, bg = c.bg_alt, bold = true })
hl("Pmenu", { fg = c.fg, bg = c.bg_alt })
hl("PmenuSel", { fg = c.white, bg = c.blue, bold = true })
hl("PmenuSbar", { bg = c.bg_alt })
hl("PmenuThumb", { bg = c.border })
hl("WildMenu", { fg = c.white, bg = c.blue, bold = true })

hl("StatusLine", { fg = c.fg, bg = c.bg_alt })
hl("StatusLineNC", { fg = c.muted, bg = c.bg_alt })
hl("WinSeparator", { fg = c.border, bg = c.bg })
hl("VertSplit", { fg = c.border, bg = c.bg })
hl("TabLine", { fg = c.muted, bg = c.bg_alt })
hl("TabLineFill", { fg = c.muted, bg = c.bg_alt })
hl("TabLineSel", { fg = c.blue, bg = c.bg, bold = true })
hl("ModeMsg", { fg = c.blue, bold = true })
hl("MoreMsg", { fg = c.green, bold = true })
hl("Question", { fg = c.blue, bold = true })
hl("WarningMsg", { fg = c.yellow, bold = true })
hl("ErrorMsg", { fg = c.red, bold = true })
hl("Directory", { fg = c.blue, bold = true })
hl("Title", { fg = c.blue, bold = true })

hl("Comment", { fg = c.muted })
hl("Constant", { fg = c.purple })
hl("String", { fg = c.green })
hl("Character", { fg = c.green })
hl("Number", { fg = c.purple })
hl("Boolean", { fg = c.purple, bold = true })
hl("Float", { fg = c.purple })
hl("Identifier", { fg = c.fg })
hl("Function", { fg = c.blue, bold = true })
hl("Statement", { fg = c.red, bold = true })
hl("Conditional", { fg = c.red, bold = true })
hl("Repeat", { fg = c.red, bold = true })
hl("Label", { fg = c.orange, bold = true })
hl("Operator", { fg = c.red })
hl("Keyword", { fg = c.red, bold = true })
hl("Exception", { fg = c.red, bold = true })
hl("PreProc", { fg = c.orange })
hl("Include", { fg = c.red, bold = true })
hl("Define", { fg = c.orange })
hl("Macro", { fg = c.orange })
hl("PreCondit", { fg = c.orange })
hl("Type", { fg = c.purple, bold = true })
hl("StorageClass", { fg = c.purple, bold = true })
hl("Structure", { fg = c.purple, bold = true })
hl("Typedef", { fg = c.purple, bold = true })
hl("Special", { fg = c.cyan })
hl("SpecialChar", { fg = c.cyan })
hl("Tag", { fg = c.blue })
hl("Delimiter", { fg = c.fg_alt })
hl("SpecialComment", { fg = c.muted, bold = true })
hl("Debug", { fg = c.red })
hl("Underlined", { fg = c.blue, underline = true })
hl("Ignore", { fg = c.muted })
hl("Error", { fg = c.white, bg = c.red, bold = true })
hl("Todo", { fg = c.white, bg = c.orange, bold = true })

hl("DiffAdd", { fg = c.green, bg = "#e7f0c8" })
hl("DiffChange", { fg = c.yellow, bg = "#f7e8b1" })
hl("DiffDelete", { fg = c.red, bg = "#f7d8d6" })
hl("DiffText", { fg = c.fg, bg = "#f0d470", bold = true })
hl("Added", { fg = c.green })
hl("Changed", { fg = c.yellow })
hl("Removed", { fg = c.red })

hl("DiagnosticError", { fg = c.red })
hl("DiagnosticWarn", { fg = c.yellow })
hl("DiagnosticInfo", { fg = c.cyan })
hl("DiagnosticHint", { fg = c.blue })
hl("DiagnosticUnderlineError", { undercurl = true, sp = c.red })
hl("DiagnosticUnderlineWarn", { undercurl = true, sp = c.yellow })
hl("DiagnosticUnderlineInfo", { undercurl = true, sp = c.cyan })
hl("DiagnosticUnderlineHint", { undercurl = true, sp = c.blue })
hl("LspReferenceText", { bg = c.bg_line })
hl("LspReferenceRead", { bg = c.bg_line })
hl("LspReferenceWrite", { bg = c.bg_line })

hl("@comment", { link = "Comment" })
hl("@string", { link = "String" })
hl("@number", { link = "Number" })
hl("@boolean", { link = "Boolean" })
hl("@function", { link = "Function" })
hl("@function.call", { link = "Function" })
hl("@method", { link = "Function" })
hl("@constructor", { fg = c.purple, bold = true })
hl("@keyword", { link = "Keyword" })
hl("@keyword.function", { link = "Keyword" })
hl("@conditional", { link = "Conditional" })
hl("@repeat", { link = "Repeat" })
hl("@operator", { link = "Operator" })
hl("@type", { link = "Type" })
hl("@type.builtin", { link = "Type" })
hl("@variable", { fg = c.fg })
hl("@variable.builtin", { fg = c.red, bold = true })
hl("@property", { fg = c.cyan })
hl("@field", { fg = c.cyan })
hl("@parameter", { fg = c.orange })
hl("@punctuation", { fg = c.fg_alt })
hl("@constant", { link = "Constant" })
hl("@constant.builtin", { link = "Constant" })
hl("@module", { fg = c.blue })
hl("@tag", { fg = c.blue })
hl("@tag.attribute", { fg = c.orange })
hl("@tag.delimiter", { fg = c.fg_alt })
