----------------------------------------------------------------------------------------
-- Text Format Vars
-- (HP/MP text and status bars)
-- $miss = Missing hp/mp
-- $cur = current hp/mp
-- $max = Max hp/mp
-- $perc = Percent hp/mp
--
-- (Name/Level text)
-- $name = Name
-- $level = Level
-- $class = Class
-- $guild = Guild
-- $race = Race
-- $rname = PvP Rank Name
-- $rnum = PvP Rank Number
-- $key = Key Binding
--
-- Element Names
-- hp, mp, xp, combo, target
-- name, level, class, race
-- pvp, leader, master, feedback
-- group, status, buff, debuff
-- raidtarget, highlight, pet, portrait
--
-- StatusBar Animations
-- glide
----------------------------------------------------------------------------------------

function Nurfed_HealthPercColor(perc)
	local color = {};
	if(perc > 0.6) then
		color.r = (0/255);
		color.g = (255/255);
		color.b = (0/255);
	else
		if(perc > 0.2) then
			color.r = (( 255+((0.6-perc)*100*(128/40)))/255);
			color.g = ((204+((0.6-perc)*100*(-89/40)))/255);
			color.b = ((1+((0.6-perc)*100*(-136/40)))/255);
		else
			color.r = (206/255);
			color.g = (17/255);
			color.b = (17/255);
		end
	end
	return color;
end

ManaBarColor[0] = { r = 0/255, g = 255/255, b = 255/255, prefix = TEXT(MANA) };	-- mana
-- ManaBarColor[0] = { r = 0/255, g = 96/255, b = 255/255, prefix = TEXT(MANA) };	-- mana
ManaBarColor[1] = { r = 255/255, g = 0/255, b = 0/255, prefix = TEXT(MANA) };	-- rage
ManaBarColor[2] = { r = 255/255, g = 178/255, b = 0, prefix = TEXT(MANA) };	-- focus
ManaBarColor[3] = { r = 1.00, g = 1.00, b = 34/255, prefix = TEXT(MANA) };	-- energy
ManaBarColor[4] = { r = 0.00, g = 1.00, b = 1.00, prefix = TEXT(MANA) };	

