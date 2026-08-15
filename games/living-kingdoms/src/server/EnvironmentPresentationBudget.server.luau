--!strict

--[[
	One-shot Main World presentation budget audit. This script measures only
	presentation-owned subtrees, never gameplay geometry. It does not remove or
	change content at runtime; it publishes diagnostics and warns when a budget or
	authority boundary is exceeded so Studio profiling has concrete evidence.

	The audit runs once for each generated Main World root after a short bounded
	settle window. There is no heartbeat, render-step, or permanent polling loop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BudgetConfig = require(ReplicatedStorage.Shared.Config.EnvironmentPresentationBudgetConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)

type Counts = { [string]: number }

local COUNT_KEYS = table.freeze({
	"PresentationRootCount",
	"ModelCount",
	"BasePartCount",
	"ParticleEmitterCount",
	"LightCount",
	"BeamTrailCount",
	"AttachmentCount",
	"InteractiveCount",
	"ScriptCount",
	"CollidablePartCount",
	"TouchPartCount",
	"QueryablePartCount",
})

local function newCounts(): Counts
	local counts: Counts = {}
	for _, key in COUNT_KEYS do
		counts[key] = 0
	end
	return counts
end

local function isPresentationOwned(instance: Instance): boolean
	return instance:GetAttribute("EnvironmentPresentationOnly") == true
end

local function hasPresentationAncestor(instance: Instance, worldRoot: Folder): boolean
	local ancestor = instance.Parent
	while ancestor ~= nil and ancestor ~= worldRoot do
		if isPresentationOwned(ancestor) then
			return true
		end
		ancestor = ancestor.Parent
	end
	return false
end

local function collectPresentationRoots(worldRoot: Folder): { Instance }
	local roots = {}
	for _, descendant in worldRoot:GetDescendants() do
		if isPresentationOwned(descendant) and not hasPresentationAncestor(descendant, worldRoot) then
			table.insert(roots, descendant)
		end
	end
	table.sort(roots, function(a: Instance, b: Instance): boolean
		return a:GetFullName() < b:GetFullName()
	end)
	return roots
end

local function countInstance(instance: Instance, counts: Counts)
	if instance:IsA("Model") then
		counts.ModelCount += 1
	end

	if instance:IsA("BasePart") then
		counts.BasePartCount += 1
		if instance.CanCollide then
			counts.CollidablePartCount += 1
		end
		if instance.CanTouch then
			counts.TouchPartCount += 1
		end
		if instance.CanQuery then
			counts.QueryablePartCount += 1
		end
	elseif instance:IsA("ParticleEmitter") then
		counts.ParticleEmitterCount += 1
	elseif instance:IsA("Light") then
		counts.LightCount += 1
	elseif instance:IsA("Beam") or instance:IsA("Trail") then
		counts.BeamTrailCount += 1
	elseif instance:IsA("Attachment") then
		counts.AttachmentCount += 1
	elseif instance:IsA("ProximityPrompt") or instance:IsA("ClickDetector") then
		counts.InteractiveCount += 1
	elseif instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
		counts.ScriptCount += 1
	end
end

local function measure(worldRoot: Folder): Counts
	local counts = newCounts()
	local roots = collectPresentationRoots(worldRoot)
	counts.PresentationRootCount = #roots

	for _, root in roots do
		countInstance(root, counts)
		for _, descendant in root:GetDescendants() do
			countInstance(descendant, counts)
		end
	end
	return counts
end

local function publish(worldRoot: Folder, counts: Counts, status: string)
	worldRoot:SetAttribute("EnvironmentPresentationBudgetVersion", BudgetConfig.Version)
	worldRoot:SetAttribute("EnvironmentPresentationBudgetStatus", status)
	for _, key in COUNT_KEYS do
		worldRoot:SetAttribute("EnvironmentPresentation" .. key, counts[key])
	end
end

local function evaluate(counts: Counts): { string }
	local violations = {}
	for _, key in COUNT_KEYS do
		local budget = BudgetConfig.Budgets[key]
		local actual = counts[key]
		if actual > budget then
			table.insert(violations, string.format("%s=%d > %d", key, actual, budget))
		end
	end
	return violations
end

local function audit(candidate: Instance)
	if candidate.Parent ~= Workspace or candidate.Name ~= WorldConfig.WorldRootName or not candidate:IsA("Folder") then
		return
	end

	task.wait(BudgetConfig.SettleSeconds)
	if candidate.Parent ~= Workspace then
		return
	end

	local counts = measure(candidate)
	local violations = evaluate(counts)
	local status = if #violations == 0 then "WithinBudget" else "OverBudget"
	publish(candidate, counts, status)

	if #violations > 0 then
		warn("[Living Kingdoms] Environment presentation budget exceeded: " .. table.concat(violations, "; "))
		return
	end

	print(
		string.format(
			"[Living Kingdoms] Environment presentation budget OK: %d models / %d parts / %d emitters / %d lights",
			counts.ModelCount,
			counts.BasePartCount,
			counts.ParticleEmitterCount,
			counts.LightCount
		)
	)
end

local initialRoot = Workspace:FindFirstChild(WorldConfig.WorldRootName)
if initialRoot ~= nil then
	task.defer(audit, initialRoot)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == WorldConfig.WorldRootName then
		task.defer(audit, child)
	end
end)
