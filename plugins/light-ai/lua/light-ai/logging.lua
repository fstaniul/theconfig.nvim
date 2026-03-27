---@enum Levels
local Levels = {
  DEBUG = 0,
  INFO = 5,
  ERROR = 10,
}

---@class Logger
---@field file string File path where logs are stored.
---@field level integer Minimum level to log (use Levels.DEBUG / INFO / ERROR).
---@field info fun(self: Logger, msg: string, ...) Logs an informational message.
---@field error fun(self: Logger, msg: string, ...) Logs an error message.
---@field debug fun(self: Logger, msg: string, ...) Logs a debug message.
local Logger = {}
Logger.__index = Logger

local LOG_DIR = '/tmp/light-ai'

---Creates a new Logger instance.
---@param name string  A short label used as the log file name, e.g. "agent".
---@param level? integer  Minimum level to log. Defaults to Levels.DEBUG.
---@return Logger
function Logger.new(name, level)
  vim.fn.mkdir(LOG_DIR, 'p')
  local file = LOG_DIR .. '/' .. name .. '.log'
  return setmetatable({ file = file, level = level or Levels.DEBUG }, Logger)
end

---Formats a log line with a timestamp and level label.
---@param label string  Already-padded 5-char label.
---@param msg string
---@param ... any
---@return string
local function format(label, msg, ...)
  local args = { ... }
  if #args > 0 then
    local ok, formatted = pcall(string.format, msg, unpack(args))
    msg = ok and formatted or (msg .. ' ' .. vim.inspect(args))
  end
  return string.format('%s %s | %s\n', os.date '%Y-%m-%d %H:%M:%S', label, msg)
end

---Appends a line to the log file.
---@param self Logger
---@param msg_level integer  Numeric level of this message.
---@param label string
---@param msg string
---@param ... any
local function append(self, msg_level, label, msg, ...)
  if msg_level < self.level then return end
  local fh = io.open(self.file, 'a')
  if fh then
    fh:write(format(label, msg, ...))
    fh:close()
  end
end

---Logs a debug message.
---@param msg string
---@param ... any  Optional arguments forwarded to string.format.
function Logger:debug(msg, ...) append(self, Levels.DEBUG, 'DEBUG', msg, ...) end

---Logs an informational message.
---@param msg string
---@param ... any  Optional arguments forwarded to string.format.
function Logger:info(msg, ...) append(self, Levels.INFO, ' INFO', msg, ...) end

---Logs an error message.
---@param msg string
---@param ... any  Optional arguments forwarded to string.format.
function Logger:error(msg, ...) append(self, Levels.ERROR, 'ERROR', msg, ...) end

Logger.Levels = Levels

return Logger
