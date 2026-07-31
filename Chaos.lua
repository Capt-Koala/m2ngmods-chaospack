
local KEYVAL = "F9"

-- CHAOS: continuous carnage mode — every second, flings every vehicle
-- nearby with raw engine impulses. Toggle on/off with F9.
--
-- Uses math.randf (the engine's own RNG) — NOT math.random, which
-- returns nil in this Lua build and was the source of every failure.

if not _G.Ess then
  Loader.Printf("[chaos] Ess not loaded — deploy 1_Ess.lua first")
  return
end

-- ====================== CONFIG ======================
local RADIUS           = 200
local CYCLE_SECONDS    = 1.0
local STRENGTH_MIN     = 5000
local STRENGTH_MAX     = 25000
local EXPLOSION_CHANCE = 0.15
-- ====================================================

_G.ChaosState = _G.ChaosState or { bOn = false }
local S = _G.ChaosState

local EXPLOSION_FX = {
  "global_particle_explosion_medium",
  "global_particle_explosion_small",
  "global_particle_airstrike_artillery",
}

-- Helpers wrapping the engine's real RNG (math.randf(lo, hi)).
local function randf()       return math.randf(0, 1) end
local function randInt(n)    return math.floor(math.randf(1, n + 0.999)) end
local function chance(p)     return math.randf(0, 1) < p end

-- ----------------------------------------------------------------
-- Raw impulse — bypasses all Ess wrappers.
-- ----------------------------------------------------------------
local function fling(uGuid)
  if not Ess.Object.valid(uGuid) or not Ess.Object.alive(uGuid) then
    return false
  end

  local bOk, bHib = pcall(Object.IsHibernated, uGuid)
  if bOk and bHib then return false end

  -- random world-space direction with upward bias
  local dx = randf() * 2 - 1
  local dy = randf() * 1.5
  local dz = randf() * 2 - 1
  local inv = 1 / math.sqrt(dx*dx + dy*dy + dz*dz)
  dx = dx * inv
  dy = dy * inv
  dz = dz * inv

  local strength = STRENGTH_MIN + randf() * (STRENGTH_MAX - STRENGTH_MIN)

  local bPushed = pcall(Object.ApplyImpulse, uGuid,
    dx * strength, dy * strength, dz * strength,
    false)

  -- bonus spin
  if bPushed then
    local sx = (randf() * 2 - 1) * strength * 0.3
    local sy = (randf() * 2 - 1) * strength * 0.3
    local sz = (randf() * 2 - 1) * strength * 0.3
    pcall(Object.ApplyPointImpulse, uGuid, sx, sy, sz, 0, 0, 1, false)
  end

  return bPushed
end

-- ----------------------------------------------------------------
-- MAIN WAVE
-- ----------------------------------------------------------------
local function chaosWave()
  if not S.bOn then return end

  local x, y, z = Ess.Player.pose()
  if not x then
    Event.Create(Event.TimerRelative, {CYCLE_SECONDS}, chaosWave)
    return
  end

  local uPlayerChar    = Ess.Player.character(0)
  local uPlayerVehicle = Ess.Player.inVehicle(0)
  local sPlayerGuid    = uPlayerChar and tostring(uPlayerChar)
  local sVehGuid       = uPlayerVehicle and tostring(uPlayerVehicle)

  -- Fling existing vehicles nearby
  local tAll = Ess.Probe.nearby(x, y, z, RADIUS, "vehicles") or {}
  local nFlinged, nSkipped = 0, 0

  for _, uGuid in ipairs(tAll) do
    local sGuid = tostring(uGuid)
    if sGuid == sPlayerGuid or sGuid == sVehGuid then
      nSkipped = nSkipped + 1
    else
      local bOk, sErr = pcall(fling, uGuid)
      if bOk then
        nFlinged = nFlinged + 1
      else
        Ess.Log("[chaos] fling failed: " .. tostring(sErr))
      end

      if chance(EXPLOSION_CHANCE) then
        local fx = EXPLOSION_FX[randInt(#EXPLOSION_FX)]
        local cx, cy, cz = Ess.Object.pos(uGuid)
        if cx then
          pcall(Airstrike.SpawnDirectedObject, fx, cx, cy, cz, 0, 1, 0)
        end
      end
    end
  end

  if #tAll > 0 then
    Ess.Log(string.format("[chaos] wave: %d objects (%d flung, %d skipped)",
      #tAll, nFlinged, nSkipped))
  end

  Event.Create(Event.TimerRelative, {CYCLE_SECONDS}, chaosWave)
end

-- ====================== TOGGLE ======================
S.bOn = not S.bOn

if S.bOn then
  Ess.UI.Toast("CHAOS: UNLEASHED   ")
  Ess.Log(string.format(
    "[chaos] ARMED — %du radius, every %.1fs, raw impulse %d–%d",
    RADIUS, CYCLE_SECONDS, STRENGTH_MIN, STRENGTH_MAX))
  chaosWave()
else
  S.bOn = false
  Ess.UI.Toast("CHAOS: SUPPRESSED")
  Ess.Log("[chaos] DISARMED")
end
