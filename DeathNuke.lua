local KEYVAL = "f11"  -- must be in the first 10 lines -- pick an unused key

-- deathnuke.lua: OnKey toggle -- when ON, a tactical-nuke particle erupts
-- at your position every time you die. Re-arms itself after respawn.

if not _G.Ess then
  Loader.Printf("[deathnuke] Ess not loaded -- deploy 1_Ess.lua first")
  return
end

_G.DeathNuke = _G.DeathNuke or {
  bOn      = false,
  stopDeath = nil,   -- stop() from Ess.On.death
  stopPoll  = nil,   -- stop() from the respawn-polling tick
}
local S = _G.DeathNuke

----------------------------------------------------------------------
-- Arm the death watch on the current character. Call this whenever
-- a fresh character appears (initial toggle-on, or after respawn).
----------------------------------------------------------------------
local function armDeathWatch()
  -- Tear down any previous watch first (idempotent).
  if S.stopDeath then S.stopDeath(); S.stopDeath = nil end

  local uChar = Ess.Player.character(0)
  if not uChar then
    Ess.Log("[deathnuke] no character to watch -- will retry on next death poll")
    return
  end

  S.stopDeath = Ess.On.death(uChar, function()
    -- Read the position while the corpse/wreck is still there.
    local x, y, z = Ess.Object.pos(uChar)
    if x then
      -- Fire the two main nuke particles at ground zero.
      pcall(Airstrike.SpawnDirectedObject,
            "global_particle_airstrike_tactnuke", x, y, z, 0, 1, 0)
      pcall(Airstrike.SpawnDirectedObject,
            "global_particle_exp_shockwave_ground_tactnuke", x, y, z, 0, 1, 0)
      Ess.Log(string.format("[deathnuke] \194\160BOOM at %.1f, %.1f, %.1f", x, y, z))
    end

    -- Player is dead now -- wait for respawn, then re-arm.
    if S.stopPoll then S.stopPoll() end
    S.stopPoll = Ess.On.tick(0.5, function()
      local newChar = Ess.Player.character(0)
      if newChar and Ess.Object.alive(newChar) then
        S.stopPoll()
        S.stopPoll = nil
        armDeathWatch()
        Ess.Log("[deathnuke] re-armed on respawned character")
      end
    end)
  end)

  Ess.Log("[deathnuke] watching " .. tostring(Ess.Name(uChar) or uChar))
end

----------------------------------------------------------------------
-- Tear down everything.
----------------------------------------------------------------------
local function disarm()
  if S.stopDeath then S.stopDeath(); S.stopDeath = nil end
  if S.stopPoll  then S.stopPoll();  S.stopPoll  = nil end
end

----------------------------------------------------------------------
-- Toggle on each keypress.
----------------------------------------------------------------------
S.bOn = not S.bOn

if S.bOn then
  armDeathWatch()
  Ess.UI.Toast("DEATH NUKE: ARMED   ")
  Ess.Log("[deathnuke] ARMED -- tactical nuke will fire on every death")
else
  disarm()
  Ess.UI.Toast("DEATH NUKE: DISARMED")
  Ess.Log("[deathnuke] DISARMED")
end