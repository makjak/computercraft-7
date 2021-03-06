---
-- lib/display.lua - Display exposed as API
-- @release 0.0.2
-- @author David O'Trakoun <me@davidosomething.com>
--
-- luacheck: globals devices

local windows = {}

-- ---------------------------------------------------------------------------
-- Functions
-- ---------------------------------------------------------------------------

--- Create or reuse a window on the current display
--
-- @tparam string name
function use(name) -- luacheck: ignore
  -- Window exists, make visible
  if windows[name] ~= nil then windows[name].setVisible(true) end

  -- Already using the window, done
  if term.current() == windows[name] then return end

  -- Window doesn't exist, create it in the monitor
  if windows[name] == nil then
    local termW, termH = term.getSize()
    local parentTerm = devices['monitor'] or term.native()
    windows[name] = window.create(parentTerm, 1, 1, termW, termH)
  end

  -- Use window
  term.redirect(windows[name])
end


--- Back to regular monitor/native term
--
function reset() -- luacheck: ignore
  -- Hide any open windows
  for name,win in pairs(windows) do win.setVisible(false) end

  -- Redirect any future output to monitor or native terminal
  local parentTerm = devices['monitor'] or term.native()
  term.redirect(parentTerm)
end

