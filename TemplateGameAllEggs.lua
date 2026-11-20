--[[
	═══════════════════════════════════════════════════════════════
	  GOD MODE
	  • Kebal pukul / damage  (Health dikunci + metatable hook)
	  • Anti knockback / anti lempar
	  • Anti steal (tool yang diambil balik ke Backpack)
	  • Anti teleport / anti grab paksa
	  • Anti void (jatuh ke bawah ditarik balik)
	  • Anti freeze / anchor
	  • Speed + JumpPower + Infinite Jump + Noclip + Fly
	  Taruh di: StarterPlayer > StarterPlayerScripts (LocalScript)
	═══════════════════════════════════════════════════════════════
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local CONFIG = {
	GodMode        = true,
	AntiKnockback  = true,
	KnockbackLimit = 45,   -- batas kecepatan horizontal (stud/s)
	AntiSteal      = true,
	AntiTeleport   = true,
	TeleportLimit  = 60,   -- jarak 1 frame yang dianggap teleport
	AntiVoid       = true,
	AntiFreeze     = true,
	WalkSpeed      = 32,
	JumpPower      = 110,
	InfiniteJump   = true,
	Noclip         = false,
	FlyKey         = Enum.KeyCode.F,
	GodKey         = Enum.KeyCode.G,
	FlySpeed       = 85,
}

---------------------------------------------------------------------
local myHum, myHrp, myBackpack
local rawIndex, rawNewIndex
local hooksInstalled = false
local flying, flyBV, flyBG = false, nil, nil
local lastPos
local conns = {}

local function track(c) conns[#conns + 1] = c return c end
local function cleanup()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	table.clear(conns)
end

---------------------------------------------------------------------
-- HOOK METATABLE (sekali saja, dipakai semua karakter)
---------------------------------------------------------------------
local function installHooks()
	if hooksInstalled then return end
	hooksInstalled = true

	local probe = Instance.new("Humanoid")
	local mt = getmetatable(probe)
	probe:Destroy()
	if not mt then return end

	rawIndex    = mt.__index
	rawNewIndex = mt.__newindex or function() end

	mt.__index = function(self, key)
		if self == myHum and CONFIG.GodMode and key == "Health" then
			return rawIndex(self, "MaxHealth")
		end
		return rawIndex(self, key)
	end

	mt.__newindex = function(self, key, value)
		if self == myHum and CONFIG.GodMode then
			if key == "Health" then
				local max = rawIndex(self, "MaxHealth")
				if value < max then value = max end
			elseif key == "MaxHealth" and value < 1000 then
				value = 1000
			end
		end
		rawNewIndex(self, key, value)
	end
end

local function hardSetHealth()
	rawNewIndex(myHum, "MaxHealth", 1e6)
	rawNewIndex(myHum, "Health", 1e6)
end

---------------------------------------------------------------------
-- FLY
---------------------------------------------------------------------
local function stopFly()
	flying = false
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
	if myHum and myHum.Parent then myHum.PlatformStand = false end
end

local function startFly()
	if flying or not myHrp then return end
	flying = true
	myHum.PlatformStand = true

	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	flyBV.Velocity = Vector3.zero
	flyBV.Parent = myHrp

	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	flyBG.P = 4000
	flyBG.Parent = myHrp
end

---------------------------------------------------------------------
-- SETUP KARAKTER
---------------------------------------------------------------------
local function setupCharacter(char)
	cleanup()
	stopFly()

	myHum      = char:WaitForChild("Humanoid")
	myHrp      = char:WaitForChild("HumanoidRootPart")
	myBackpack = player:WaitForChild("Backpack")
	lastPos    = myHrp.Position

	installHooks()
	if CONFIG.GodMode then hardSetHealth() end

	myHum.WalkSpeed = CONFIG.WalkSpeed
	myHum.JumpPower = CONFIG.JumpPower

	local grace = os.clock() + 1.5

	-----------------------------------------------------------------
	-- 1. JAGA HEALTH TETAP PENUH (backup kalau hook dilewati)
	-----------------------------------------------------------------
	track(RunService.Heartbeat:Connect(function()
		if not CONFIG.GodMode or not myHum.Parent then return end
		if rawIndex(myHum, "Health") ~= rawIndex(myHum, "MaxHealth") then
			rawNewIndex(myHum, "Health", rawIndex(myHum, "MaxHealth"))
		end
	end))

	-----------------------------------------------------------------
	-- 2. ANTI KNOCKBACK / ANTI LEMPAR
	-----------------------------------------------------------------
	track(RunService.Heartbeat:Connect(function()
		if not CONFIG.AntiKnockback or flying then return end
		local v = myHrp.AssemblyLinearVelocity
		local flat = Vector3.new(v.X, 0, v.Z)
		if flat.Magnitude > CONFIG.KnockbackLimit then
			local d = flat.Unit
			myHrp.AssemblyLinearVelocity =
				Vector3.new(d.X * CONFIG.KnockbackLimit, v.Y, d.Z * CONFIG.KnockbackLimit)
		end
		if myHum:GetState() == Enum.HumanoidStateType.FallingDown then
			myHum:ChangeState(Enum.HumanoidStateType.Running)
		end
	end))

	-----------------------------------------------------------------
	-- 3. ANTI STEAL (tool dikembalikan ke Backpack)
	-----------------------------------------------------------------
	track(myBackpack.ChildRemoved:Connect(function(item)
		if not CONFIG.AntiSteal or not item:IsA("Tool") then return end
		task.wait(0.1)
		if item.Parent == nil and myBackpack.Parent then
			item.Parent = myBackpack
		end
	end))

	track(char.ChildRemoved:Connect(function(item)
		if not CONFIG.AntiSteal or not item:IsA("Tool") then return end
		task.wait(0.1)
		if item.Parent == nil and myBackpack.Parent then
			item.Parent = myBackpack
		end
	end))

	-----------------------------------------------------------------
	-- 4. ANTI TELEPORT / ANTI GRAB
	-----------------------------------------------------------------
	track(RunService.Stepped:Connect(function()
		if not CONFIG.AntiTeleport or flying or not myHrp.Parent then
			lastPos = myHrp.Position
			return
		end
		if os.clock() < grace then
			lastPos = myHrp.Position
			return
		end
		local rot = myHrp.CFrame - myHrp.Position
		if (myHrp.Position - lastPos).Magnitude > CONFIG.TeleportLimit then
			myHrp.CFrame = CFrame.new(lastPos) * rot
		else
			lastPos = myHrp.Position
		end
	end))

	-----------------------------------------------------------------
	-- 5. ANTI VOID + ANTI FREEZE
	-----------------------------------------------------------------
	track(RunService.Heartbeat:Connect(function()
		if CONFIG.AntiVoid and myHrp.Position.Y < -60 then
			local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
			myHrp.CFrame = CFrame.new(spawn and spawn.Position + Vector3.new(0, 5, 0)
				or Vector3.new(0, 50, 0))
			myHrp.AssemblyLinearVelocity = Vector3.zero
		end
		if CONFIG.AntiFreeze then
			if myHrp.Anchored then myHrp.Anchored = false end
			if myHum.PlatformStand and not flying then myHum.PlatformStand = false end
		end
	end))

	-----------------------------------------------------------------
	-- 6. INFINITE JUMP
	-----------------------------------------------------------------
	track(UserInputService.JumpRequest:Connect(function()
		if not CONFIG.InfiniteJump then return end
		local v = myHrp.AssemblyLinearVelocity
		myHrp.AssemblyLinearVelocity = Vector3.new(v.X, CONFIG.JumpPower * 0.5, v.Z)
	end))

	-----------------------------------------------------------------
	-- 7. NOCLIP
	-----------------------------------------------------------------
	track(RunService.Stepped:Connect(function()
		if not CONFIG.Noclip then return end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = false end
		end
	end))

	-----------------------------------------------------------------
	-- 8. FLY UPDATE
	-----------------------------------------------------------------
	track(RunService.RenderStepped:Connect(function()
		if not flying or not flyBV or not myHrp.Parent then return end
		local cam = workspace.CurrentCamera
		local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
		local dir = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += look end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= look end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += right end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= right end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
		flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * CONFIG.FlySpeed or Vector3.zero
		flyBG.CFrame = CFrame.new(myHrp.Position, myHrp.Position + look)
	end))

	track(myHum.Died:Connect(function() stopFly() end))
end

---------------------------------------------------------------------
-- HOTKEY
---------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == CONFIG.FlyKey then
		if flying then stopFly() else startFly() end
	elseif input.KeyCode == CONFIG.GodKey then
		CONFIG.GodMode = not CONFIG.GodMode
		if CONFIG.GodMode then hardSetHealth() else myHum.Health = 100 end
	end
end)

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)
