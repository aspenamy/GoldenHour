-------------------------------------------------------------------------------
-- Golden Hour: the settings
--
-- Each page lists console settings (CVars). "beyond" is the Beyond Ultra
-- value from the WoW Forever settings guide and its test sheet. Settings the
-- client doesn't have are skipped, so old ones can stay listed.
--
--   cvar     console name
--   label    shown name
--   tip      one or two plain sentences
--   min, max, step   slider range (Blizzard's default and Beyond are added as stops)
--   stops    exact list of values, instead of a range
--   toggle   a checkbox: { on = value, off = value }
--   beyond   Beyond Ultra value (nil = left alone by the preset)
--   lower    lower numbers look better
--   warn     extra line in red in the tooltip
--   restart  needs a graphics restart to show
-------------------------------------------------------------------------------

local _, ns = ...

ns.PAGES = {
  {
    key = "distance", tab = "Distance", title = "View Distance",
    blurb = "How far the world is drawn, and how far out things keep their detail.",
    settings = {
      { cvar = "farclip", label = "View distance", min = 1000, max = 24000, step = 1000, beyond = 24000,
        tip = "How far away the world is drawn." },
      { cvar = "horizonStart", label = "Horizon detail start", min = 0, max = 24000, step = 1000, beyond = 24000,
        tip = "Where the detailed world hands over to the low-detail horizon.",
        warn = "Very demanding. Lower this first if you lose frame rate." },
      { cvar = "horizonClip", label = "Horizon distance", min = 0, max = 24000, step = 1000, beyond = 10000,
        tip = "How far the low-detail horizon is drawn." },
      { cvar = "terrainLodDist", label = "Terrain detail distance", min = 0, max = 4000, step = 100, beyond = 2000,
        tip = "How far out the ground keeps its full shape.",
        warn = "Very demanding together with a high horizon start and building detail." },
      { cvar = "wmoLodDist", label = "Building detail distance", min = 0, max = 4000, step = 100, beyond = 2000,
        tip = "How far out buildings and large structures keep their full detail.",
        warn = "Very demanding." },
      { cvar = "entityLodDist", label = "Character detail distance", min = 0, max = 2000, step = 50, beyond = 1000,
        tip = "How far out players, creatures and NPCs keep their full detail." },
      { cvar = "doodadLodScale", label = "Object detail distance", min = 0, max = 300, step = 10, beyond = 150,
        tip = "How far out trees, rocks and props keep their full detail." },
      { cvar = "lodObjectCullDist", label = "Small object distance", min = 1, max = 200, step = 5, beyond = 200,
        tip = "How far out small objects are still drawn." },
      { cvar = "lodObjectCullSize", label = "Small object cutoff", min = 1, max = 100, step = 1, beyond = 1, lower = true,
        tip = "Objects smaller than this are hidden in the distance. Lower shows more of them." },
      { cvar = "lodObjectMinSize", label = "Smallest object kept", min = 0, max = 1000, step = 10, beyond = 0, lower = true,
        tip = "Lower keeps more small objects on screen." },
      { cvar = "lodObjectFadeScale", label = "Object fade distance", min = 50, max = 1000, step = 25, beyond = 300,
        tip = "How far out objects fade in.",
        warn = "Going much past 300 costs a lot of frame rate for little gain." },
      { cvar = "bodyQuota", label = "Characters shown", min = 0, max = 400, step = 10, beyond = 200,
        tip = "How many players and creatures can be drawn at once." },
    },
  },
  {
    key = "ground", tab = "Ground", title = "Ground & Weather",
    blurb = "Grass, flowers and other ground clutter, footprints and weather.",
    settings = {
      { cvar = "groundEffectDensity", label = "Clutter density", min = 16, max = 256, step = 16, beyond = 256,
        tip = "How thick grass, flowers and small ground plants grow." },
      { cvar = "groundEffectDist", label = "Clutter distance", min = 40, max = 500, step = 20, beyond = 500,
        tip = "How far away ground clutter is drawn." },
      { cvar = "groundEffectFade", label = "Clutter fade distance", min = 0, max = 1000, step = 25, beyond = 600,
        tip = "How far out ground clutter fades in." },
      { cvar = "terrainMipLevel", label = "Full-size ground textures", toggle = { on = 0, off = 1 }, beyond = 0,
        tip = "Uses the sharpest version of ground textures." },
      { cvar = "WeatherDensity", label = "Weather", min = 0, max = 3, step = 1, beyond = 3,
        tip = "How much rain, snow and dust you see." },
      { cvar = "physicsLevel", label = "Physics", min = 0, max = 2, step = 1, beyond = 2,
        tip = "Cloth and other physics. 2 includes NPCs as well as you." },
      { cvar = "showfootprints", label = "Footprints", toggle = { on = 1, off = 0 }, beyond = 1,
        tip = "Leaves footprints in sand and snow." },
      { cvar = "showfootprintparticles", label = "Footstep dust", toggle = { on = 1, off = 0 }, beyond = 1,
        tip = "Kicks up little puffs as you walk." },
    },
  },
  {
    key = "shadows", tab = "Shadows", title = "Shadows",
    blurb = "Shadow quality, sharpness and how far out they reach.",
    settings = {
      { cvar = "shadowMode", label = "Shadow quality", min = 0, max = 4, step = 1, beyond = 4,
        tip = "Overall shadow quality." },
      { cvar = "shadowTextureSize", label = "Shadow resolution", stops = { 512, 1024, 2048 }, beyond = 2048, restart = true,
        tip = "Sharpness of shadow edges." },
      { cvar = "shadowNumCascades", label = "Shadow layers", min = 1, max = 4, step = 1, beyond = 4,
        tip = "More layers keep shadows sharp further from the camera." },
      { cvar = "shadowSoft", label = "Soft shadows", toggle = { on = 1, off = 0 }, beyond = 1,
        tip = "Softens shadow edges." },
      { cvar = "shadowBlendCascades", label = "Blend shadow layers", toggle = { on = 1, off = 0 }, beyond = 1,
        tip = "Hides the seam where one shadow layer meets the next." },
      { cvar = "entityShadowFadeScale", label = "Character shadow distance", min = 0, max = 50, step = 1, beyond = 25,
        tip = "How far out players and creatures still cast shadows." },
      { cvar = "SSAO", label = "Ambient occlusion", min = 0, max = 4, step = 1, beyond = 4,
        tip = "Soft contact shadows in corners and under objects." },
    },
  },
  {
    key = "lighting", tab = "Lighting", title = "Lighting & Sky",
    blurb = "Light, fog, clouds, sun shafts, bloom and HDR.",
    settings = {
      { cvar = "giQuality", label = "Global illumination", min = 0, max = 4, step = 1, beyond = 4,
        tip = "Light bouncing off surfaces.",
        warn = "Capped at 4. The client turns 5 back to 0, and higher can crash the game." },
      { cvar = "graphicsLightMode", label = "Lighting quality", min = 0, max = 3, step = 1, beyond = 3,
        tip = "Quality of lights in the world." },
      { cvar = "sunshafts", label = "Sun shafts", min = 0, max = 2, step = 1, beyond = 2,
        tip = "Rays of light through trees and clouds." },
      { cvar = "volumeFogLevel", label = "Volumetric fog", min = 0, max = 4, step = 1, beyond = 4,
        tip = "Quality of fog and light in the air." },
      { cvar = "SkyCloudLOD", label = "Cloud detail", min = 0, max = 3, step = 1, beyond = 3,
        tip = "Detail of the clouds in the sky." },
      { cvar = "graphicsDepthEffects", label = "Depth effects", min = 0, max = 3, step = 1, beyond = 3,
        tip = "Depth of field and other depth-based effects." },
      { cvar = "graphicsBloomUserMult", label = "Bloom", toggle = { on = 1, off = 0 }, beyond = 1,
        tip = "A soft glow around bright light." },
      { cvar = "projectedTextures", label = "Projected textures", toggle = { on = 1, off = 0 }, beyond = 1,
        tip = "Spell circles and other effects drawn onto the ground." },
      { cvar = "HDROutput", label = "HDR", toggle = { on = 1, off = 0 }, restart = true,
        tip = "High dynamic range output. Only turn this on with an HDR monitor and HDR switched on in Windows.",
        warn = "Not part of the Beyond Ultra preset." },
      { cvar = "HDRFactor", label = "HDR brightness", min = 0.5, max = 3, step = 0.1,
        tip = "How bright HDR highlights are. The guide uses 1.3." },
    },
  },
  {
    key = "effects", tab = "Effects", title = "Effects & Water",
    blurb = "Spells, particles, water and outlines.",
    settings = {
      { cvar = "graphicsComputeEffects", label = "Compute effects", min = 0, max = 4, step = 1, beyond = 4,
        tip = "Quality of effects run on the graphics card." },
      { cvar = "graphicsSpellDensity", label = "Spell density", min = 0, max = 2, step = 1, beyond = 2,
        tip = "How many spell effects are shown." },
      { cvar = "spellClutter", label = "Spell clutter", min = 0, max = 4, step = 1, beyond = 2,
        tip = "Spell effect clutter. The guide's tests settled on 2." },
      { cvar = "spellVisualDensityFilterSetting", label = "Spell visual filter", min = 0, max = 2, step = 1, beyond = 2,
        tip = "How much other players' spell effects are trimmed. Higher shows more." },
      { cvar = "particleDensity", label = "Particle density", min = 10, max = 100, step = 10, stopsExtra = { 100.99 }, beyond = 100.99,
        tip = "How many particles effects use. 100.99 is the top value the client takes." },
      { cvar = "particleMTDensity", label = "Particle density (threaded)", min = 10, max = 100, step = 10, stopsExtra = { 100.99 }, beyond = 100.99,
        tip = "The same, for particles worked out on extra CPU threads." },
      { cvar = "pbrLiquidDetail", label = "Liquid detail", min = 0, max = 2, step = 1, beyond = 2,
        tip = "Quality of water, lava and other liquids." },
      { cvar = "waterDetail", label = "Water detail", min = 0, max = 2, step = 1, beyond = 2,
        tip = "Quality of water surfaces.",
        warn = "Capped at 2. 3 has crashed the game in Dalaran." },
      { cvar = "rippleDetail", label = "Ripples", min = 0, max = 2, step = 1, beyond = 2,
        tip = "Ripples in water as you move through it." },
      { cvar = "reflectionMode", label = "Reflections", min = 0, max = 3, step = 1, beyond = 3,
        tip = "What water reflects.",
        warn = "Capped at 3. 4 has crashed the game in the Ruins of Lordaeron." },
      { cvar = "refraction", label = "Refraction", min = 0, max = 2, step = 1, beyond = 2,
        tip = "Light bending through water and heat haze." },
      { cvar = "OutlineEngineMode", label = "Outlines", min = 0, max = 2, step = 1, beyond = 2,
        tip = "Outlines around targets and objects you can use." },
    },
  },
  {
    key = "textures", tab = "Textures", title = "Textures & Loading",
    blurb = "Character texture sharpness and how fast models and textures load.",
    settings = {
      { cvar = "componentTextureLevel", label = "Character texture level", min = 0, max = 2, step = 1, beyond = 0, lower = true,
        tip = "Lower is sharper." },
      { cvar = "componentCompress", label = "Uncompressed character textures", toggle = { on = 0, off = 1 }, beyond = 0,
        tip = "Skips compressing character textures, so they stay sharper." },
      { cvar = "componentEmissive", label = "Glowing gear", toggle = { on = 1, off = 0 }, beyond = 1,
        tip = "Glowing parts on armor and weapons." },
      { cvar = "componentSpecular", label = "Shiny gear", toggle = { on = 1, off = 0 }, beyond = 1,
        tip = "Shine on metal and other armor." },
      { cvar = "componentTexCacheSize", label = "Texture cache", min = 0, max = 2048, step = 64, beyond = 1024,
        tip = "Memory kept for character textures." },
      { cvar = "componentTexLoadLimit", label = "Texture load limit", min = 0, max = 128, step = 4, beyond = 48,
        tip = "How many character textures load at once." },
      { cvar = "componentThread", label = "Texture threads", min = 0, max = 16, step = 1, beyond = 12,
        tip = "CPU threads used to build character textures." },
      { cvar = "M2UseThreads", label = "Model threads", min = 0, max = 8, step = 1, beyond = 3,
        tip = "CPU threads used for models." },
    },
  },
}

-- Midrange: for a strong graphics card with a mid-range CPU. WoW leans on the CPU, so
-- view distance and character counts stay moderate, while shadows, light,
-- water and textures go high. Settings not listed are left alone.
ns.MIDRANGE = {
  -- Distance
  farclip = 12000, horizonStart = 6000, horizonClip = 10000,
  terrainLodDist = 1000, wmoLodDist = 1000, entityLodDist = 600,
  doodadLodScale = 150, lodObjectCullDist = 200, lodObjectCullSize = 10,
  lodObjectMinSize = 10, lodObjectFadeScale = 200, bodyQuota = 150,
  -- Ground
  groundEffectDensity = 256, groundEffectDist = 320, groundEffectFade = 400,
  terrainMipLevel = 0, WeatherDensity = 3, physicsLevel = 2,
  showfootprints = 1, showfootprintparticles = 1,
  -- Shadows
  shadowMode = 4, shadowTextureSize = 2048, shadowNumCascades = 4, shadowSoft = 1,
  shadowBlendCascades = 1, entityShadowFadeScale = 15, SSAO = 3,
  -- Lighting
  giQuality = 3, graphicsLightMode = 3, sunshafts = 2, volumeFogLevel = 3,
  SkyCloudLOD = 3, graphicsDepthEffects = 3, graphicsBloomUserMult = 1, projectedTextures = 1,
  -- Effects and water
  graphicsComputeEffects = 4, particleDensity = 100, particleMTDensity = 100,
  pbrLiquidDetail = 2, waterDetail = 2, rippleDetail = 2, reflectionMode = 2,
  refraction = 2, OutlineEngineMode = 2,
  -- Textures
  componentTextureLevel = 0, componentCompress = 0, componentEmissive = 1, componentSpecular = 1,
  componentTexCacheSize = 1024, componentTexLoadLimit = 48, componentThread = 6, M2UseThreads = 3,
}

-- Lite: for laptops and older PCs. Shorter view distance and simpler
-- shadows, light and water, easier on both the CPU and the graphics card.
-- Settings not listed are left alone.
ns.LITE = {
  -- Distance
  farclip = 3000, horizonStart = 1000, horizonClip = 4000,
  terrainLodDist = 300, wmoLodDist = 300, entityLodDist = 200,
  doodadLodScale = 80, lodObjectFadeScale = 100, bodyQuota = 80,
  -- Ground
  groundEffectDensity = 64, groundEffectDist = 120, groundEffectFade = 100,
  WeatherDensity = 1, physicsLevel = 1,
  -- Shadows
  shadowMode = 1, shadowTextureSize = 1024, shadowNumCascades = 2, shadowSoft = 0,
  entityShadowFadeScale = 5, SSAO = 0,
  -- Lighting
  giQuality = 0, graphicsLightMode = 1, sunshafts = 0, volumeFogLevel = 1,
  SkyCloudLOD = 1, graphicsDepthEffects = 1,
  -- Effects and water
  graphicsComputeEffects = 1, particleDensity = 50, particleMTDensity = 50,
  pbrLiquidDetail = 1, waterDetail = 1, rippleDetail = 0, reflectionMode = 0, refraction = 0,
  -- Textures
  componentTextureLevel = 1,
}

-- The loot sparkle: quest items sparkle instead of only getting an outline.
ns.SPARKLE_CVAR = "outlineModeShowLootEffectWhenDisabled"

-- Blizzard's graphics quality sliders. Moving them resets many of the
-- settings above, and turns the loot sparkle off.
ns.QUALITY_CVARS = { graphicsquality = true, raidgraphicsquality = true }
