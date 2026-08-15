--!strict

-- Compatibility facade during semantic controller migration.
-- New code should require Controllers.Input.ChoiceInputCoordinator.
return require(script.Parent.Input.ChoiceInputCoordinator)
