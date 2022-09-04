local M = {}

M.COLORS_BY_NAME = {
   BLACK = 0,
   RED = 1,
   GREEN = 2,
   YELLOW = 3,
   BLUE = 4,
   PURPLE = 5,
   CYAN = 6,
   WHITE = 7,
}

local ESCAPE = string.char(27) -- \e

local function E(s)
   return ESCAPE .. s
end

function M.fg(color)
   return string.format(E"[0;%dm", 30 + color)
end

function M.bg(color)
   return string.format(E"[%dm", 40 + color)
end

function M.bold(color)
   return string.format(E"[1;%dm", 30 + color)
end

M.RESET = E"[0m"

M.STYLES = {
   fg = M.fg,
   bg = M.bg,
   bold = M.bold,
}

M.PATTERN = "%[([a-zA-Z0-9]*):([a-zA-Z0-9]*)%]"

function M.format(fmt, ...)
   local function replace(style, name)
      if style == "" then
         style = "fg"
      end
      assert(M.STYLES[style], "expected a valid style name, not " .. style)
      name = string.upper(name)
      if name == "" then
         return M.RESET
      elseif M.COLORS_BY_NAME[name] then
         return M.STYLES[style](M.COLORS_BY_NAME[name])
      else
         error("could not recognize color: " .. name)
      end
   end
   local escaped = string.gsub(fmt, M.PATTERN, replace)
   return string.format(escaped, ...)
end

return M
