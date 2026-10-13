--!nonstrict
-- Sounds.luau
-- Sound IDs in one place. The rbxasset:// sounds ship with every Roblox
-- client, so they always work. Swap in Creator Store audio for extra polish
-- (see docs/ASSETS.md). An empty string disables that sound gracefully.

return {
	Click = "rbxasset://sounds/clickfast.wav",
	Catch = "rbxasset://sounds/electronicpingshort.wav",
	Collect = "rbxasset://sounds/electronicpingshort.wav",
	Upgrade = "rbxasset://sounds/button.wav",
	Error = "rbxasset://sounds/clickfast.wav",
	Announce = "rbxasset://sounds/electronicpingshort.wav",
	Jump = "rbxasset://sounds/action_jump.mp3",
	Splash = "rbxasset://sounds/impact_water.mp3",
	-- Background music: paste a licensed/Roblox-provided track ID, e.g. "rbxassetid://1234".
	Music = "",
	WeatherMusic = "",
}
