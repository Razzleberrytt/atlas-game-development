--!strict

local CharacterProgressionGameplayRewardService =
	require(script.Parent.Systems.CharacterProgressionGameplayRewardService)

CharacterProgressionGameplayRewardService.start()

game:BindToClose(function()
	CharacterProgressionGameplayRewardService.stop()
end)

print("[Living Kingdoms] Character progression gameplay rewards mounted")
