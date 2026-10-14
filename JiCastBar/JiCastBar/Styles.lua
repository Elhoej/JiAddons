local _, ns = ...

-- The ten styles of Elva's cast bar WeakAuras (wago.io/xeJOxehA8), generated
-- from each aura's export. Every style shares one layout (ns.LAYOUT); they
-- differ in fill, background, spark and spell models.
--
--   texture     "solid" (flat), "dground" (Details!' flat grey bar, see
--               SHADE) or "gradient" (an unknown LibSharedMedia texture, drawn flat)
--   color       fill colour; with color2 the fill is a left-to-right gradient
--               across the whole bar that the progress reveals
--   background  rgba behind the fill
--   spark       texture (file ID or atlas), colour, size; drawn with ADD blending
--   nameX/Y     offset of the spell name
--   models      spell models over the bar (WeakAuras' "submodel"):
--     attach    clip to the filled part of the bar (else the whole bar)
--     stretch   size the model to the filled part (else the whole bar), so it
--               moves and grows with the progress
--     position  { x, y, z } for Model:SetPosition(z, x, y) and facing in degrees, or
--     transform { tx, ty, tz, rx, ry, rz, scale } in WeakAuras' units
--               (thousandths and degrees) for Model:SetTransform

ns.LAYOUT = {
    width = 280,      -- default width, icon included (each bar has its own)
    height = 28,      -- default height, also the icon's width
    border = 2,       -- black, drawn inside the edge, around icon and bar
    iconZoom = 0.075, -- WeakAuras' zoom 0.3 trims 7.5% off each side
    fontSize = 12,
    timeColor = { 0.953, 0.965, 1 },
}

-- Details!' "DGround" bar is a flat 175/255 grey, so it darkens the colour.
ns.SHADE = { solid = 1, dground = 175 / 255, gradient = 1 }

ns.STYLES = {
    { key = "sunset", name = "Sunset", wago = "YvE6OQvhQ",
        texture = "solid", color = { 0.808, 0.349, 0.965 }, color2 = { 1, 0.91, 0 },
        background = { 0, 0, 0, 0.7 },
        spark = { texture = 130877, color = { 1, 0.882, 0 }, width = 5, height = 50 },
        nameX = 4, nameY = -1,
        models = {
            { file = 166594, alpha = 1, attach = true, stretch = true, position = { 0, -0.6, 2.55 }, facing = 0 },
        },
    },
    { key = "void", name = "Void", wago = "5xziQvVrN",
        texture = "dground", color = { 0.675, 0.475, 1 }, color2 = { 0.09, 0.09, 0.09 },
        background = { 0, 0, 0, 0.701 },
        nameX = 2, nameY = -1,
        models = {
            { file = 166784, alpha = 0.9, attach = true, stretch = false, transform = { 35, 50, -288, 141, 128, 72, 55 } },
        },
    },
    { key = "celestial", name = "Celestial", wago = "e7OWqrrSx",
        texture = "solid", color = { 0, 0.651, 0.918 }, color2 = { 0, 0, 0 },
        background = { 0, 0, 0, 0.701 },
        nameX = 4, nameY = -2,
        models = {
            { file = 165829, alpha = 1, attach = true, stretch = true, position = { 0.15, -0.1, 0.2 }, facing = 0 },
        },
    },
    { key = "flux", name = "Flux", wago = "vrADoIkLX",
        texture = "solid", color = { 0.408, 0.224, 0.725 }, color2 = { 0.631, 0.439, 1 },
        background = { 0, 0, 0, 0.71 },
        spark = { texture = 130877, color = { 1, 0.882, 0 }, width = 5, height = 50 },
        nameX = 4, nameY = -1,
        models = {
            { file = 166784, alpha = 1, attach = true, stretch = true, transform = { 45, 50, 0, 141, 128, 72, 81 } },
            { file = 165693, alpha = 1, attach = true, stretch = false, position = { 0, 0, 0 }, facing = 38.1 },
        },
    },
    { key = "nebula", name = "Nebula", wago = "9dTTb_PrA",
        texture = "dground", color = { 0.231, 0.882, 1 }, color2 = { 0, 0.506, 1 },
        background = { 0, 0.02, 0.271, 0.709 },
        spark = { texture = "bonusobjectives-bar-spark", color = { 0, 0.941, 1 }, width = 40, height = 50 },
        nameX = 4, nameY = -1,
        models = {
            { file = 130629, alpha = 1, attach = false, stretch = false, transform = { 78, -72, 113, 169, 0, 0, 5 } },
            { file = 166594, alpha = 1, attach = true, stretch = true, position = { 0, -1.25, 0.85 }, facing = 0 },
        },
    },
    { key = "fel", name = "Fel", wago = "YWaNciV4v",
        texture = "gradient", color = { 0.427, 1, 0 },
        background = { 0.031, 0.169, 0, 0.75 },
        spark = { texture = "XPBarAnim-OrangeSpark", color = { 0.016, 0.318, 0 }, width = 100, height = 60 },
        nameX = 4, nameY = -1,
        models = {
            { file = 130629, alpha = 1, attach = false, stretch = false, transform = { 78, -72, 113, 169, 0, 0, 5 } },
            { file = 130629, alpha = 0.8, attach = true, stretch = false, position = { 0, 0, 0 }, facing = 0 },
        },
    },
    { key = "ember", name = "Ember", wago = "rG6nr7nWU",
        texture = "solid", color = { 1, 0.184, 0 }, color2 = { 1, 0.91, 0 },
        background = { 0, 0, 0, 0.701 },
        spark = { texture = 130877, color = { 1, 0.882, 0 }, width = 5, height = 50 },
        nameX = 4, nameY = -1,
        models = {
            { file = 166112, alpha = 1, attach = true, stretch = true, position = { 0, 1.3, 4 }, facing = 0 },
        },
    },
    { key = "galaxy", name = "Galaxy", wago = "Uos2_REtN",
        texture = "solid", color = { 0.475, 0.302, 0.925 }, color2 = { 0, 0, 0 },
        background = { 0, 0, 0, 0.701 },
        nameX = 4, nameY = -2,
        models = {
            { file = 165829, alpha = 1, attach = true, stretch = true, position = { 0.15, -0.1, 0.2 }, facing = 0 },
        },
    },
    { key = "sage", name = "Sage", wago = "WvUzCLRuc",
        texture = "solid", color = { 0, 0.667, 0.125 },
        background = { 0, 0, 0, 0.709 },
        nameX = 4, nameY = -1,
        models = {
            { file = 166694, alpha = 1, attach = true, stretch = true, position = { 0, 0, 2.4 }, facing = 0 },
        },
    },
    { key = "astral", name = "Astral", wago = "mNJRj47pM",
        texture = "dground", color = { 0.478, 0.153, 0.867 },
        background = { 0, 0, 0, 0.701 },
        spark = { texture = "bonusobjectives-bar-spark", color = { 1, 0, 0.82 }, width = 40, height = 40 },
        nameX = 4, nameY = -1,
        models = {
            { file = 165821, alpha = 0.8, attach = true, stretch = true, position = { 0, 0.25, 2 }, facing = 0 },
            { file = 130629, alpha = 0.4, attach = false, stretch = false, position = { 0, 0, 0 }, facing = 56 },
        },
    },
}

ns.STYLE_BY_KEY = {}
for i, style in ipairs(ns.STYLES) do
    style.index = i
    ns.STYLE_BY_KEY[style.key] = style
end
