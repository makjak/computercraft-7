--
-- reactor/main
-- v3.0.0
-- by @davidosomething
-- pastebin 710inmxN
--
-- Reactor autostart
--

os.loadAPI('lib/meter')

-- -----------------------------------------------------------------------------
-- Meta ------------------------------------------------------------------------
-- -----------------------------------------------------------------------------
local PROTOCOL = 'reactor'
local REMOTE_PROTOCOL = 'reactor_remote'
local HOSTNAME = 'main'
local MODEM_SIDE = 'left'
local REACTOR_SIDE = 'back'

local ENERGY_MAX = 10000000
local AUTOTOGGLE_ENERGY_THRESHOLD = 50

local is_autotoggle = true
local is_exit = false


-- -----------------------------------------------------------------------------
-- Peripheral config -----------------------------------------------------------
-- -----------------------------------------------------------------------------

-- monitor
local m = peripheral.find('monitor')
if m == nil then
  is_exit = true
else
  local termW, termH = m.getSize()
  term.redirect(m)
end

-- reactor
local r = peripheral.wrap(REACTOR_SIDE)
if r == nil then is_exit = true end

-- modem
rednet.open(MODEM_SIDE)
rednet.host(PROTOCOL, HOSTNAME)


-- -----------------------------------------------------------------------------
-- Functions -------------------------------------------------------------------
-- -----------------------------------------------------------------------------

-- getEnergyPercentage
--
-- @return int
local function getEnergyPercentage()
  return math.floor(r.getEnergyStored() / ENERGY_MAX * 100)
end

-- doAutotoggle
--
local function doAutotoggle()
  -- no fuel, leave off
  if r.getFuelAmount() == 0 then
    r.setActive(false)
    return
  end

  -- turn on if empty buffer
  if getEnergyPercentage() < AUTOTOGGLE_ENERGY_THRESHOLD then
    r.setActive(true)
    return
  end

  -- turn off if not needed
  if r.getEnergyProducedLastTick() == 0 then
    r.setActive(false)
    return
  end
end


-- sendStatus
--
-- Send reactor status as a table over rednet
--
-- @param int remoteId computerId to send rednet message to
local function sendStatus(remoteId)
  local message = {}

  message['active']                 = r.getActive()
  message['energyStored']           = r.getEnergyStored()
  message['fuelAmount']             = r.getFuelAmount()
  message['wasteAmount']            = r.getWasteAmount()
  message['fuelAmountMax']          = r.getFuelAmountMax()
  message['energyProducedLastTick'] = r.getEnergyProducedLastTick()
  message['fuelConsumedLastTick']   = r.getFuelConsumedLastTick()
  message['fuelTemperature']        = r.getFuelTemperature()
  message['casingTemperature']      = r.getCasingTemperature()
  message['is_autotoggle']          = is_autotoggle
  message['energyPercentage']       = getEnergyPercentage()

  rednet.send(remoteId, message, REMOTE_PROTOCOL)
end


-- statusLabel
--
-- Output white text
--
-- @param string text
local function statusLabel(text)
  m.setTextColor(colors.white)
  term.write(text)
end


-- status
--
-- Display reactor status on monitor
--
local function status()
  m.clear()
  m.setTextScale(0.5)
  m.setCursorPos(1,1)

  statusLabel('reactor: ')
  if r.getActive() then
    m.setTextColor(colors.lime)
    term.write('ON')
  else
    m.setTextColor(colors.red)
    term.write('OFF')
  end
  print()

  meter.draw(1, 2, termW, 2, data['energyStored'], ENERGY_MAX)
  print()

  statusLabel('energy: ')
  m.setTextColor(colors.lightGray)
  term.write(r.getEnergyStored() .. '/10000000 RF')
  print()

  statusLabel('output: ')
  m.setTextColor(colors.lightGray)
  term.write(r.getEnergyProducedLastTick() .. ' RF/t')
  print()

  statusLabel('fuel:   ')
  m.setTextColor(colors.yellow)
  term.write(r.getFuelAmount())
  m.setTextColor(colors.lightGray)
  term.write('/')
  m.setTextColor(colors.lightBlue)
  term.write(r.getWasteAmount())
  m.setTextColor(colors.lightGray)
  term.write('/' .. r.getFuelAmountMax() .. 'mb')
  print()

  statusLabel('usage:  ')
  m.setTextColor(colors.lightGray)
  term.write(r.getFuelConsumedLastTick() .. 'mb/t')
  print()

  statusLabel('core:   ')
  m.setTextColor(colors.lightGray)
  term.write(r.getFuelTemperature() .. 'C')
  print()

  statusLabel('case:   ')
  m.setTextColor(colors.lightGray)
  term.write(r.getCasingTemperature() .. 'C')
  print()

  statusLabel('auto:   ')
  if is_autotoggle then
    m.setTextColor(colors.lime)
    term.write('ON')
  else
    m.setTextColor(colors.gray)
    term.write('OFF')
  end

  m.setTextColor(colors.lightGray)
  print()
  print("[q]uit  [t]oggle  [a]utotoggle")
  print()
end


-- toggleAutotoggle
--
-- Switch autotoggle on/off state
--
local function toggleAutotoggle()
  is_autotoggle = not is_autotoggle
end


-- toggleReactor
--
-- Switch reactor on/off
--
-- @param nil,boolean state - toggle if nil, on if true, off if false
local function toggleReactor(state)
  -- toggle
  if state == nil then state = not r.getActive() end

  -- set to exact
  r.setActive(state)
end


-- getMonitorTouch
--
-- Read right clicks on monitor to toggle reactor on/off
--
local function getMonitorTouch()
  local event, side, x, y = os.pullEvent('monitor_touch')
  toggleReactor()
end


-- getKey
--
-- Do some action based on user key input from terminal
--
local function getKey()
  local event, code = os.pullEvent('char')
  if      code == keys.a then toggleAutotoggle()
  elseif  code == keys.t then toggleReactor()
  elseif  code == keys.q then is_exit = true
  end
end


-- getModemMessage
--
-- Do some action if receiving redstone message from modem
--
local function getModemMessage()
  local senderId, message, protocol = rednet.receive('reactor')
  if     message == 'autotoggle'  then toggleAutotoggle()
  elseif message == 'toggle'      then toggleReactor()
  elseif message == 'on'          then toggleReactor(true)
  elseif message == 'off'         then toggleReactor(false)
  end

  -- always send reactor status back when a request is made
  sendStatus(senderId)
end


-- getTimeout
--
local function getTimeout()
  local event, timerHandler = os.pullEvent('timer')
  if is_autotoggle then doAutotoggle() end
end


-- -----------------------------------------------------------------------------
-- Main ------------------------------------------------------------------------
-- -----------------------------------------------------------------------------

(function ()
  if is_exit then return end

  while not is_exit do
    local statusTimer = os.startTimer(1)
    status()

    parallel.waitForAny(getKey, getMonitorTouch, getModemMessage, getTimeout)
    os.cancelTimer(statusTimer)
  end
end)()
