--!strict

-- Secondary presentation dressing layered around the seeded hero composition.
-- Stable modular AssetIds come from ModularAssetProductionCatalog; this config
-- only decides where those presentation prototypes are useful in the Main World.

local Config = {
	Version = "modular-field-dressing-v1",
	FolderName = "ModularFieldProps",
	MaximumPropCount = 18,
	MinimumOffsetStuds = 7,
	MaximumOffsetStuds = 11,
	GroundRayOriginY = 160,
	GroundRayDistance = 320,
	GeneratedAssetWaitSeconds = 8,
	WorldDressingWaitSeconds = 8,
	FieldSpecs = table.freeze({
		frontier = table.freeze({
			count = 5,
			assetIds = table.freeze({
				"prop.rock.a",
				"prop.vegetation.a",
				"prop.debris.a",
			}),
		}),
		corruption = table.freeze({
			count = 4,
			assetIds = table.freeze({
				"prop.vegetation.a",
				"prop.debris.a",
				"prop.barrel.a",
			}),
		}),
		industry = table.freeze({
			count = 5,
			assetIds = table.freeze({
				"prop.pipe.a",
				"prop.sign.a",
				"prop.broken_machinery.a",
				"prop.barrel.a",
				"prop.lamp.a",
			}),
		}),
		camp = table.freeze({
			count = 4,
			assetIds = table.freeze({
				"prop.crate.a",
				"prop.barrel.a",
				"prop.desk.a",
				"prop.debris.a",
				"prop.lamp.a",
			}),
		}),
	}),
}

local total = 0
for _, fieldSpec in Config.FieldSpecs do
	total += fieldSpec.count
end
assert(total == Config.MaximumPropCount, "modular field dressing budget must match configured field counts")
assert(Config.MinimumOffsetStuds < Config.MaximumOffsetStuds, "modular field dressing requires an offset range")

return table.freeze(Config)