if (not Nurfed_UnitsLayout) then

	Nurfed_UnitsLayout = {};

	Nurfed_UnitsLayout.Name = "Default Nurfed UnitFrames";
	Nurfed_UnitsLayout.Author = "Tivoli";

	--Frame Templates
	Nurfed_UnitsLayout.templates = {
		Nurfed_UnitFont = {
			type = "Font",
			Font = { NRF_FONT.."framd.ttf", 10, "NONE" },
			TextColor = { 1, 1, 1 },
		},
		Nurfed_UnitFontOutline = {
			type = "Font",
			Font = { NRF_FONT.."framd.ttf", 10, "OUTLINE" },
			TextColor = { 1, 1, 1 },
		},
		Nurfed_UnitFontSmall = {
			type = "Font",
			Font = { NRF_FONT.."framd.ttf", 8, "NONE" },
			TextColor = { 1, 1, 1 },
		},
		Nurfed_UnitFontSmallOutline = {
			type = "Font",
			Font = { NRF_FONT.."framd.ttf", 8, "OUTLINE" },
			TextColor = { 1, 1, 1 },
		},
		Nurfed_CountFontOutline = {
			type = "Font",
			Font = { "Fonts\\ARIALN.TTF", 12, "OUTLINE" },
			TextColor = { 1, 1, 1 },
		},
		Nurfed_Unit_hp = {
			type = "StatusBar",
			FrameStrata = "LOW",
			Orientation = "HORIZONTAL",
			StatusBarTexture = NRF_IMG.."statusbar6",
			children = {
				bg = {
					type = "Texture",
					layer = "BACKGROUND",
					Texture = NRF_IMG.."statusbar6",
					VertexColor = { 1, 0, 0, 0.25 },
					Anchor = "all",
				},
				text = {
					type = "FontString",
					layer = "OVERLAY",
					FontObject = "Nurfed_UnitFont",
					JustifyH = "LEFT",
					ShadowColor = { 0, 0, 0, 0.75},
					ShadowOffset = { -1, -1 },
					Anchor = "all",
					vars = { format = "$cur ($max)" },
				},
				text2 = {
					type = "FontString",
					layer = "OVERLAY",
					FontObject = "Nurfed_UnitFontOutline",
					JustifyH = "RIGHT",
					TextColor = { 1, 0.25, 0 },
					Anchor = "all",
					vars = { format = "$miss" },
				},
			},
			vars = { ani = "glide" },
		},

		Nurfed_Unit_mp = {
			type = "StatusBar",
			FrameStrata = "LOW",
			Orientation = "HORIZONTAL",
			StatusBarTexture = NRF_IMG.."statusbar6",
			children = {
				bg = {
					type = "Texture",
					layer = "BACKGROUND",
					Texture = NRF_IMG.."statusbar6",
					VertexColor = { 0, 1, 1, 0.25 },
					Anchor = "all",
				},
				text = {
					type = "FontString",
					layer = "OVERLAY",
					FontObject = "Nurfed_UnitFont",
					JustifyH = "LEFT",
					ShadowColor = { 0, 0, 0, 0.75 },
					ShadowOffset = { -1, -1 },
					Anchor = "all",
					vars = { format = "$cur ($max)" },
				},
			},
			vars = { ani = "glide" },
		},

		Nurfed_Unit_xp = {
			type = "StatusBar",
			strata = "LOW",
			Orientation = "HORIZONTAL",
			StatusBarTexture = NRF_IMG.."statusbar5",
			children = {
				bg = {
					type = "Texture",
					layer = "BACKGROUND",
					Texture = NRF_IMG.."statusbar5",
					VertexColor = { 0, 0, 1, 0.25 },
					Anchor = "all",
				},
				text = {
					type = "FontString",
					layer = "OVERLAY",
					FontObject = "Nurfed_UnitFontSmall",
					JustifyH = "CENTER",
					ShadowColor = { 0, 0, 0, 0.75 },
					ShadowOffset = { -1, -1 },
					Anchor = "all",
					vars = { format = "$cur/$max ($rest)" },
				},
				text2 = {
					type = "FontString",
					layer = "OVERLAY",
					FontObject = "Nurfed_UnitFontSmall",
					JustifyH = "RIGHT",
					ShadowColor = { 0, 0, 0, 0.75 },
					ShadowOffset = { -1, -1 },
					Anchor = "all",
					vars = { format = "$perc" },
				}
			},
		},

		Nurfed_Unit_model = {
			type = "PlayerModel",
			size = { 43, 43 },
			FrameStrata = "LOW",
			ModelScale = 1.9,
			Camera = 0,
			FrameLevel = 1,
		},

		Nurfed_Unit_mini = {
			type = "Button",
			size = { 80, 22 },
			FrameStrata = "LOW",
			Backdrop = {
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true,
				tileSize = 16,
				edgeSize = 8,
				insets = { left = 2, right = 2, top = 2, bottom = 2 }
			},
			BackdropColor = { 0, 0, 0, 0.75 },
			BackdropBorderColor = { 0, 0, 0, 1 },
			children = {
				hp = {
					type = "StatusBar",
					size = { 74, 9 },
					FrameStrata = "LOW",
					Orientation = "HORIZONTAL",
					StatusBarTexture = NRF_IMG.."statusbar6",
					Anchor = { "BOTTOMLEFT", "$parent", "BOTTOMLEFT", 3, 3 },
					children = {
						bg = {
							type = "Texture",
							layer = "BACKGROUND",
							Texture = NRF_IMG.."statusbar6",
							VertexColor = { 1, 0, 0, 0.25 },
							Anchor = "all",
						},
						text = {
							type = "FontString",
							layer = "OVERLAY",
--							FontObject = "Nurfed_UnitFontSmallOutline",
							FontObject = "Nurfed_UnitFontSmall",
							JustifyH = "RIGHT",
--							TextColor = { 1, 0.25, 0 },
							ShadowColor = { 0, 0, 0, 0.75 },
							ShadowOffset = { -1, -1 },
							Anchor = "all",
							vars = { format = "$perc" },
						},
					},
				},
				name = {
					type = "FontString",
					size = { 75, 8 },
					layer = "OVERLAY",
					FontObject = "Nurfed_UnitFontSmall",
					JustifyH = "LEFT",
					ShadowColor = { 0, 0, 0, 0.75 },
					ShadowOffset = { -1, -1 },
					Anchor = { "TOPLEFT", "$parent", "TOPLEFT", 3, -2 },
					vars = { format = "$name" },
				},
			},
			Hide = true,
		},

		Nurfed_Party = {
			type = "Button",
			size = { 190, 41 },
			FrameStrata = "LOW",
			ClampedToScreen = true,
			Backdrop = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 }, },
			BackdropColor = { 0, 0, 0, 0.75 },
			BackdropBorderColor = { 0, 0, 0, 1 },
			Movable = true,
			Mouse = true,
			children = {
				hp = {
					template = "Nurfed_Unit_hp",
					size = { 157, 12 },
					Anchor = { "BOTTOMRIGHT", "$parent", "BOTTOMRIGHT", -5, 14 },
				},
				mp = {
					template = "Nurfed_Unit_mp",
					size = { 157, 8 },
					Anchor = { "BOTTOMRIGHT", "$parent", "BOTTOMRIGHT", -5, 5 },
				},
				buff1 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "TOPLEFT", "$parent", "BOTTOMLEFT", 4, 2 } },
				buff2 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff1", "RIGHT", 0, 0 } },
				buff3 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff2", "RIGHT", 0, 0 } },
				buff4 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff3", "RIGHT", 0, 0 } },
				buff5 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff4", "RIGHT", 0, 0 } },
				buff6 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff5", "RIGHT", 0, 0 } },
				buff7 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff6", "RIGHT", 0, 0 } },
				buff8 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff7", "RIGHT", 0, 0 } },
				buff9 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff8", "RIGHT", 0, 0 } },
				buff10 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff9", "RIGHT", 0, 0 } },
				buff11 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff10", "RIGHT", 0, 0 } },
				buff12 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff11", "RIGHT", 0, 0 } },
				buff13 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff12", "RIGHT", 0, 0 } },
				buff14 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff13", "RIGHT", 0, 0 } },
				buff15 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff14", "RIGHT", 0, 0 } },
				buff16 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff15", "RIGHT", 0, 0 } },
				buff17 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "TOPLEFT", "$parentbuff1", "BOTTOMLEFT", 0, 0 } },
				buff18 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff17", "RIGHT", 0, 0 } },
				buff19 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff18", "RIGHT", 0, 0 } },
				buff20 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff19", "RIGHT", 0, 0 } },
				buff21 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff20", "RIGHT", 0, 0 } },
				buff22 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff21", "RIGHT", 0, 0 } },
				buff23 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff22", "RIGHT", 0, 0 } },
				buff24 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff23", "RIGHT", 0, 0 } },
				buff25 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff24", "RIGHT", 0, 0 } },
				buff26 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff25", "RIGHT", 0, 0 } },
				buff27 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff26", "RIGHT", 0, 0 } },
				buff28 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff27", "RIGHT", 0, 0 } },
				buff29 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff28", "RIGHT", 0, 0 } },
				buff30 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff29", "RIGHT", 0, 0 } },
				buff31 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff30", "RIGHT", 0, 0 } },
				buff32 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff31", "RIGHT", 0, 0 } },
				debuff1 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "TOPLEFT", "$parent", "TOPRIGHT", -3, -2 } },
				debuff2 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff1", "RIGHT", 1, 0 } },
				debuff3 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff2", "RIGHT", 1, 0 } },
				debuff4 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff3", "RIGHT", 1, 0 } },
				classicon = {
					type = "Texture",
					size = { 23, 23 },
					layer = "OVERLAY",
					Texture = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes",
					Anchor = { "TOPLEFT", "$parent", "TOPLEFT", 5, -4 },
				},
				highlight = {
					type = "Texture",
					size = { 130, 12 },
					layer = "ARTWORK",
					Texture = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
					BlendMode = "ADD",
					Anchor = { "TOPRIGHT", "$parent", "TOPRIGHT", -5, -4 },
					Hide = true,
				},
				leader = {
					type = "Texture",
					size = { 12, 13 },
					layer = "OVERLAY",
					Texture = "Interface\\GroupFrame\\UI-Group-LeaderIcon",
					Anchor = { "TOPLEFT", "$parent", "TOPLEFT", 5, -25 },
				},
				master = {
					type = "Texture",
					size = { 11, 11 },
					layer = "OVERLAY",
					Texture = "Interface\\GroupFrame\\UI-Group-MasterLooter",
					Anchor = { "TOPLEFT", "$parent", "TOPLEFT", 16, -26 },
				},
				pvp = {
					type = "Texture",
					size = { 20, 20 },
					layer = "OVERLAY",
					Anchor = { "TOPRIGHT", "$parent", "TOPRIGHT", 4, -4 },
				},
				name = {
					type = "FontString",
					size = { 140, 10 },
					layer = "OVERLAY",
					FontObject = "Nurfed_UnitFont",
					JustifyH = "LEFT",
					Anchor = { "TOPLEFT", "$parent", "TOPLEFT", 28, -4 },
					vars = { format = "[$key] $name" },
				},
				hpperc = {
					type = "FontString",
					layer = "OVERLAY",
					FontObject = "Nurfed_UnitFontOutline",
					JustifyH = "RIGHT",
					Anchor = { "TOPRIGHT", "$parent", "TOPRIGHT", -15, -5 },
					vars = { format = "$perc" },
				},
				pet = {
					template = "Nurfed_Unit_mini",
					Anchor = { "BOTTOMLEFT", "$parent", "BOTTOMRIGHT", -4, 2 },
				},
			},
			vars = { aurawidth = 221, aurasize = 16 },
		},
	};
	Nurfed_UnitsLayout.Layout = {
		player = {
			type = "Button",
			size = { 200, 60 },
			FrameStrata = "LOW",
			ClampedToScreen = true,
			Backdrop = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 }, },
			BackdropColor = { 0, 0, 0, 0.75 },
			BackdropBorderColor = { 0, 0, 0, 1 },
			Movable = true,
			Mouse = true,
			children = {
				hp = {
					template = "Nurfed_Unit_hp",
					size = { 150, 23 },
					Anchor = { "BOTTOMRIGHT", "$parent", "BOTTOMRIGHT", -5, 16 },
				},
				mp = {
					template = "Nurfed_Unit_mp",
					size = { 150, 10 },
					Anchor = { "BOTTOMRIGHT", "$parent", "BOTTOMRIGHT", -5, 5 },
				},
--[[				xp = {
					template = "Nurfed_Unit_xp",
					size = { 170, 8 },
					Anchor = { "BOTTOMRIGHT", "$parent", "BOTTOMRIGHT", -5, 5 },
				},]]--
				model = {
					template = "Nurfed_Unit_model",
					Anchor = { "BOTTOMLEFT", "$parent", "BOTTOMLEFT", 5, 4 },
				},
				rank = {
					type = "Texture",
					size = { 17, 17 },
					layer = "OVERLAY",
					Anchor = { "TOPRIGHT", "$parent", "TOPRIGHT", -23, -4 },
					Hide = true,
				},
				status = {
					type = "Texture",
					size = { 20, 20 },
					layer = "OVERLAY",
					Texture = "Interface\\CharacterFrame\\UI-StateIcon",
					Anchor = { "TOPRIGHT", "$parent", "TOPRIGHT", -39, -3 },
					Hide = true,
				},
				pvp = {
					type = "Texture",
					size = { 28, 28 },
					layer = "OVERLAY",
					Anchor = { "TOPRIGHT", "$parent", "TOPRIGHT", 5, -4 },
					Hide = true,
				},
				leader = {
					type = "Texture",
					size = { 10, 10 },
					layer = "OVERLAY",
					Texture = "Interface\\GroupFrame\\UI-Group-LeaderIcon",
					Anchor = { "TOP", "$parent", "TOP", 28, -4 },
					Hide = true,
				},
				master = {
					type = "Texture",
					size = { 9, 9 },
					layer = "OVERLAY",
					Texture = "Interface\\GroupFrame\\UI-Group-MasterLooter",
					Anchor = { "TOP", "$parent", "TOP", 28, -12 },
					Hide = true,
				},
				name = {
					type = "FontString",
					size = { 65, 9 },
					layer = "OVERLAY",
					FontObject = "Nurfed_UnitFont",
					JustifyH = "LEFT",
					Anchor = { "TOPLEFT", "$parent", "TOPLEFT", 45, -4 },
					vars = { format = "$name" },
				},
				level = {
					type = "FontString",
					size = { 20, 10 },
					layer = "OVERLAY",
					FontObject = "Nurfed_UnitFont",
					JustifyH = "RIGHT",
					Anchor = { "TOP", "$parent", "TOP", 10, -5 },
					vars = { format = "$level" },
				},
				group = {
					type = "FontString",
					size = { 50, 8 },
					layer = "OVERLAY",
					FontObject = "Nurfed_UnitFontSmall",
					JustifyH = "LEFT",
					Anchor = { "TOPLEFT", "$parent", "TOPLEFT", 45, -13 },
				},
				feedbackheal = {
					type = "MessageFrame",
					layer = "OVERLAY",
					size = { 110, 11 },
					FontObject = "Nurfed_UnitFontOutline",
					JustifyH = "LEFT",
					InsertMode = "BOTTOM",
					Anchor = { "BOTTOMLEFT", "$parent", "BOTTOMLEFT", 5, 4 },
					FadeDuration = 0.5,
					TimeVisible = 1,
					vars = { heal = true },
				},
				feedbackdamage = {
					type = "MessageFrame",
					layer = "OVERLAY",
					size = { 110, 11 },
					FontObject = "Nurfed_UnitFontOutline",
					JustifyH = "LEFT",
					InsertMode = "TOP",
					Anchor = { "TOPLEFT", "$parent", "TOPLEFT", 5, -5 },
					FadeDuration = 0.5,
					TimeVisible = 1,
					vars = { damage = true },
				},
			},
		},

		target = {
			type = "Button",
			size = { 200, 50 },
			FrameStrata = "LOW",
			ClampedToScreen = true,
			Backdrop = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 }, },
			BackdropColor = { 0, 0, 0, 0.75 },
			BackdropBorderColor = { 0, 0, 0, 1 },
			Movable = true,
			Mouse = true,
			children = {
				hp = {
					template = "Nurfed_Unit_hp",
					size = { 150, 13 },
					Anchor = { "BOTTOMLEFT", "$parent", "BOTTOMLEFT", 5, 16 },
				},
				mp = {
					template = "Nurfed_Unit_mp",
					size = { 150, 10 },
					Anchor = { "BOTTOMLEFT", "$parent", "BOTTOMLEFT", 5, 5 },
				},
				model = {
					template = "Nurfed_Unit_model",
					size = { 43, 43 },
					Anchor = { "BOTTOMRIGHT", "$parent", "BOTTOMRIGHT", -4, 5 },
				},
				target = { template = "Nurfed_Unit_mini", Anchor = { "TOPLEFT", "$parent", "TOPRIGHT", -4, -3 } },
				targettarget = { template = "Nurfed_Unit_mini", Anchor = { "BOTTOMLEFT", "$parent", "BOTTOMRIGHT", -4, 3 } },
				buff1 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "TOPLEFT", "$parent", "BOTTOMLEFT", 4, 2 } },
				buff2 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff1", "RIGHT", 0, 0 } },
				buff3 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff2", "RIGHT", 0, 0 } },
				buff4 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff3", "RIGHT", 0, 0 } },
				buff5 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff4", "RIGHT", 0, 0 } },
				buff6 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff5", "RIGHT", 0, 0 } },
				buff7 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff6", "RIGHT", 0, 0 } },
				buff8 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff7", "RIGHT", 0, 0 } },
				buff9 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff8", "RIGHT", 0, 0 } },
				buff10 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff9", "RIGHT", 0, 0 } },
				buff11 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff10", "RIGHT", 0, 0 } },
				buff12 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff11", "RIGHT", 0, 0 } },
				buff13 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff12", "RIGHT", 0, 0 } },
				buff14 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff13", "RIGHT", 0, 0 } },
				buff15 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff14", "RIGHT", 0, 0 } },
				buff16 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff15", "RIGHT", 0, 0 } },
				buff17 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "TOPLEFT", "$parentbuff1", "BOTTOMLEFT", 0, 0 } },
				buff18 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff17", "RIGHT", 0, 0 } },
				buff19 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff18", "RIGHT", 0, 0 } },
				buff20 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff19", "RIGHT", 0, 0 } },
				buff21 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff20", "RIGHT", 0, 0 } },
				buff22 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff21", "RIGHT", 0, 0 } },
				buff23 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff22", "RIGHT", 0, 0 } },
				buff24 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff23", "RIGHT", 0, 0 } },
				buff25 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff24", "RIGHT", 0, 0 } },
				buff26 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff25", "RIGHT", 0, 0 } },
				buff27 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff26", "RIGHT", 0, 0 } },
				buff28 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff27", "RIGHT", 0, 0 } },
				buff29 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff28", "RIGHT", 0, 0 } },
				buff30 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff29", "RIGHT", 0, 0 } },
				buff31 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff30", "RIGHT", 0, 0 } },
				buff32 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff31", "RIGHT", 0, 0 } },
				debuff1 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "TOPLEFT", "$parent", "BOTTOMLEFT", 4, -20 } },
				debuff2 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff1", "RIGHT", 0, 0 } },
				debuff3 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff2", "RIGHT", 0, 0 } },
				debuff4 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff3", "RIGHT", 0, 0 } },
				debuff5 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff4", "RIGHT", 0, 0 } },
				debuff6 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff5", "RIGHT", 0, 0 } },
				debuff7 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff6", "RIGHT", 0, 0 } },
				debuff8 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff7", "RIGHT", 0, 0 } },
				debuff9 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff8", "RIGHT", 0, 0 } },
				debuff10 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff9", "RIGHT", 0, 0 } },
				debuff11 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff10", "RIGHT", 0, 0 } },
				debuff12 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff11", "RIGHT", 0, 0 } },
				debuff13 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff12", "RIGHT", 0, 0 } },
				debuff14 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff13", "RIGHT", 0, 0 } },
				debuff15 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff14", "RIGHT", 0, 0 } },
				debuff16 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff15", "RIGHT", 0, 0 } },
				rank = {
					type = "Texture",
					size = { 20, 20 },
					layer = "OVERLAY",
					Anchor = { "TOPRIGHT", "$parent", "TOPLEFT", 3, -4 },
				},
				pvp = {
					type = "Texture",
					size = { 29, 29 },
					layer = "OVERLAY",
					Anchor = { "TOPRIGHT", "$parent", "TOPRIGHT", -35, -4 },
				},
				name = {
					type = "FontString",
					size = { 110, 9 },
					layer = "OVERLAY",
					FontObject = "Nurfed_UnitFont",
					JustifyH = "LEFT",
					Anchor = { "TOPLEFT", "$parent", "TOPLEFT", 5, -4 },
					vars = { format = "$name $guild" },
					vars = { format = "$name" },
				},
				level = {
					type = "FontString",
					size = { 90, 8 },
					layer = "OVERLAY",
					FontObject = "Nurfed_UnitFontSmall",
					JustifyH = "LEFT",
					Anchor = { "TOPLEFT", "$parent", "TOPLEFT", 5, -13 },
					vars = { format = "$level $class" },
				},
				hpperc = {
					type = "FontString",
					size = { 100, 9 },
					layer = "OVERLAY",
					Font = {NRF_FONT.."framd.ttf", 9, "NONE" },
					JustifyH = "RIGHT",
					Anchor = { "TOPRIGHT", "$parent", "TOPRIGHT", -63, -12 },
					vars = { format = "$perc" },
				},
				combo = {
					type = "FontString",
					layer = "OVERLAY",
					Font = {NRF_FONT.."framd.ttf", 22, "OUTLINE" },
					TextHeight = 22,
					JustifyH = "RIGHT",
					Anchor = { "BOTTOMRIGHT", "$parent", "BOTTOMLEFT", 2, 3 },
				},
				raidtarget = {
					type = "Texture",
					Texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
					size = { 15, 15 },
					layer = "OVERLAY",
					Anchor = { "BOTTOMRIGHT", "$parent", "TOPRIGHT", -5, 0 },
					Hide = true,
				},
			},
			vars = { aurawidth = 221, aurasize = 17 },
		},
		pet = {
			type = "Button",
			size = { 160, 43 },
			FrameStrata = "LOW",
			ClampedToScreen = true,
			Backdrop = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 }, },
			BackdropColor = { 0, 0, 0, 0.75 },
			BackdropBorderColor = { 0, 0, 0, 1 },
			Movable = true,
			Mouse = true,
			children = {
				hp = {
					template = "Nurfed_Unit_hp",
					size = { 150, 12 },
					Anchor = { "BOTTOMRIGHT", "$parent", "BOTTOMRIGHT", -5, 14 },
				},
				mp = {
					template = "Nurfed_Unit_mp",
					size = { 150, 8 },
					Anchor = { "BOTTOMRIGHT", "$parent", "BOTTOMRIGHT", -5, 5 },
				},
				name = {
					type = "FontString",
					size = { 123, 10 },
					layer = "ARTWORK",
					FontObject = "Nurfed_UnitFont",
					JustifyH = "LEFT",
					Anchor = { "TOPLEFT", "$parent", "TOPLEFT", 5, -4 },
					vars = { format = "[$level] $name" },
				},
				hpperc = {
					type = "FontString",
					layer = "OVERLAY",
					Font = { NRF_FONT.."framd.ttf", 9, "OUTLINE" },
					JustifyH = "RIGHT",
					Anchor = { "TOPRIGHT", "$parent", "TOPRIGHT", -5, -5 },
					vars = { format = "$perc" },
				},
				happiness = {
					type = "Texture",
					Texture = "Interface\\PetPaperDollFrame\\UI-PetHappiness",
					size = { 14, 14 },
					layer = "OVERLAY",
					Anchor = { "TOPRIGHT", "$parent", "TOPRIGHT", -40, -4 },
					Hide = true,
				},
				buff1 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "TOPLEFT", "$parent", "BOTTOMLEFT", 4, 2 } },
				buff2 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff1", "RIGHT", 0, 0 } },
				buff3 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff2", "RIGHT", 0, 0 } },
				buff4 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff3", "RIGHT", 0, 0 } },
				buff5 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff4", "RIGHT", 0, 0 } },
				buff6 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff5", "RIGHT", 0, 0 } },
				buff7 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff6", "RIGHT", 0, 0 } },
				buff8 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff7", "RIGHT", 0, 0 } },
				buff9 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff8", "RIGHT", 0, 0 } },
				buff10 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff9", "RIGHT", 0, 0 } },
				buff11 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff10", "RIGHT", 0, 0 } },
				buff12 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff11", "RIGHT", 0, 0 } },
				buff13 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff12", "RIGHT", 0, 0 } },
				buff14 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff13", "RIGHT", 0, 0 } },
				buff15 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff14", "RIGHT", 0, 0 } },
				buff16 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff15", "RIGHT", 0, 0 } },
				buff17 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "TOPLEFT", "$parentbuff1", "BOTTOMLEFT", 0, 0 } },
				buff18 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff17", "RIGHT", 0, 0 } },
				buff19 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff18", "RIGHT", 0, 0 } },
				buff20 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff19", "RIGHT", 0, 0 } },
				buff21 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff20", "RIGHT", 0, 0 } },
				buff22 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff21", "RIGHT", 0, 0 } },
				buff23 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff22", "RIGHT", 0, 0 } },
				buff24 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff23", "RIGHT", 0, 0 } },
				buff25 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff24", "RIGHT", 0, 0 } },
				buff26 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff25", "RIGHT", 0, 0 } },
				buff27 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff26", "RIGHT", 0, 0 } },
				buff28 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff27", "RIGHT", 0, 0 } },
				buff29 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff28", "RIGHT", 0, 0 } },
				buff30 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff29", "RIGHT", 0, 0 } },
				buff31 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff30", "RIGHT", 0, 0 } },
				buff32 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentbuff31", "RIGHT", 0, 0 } },
				debuff1 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "TOPLEFT", "$parent", "BOTTOMLEFT", 4, -20 } },
				debuff2 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff1", "RIGHT", 0, 0 } },
				debuff3 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff2", "RIGHT", 0, 0 } },
				debuff4 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff3", "RIGHT", 0, 0 } },
				debuff5 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff4", "RIGHT", 0, 0 } },
				debuff6 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff5", "RIGHT", 0, 0 } },
				debuff7 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff6", "RIGHT", 0, 0 } },
				debuff8 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff7", "RIGHT", 0, 0 } },
				debuff9 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff8", "RIGHT", 0, 0 } },
				debuff10 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff9", "RIGHT", 0, 0 } },
				debuff11 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff10", "RIGHT", 0, 0 } },
				debuff12 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff11", "RIGHT", 0, 0 } },
				debuff13 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff12", "RIGHT", 0, 0 } },
				debuff14 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff13", "RIGHT", 0, 0 } },
				debuff15 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff14", "RIGHT", 0, 0 } },
				debuff16 = { type = "Button", uitemp = "TargetDebuffButtonTemplate", Anchor = { "LEFT", "$parentdebuff15", "RIGHT", 0, 0 } },
			},
			vars = { aurawidth = 160, aurasize = 16 },
		},
		party1 = "Nurfed_Party",
		party2 = "Nurfed_Party",
		party3 = "Nurfed_Party",
		party4 = "Nurfed_Party",
	};
end