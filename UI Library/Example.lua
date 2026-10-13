-- ===================================================================
--  LOUIS HUB UI LIBRARY (V3.0) — COMPLETE 100% COMPONENT SHOWCASE
--  Resource: https://raw.githubusercontent.com/gamerlatahzan-design/SSLH-SourceCode-/refs/heads/main/UI%20Library/LouisHub.lua
-- ===================================================================

local LouisHub = loadstring(game:HttpGet("https://raw.githubusercontent.com/gamerlatahzan-design/SSLH-SourceCode-/refs/heads/main/UI%20Library/LouisHub.lua"))()

-- 1. WINDOW INITIALIZATION
local Ventana = LouisHub:CrearVentanaConSeguridad({
    Titulo = "Louis Hub V3",
    Subtitulo = "Official Complete Showcase",
    TamanoX = 580,
    TamanoY = 360,
    TeclaToggle = Enum.KeyCode.RightControl,
    Orientacion = "vertical",     -- "vertical" or "horizontal"
    NombreConfig = "ShowcaseConfig",
    AutoGuardar = true,
    Buscador = true,
    PestanaPreinstalada = true    -- Injects '🔧 Suite' Tab
})

-- Header Badges & Sidebar Dividers
Ventana:AgregarTag({ Texto = "VERIFIED", Color = "success" })
Ventana:AgregarTag({ Texto = "v3.0.0", Color = "info" })
Ventana:AgregarDivisorSidebar({ Texto = "MAIN MODULES" })
Ventana:AgregarSelectorTemas()

-- ===================================================================
--  TAB 1: CORE INPUTS & CONTROLS
-- ===================================================================
local TabCore = Ventana:CrearTab("Controls", "⚡")

local Sec1 = TabCore:CrearSeccion("Standard Interactive Controls", { Colapsable = true })

-- 1. TOGGLE
Sec1:Toggle({
    Texto = "Auto Farming Mode",
    Flag = "Demo_AutoFarm",
    Defecto = false,
    Tooltip = "Automated mob combat routine",
    Tecla = Enum.KeyCode.H,
    Callback = function(val) print("[Core] Toggle:", val) end
})

-- 2. CASILLA (CHECKBOX)
Sec1:Casilla({
    Texto = "Mute Sound Effects",
    Flag = "Demo_Mute",
    Defecto = false,
    Callback = function(val) print("[Core] Checkbox:", val) end
})

-- 3. BOTON (BUTTON: STANDARD & ASYNC)
Sec1:Boton({
    Texto = "Instant Heal",
    Icono = "💖",
    Callback = function()
        LouisHub:Notificar({ Titulo = "Healed", Texto = "HP restored to 100%", Tipo = "Success" })
    end
})

Sec1:Boton({
    Texto = "Sync Server Data (Async Spinner)",
    Icono = "🌐",
    Async = true,
    Callback = function()
        task.wait(1.5)
        LouisHub:Notificar({ Titulo = "Synced", Texto = "Data loaded successfully", Tipo = "Success" })
    end
})

-- 4. SLIDER
Sec1:Slider({
    Texto = "WalkSpeed",
    Flag = "Demo_WalkSpeed",
    Min = 16,
    Max = 150,
    Incremento = 1,
    Sufijo = " studs/s",
    Defecto = 16,
    Callback = function(val)
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char:FindFirstChildOfClass("Humanoid").WalkSpeed = val
        end
    end
})

-- 5. RANGE SLIDER (DUAL THUMB)
Sec1:RangeSlider({
    Texto = "Mob Level Range",
    Flag = "Demo_LevelRange",
    Min = 1,
    Max = 100,
    Incremento = 1,
    Defecto = { min = 15, max = 75 },
    Callback = function(rng) print("[Core] Level Range:", rng.min, "-", rng.max) end
})

-- 6. NUMBER STEPPER
Sec1:NumberStepper({
    Texto = "Damage Multiplier",
    Flag = "Demo_Multiplier",
    Min = 1,
    Max = 20,
    Incremento = 0.5,
    Prefijo = "x",
    Defecto = 2,
    Callback = function(val) print("[Core] Multiplier:", val) end
})

-- 7. INPUT (SINGLE LINE & TEXTAREA)
Sec1:Input({
    Texto = "Target Player Name",
    Flag = "Demo_PlayerName",
    Placeholder = "Enter username...",
    MaxCaracteres = 20,
    Tipo = "pattern",
    Regex = "[%a%d_]+",
    Callback = function(txt) print("[Core] Input Text:", txt) end
})

Sec1:Input({
    Texto = "Custom Execution Notes",
    Flag = "Demo_Notes",
    Tipo = "textarea",
    Alto = 75,
    MaxCaracteres = 300,
    Placeholder = "Type notes or script logs here...",
    Callback = function(txt) print("[Core] TextArea Content:", txt) end
})

-- ===================================================================
--  TAB 2: MENUS, PICKERS & KEYBINDS
-- ===================================================================
local TabSelectors = Ventana:CrearTab("Selectors", "🎨")

local Sec2 = TabSelectors:CrearSeccion("Menus & Bindings")

-- 8. RADIO GROUP
Sec2:RadioGroup({
    Texto = "Attack Priority",
    Flag = "Demo_Priority",
    Opciones = { "Distance", "Lowest HP", "High Level" },
    Defecto = "Distance",
    Callback = function(val) print("[Selectors] Radio:", val) end
})

-- 9. DROPDOWN (SEARCHABLE, CATEGORIES, LOCKED)
Sec2:Dropdown({
    Texto = "Teleport Zone",
    Flag = "Demo_Zone",
    Multi = false,
    Opciones = {
        "Spawn City",
        "Pirate Cove",
        { Tipo = "Divider" },
        { Titulo = "Demon Lair", Descripcion = "Level 80+", Icono = "💀" },
        { Titulo = "Sky Sanctuary", Locked = true, LockedTitle = "VIP Gamepass Only" }
    },
    Defecto = "Spawn City",
    Callback = function(val) print("[Selectors] Dropdown Teleport:", val) end
})

-- 10. COLOR PICKER (RGB, HEX & QUICK PALETTES)
Sec2:ColorPicker({
    Texto = "Chams ESP Color",
    Flag = "Demo_Color",
    Defecto = Color3.fromRGB(0, 255, 170),
    Callback = function(col) print("[Selectors] Color3:", col) end
})

-- 11. KEYBIND (MODIFIERS & MOBILE COMPATIBLE)
Sec2:Keybind({
    Texto = "Flight Keybind",
    Flag = "Demo_FlyBind",
    ConModificadores = true,
    Defecto = { KeyCode = Enum.KeyCode.F, Ctrl = true, Shift = false, Alt = false },
    Callback = function()
        LouisHub:Notificar({ Titulo = "Flight Activated", Texto = "Hotkey triggered", Duracion = 2 })
    end
})

-- 12. TAG INPUT (CHIPS)
Sec2:TagInput({
    Texto = "Target Whitelist",
    Flag = "Demo_Whitelist",
    Defecto = { "Admin", "Friend1" },
    MaxTags = 8,
    Callback = function(tags) print("[Selectors] Tags count:", #tags) end
})

-- ===================================================================
--  TAB 3: MEDIA, LABELS, DIVIDERS & PROGRESS
-- ===================================================================
local TabDisplay = Ventana:CrearTab("Display", "📊")

local Sec3 = TabDisplay:CrearSeccion("Display Cards & Progress")

-- 13. LABEL (DYNAMIC REAL-TIME UPDATE)
Sec3:Label({
    Texto = "Network Latency",
    Flag = "Demo_Ping",
    Valor = "Querying...",
    Cada = 1.0,
    Actualizar = function()
        local ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        return ping .. " ms"
    end
})

-- 14. PROGRESO (ANIMATED PROGRESS BAR)
local ProgBar = Sec3:Progreso({
    Texto = "Raid Clear Progress",
    Flag = "Demo_Progress",
    Defecto = 20
})

-- 15. DIVIDER (SECTION ACCENT LINE)
Sec3:Divider({ Texto = "Visual Enhancements" })

-- 16. IMAGEN (ASPECT RATIO / BANNER)
Sec3:Imagen({
    Url = "rbxassetid://123994745552712",
    Aspecto = "16:9",
    Radio = 8
})

-- 17. GRUPO (HORIZONTAL BUTTON GROUP)
local BtnGrp = Sec3:Grupo({ Alto = 30 })
BtnGrp:Boton({
    Texto = "Progress +20%",
    Callback = function()
        ProgBar:Set(math.min(100, ProgBar:Get() + 20))
    end
})
BtnGrp:Boton({
    Texto = "Reset Progress",
    Callback = function() ProgBar:Set(0) end
})

-- 18. PARRAFO (RICH CARD WITH ACCORDION & ACTION BUTTONS)
Sec3:Parrafo({
    Titulo = "Anti-Detection Engine",
    Contenido = "Active defensive wrappers prevent client memory scans.",
    Descripcion = "Engine Details:\n• Ghost connections self-terminate\n• UI parented to gethui()",
    MiniaturaUrl = "rbxassetid://123994745552712",
    Botones = {
        {
            Texto = "Documentation",
            Variante = "primary",
            Callback = function() print("[Display] Docs clicked") end
        }
    }
})

-- TAB DIVISOR EXAMPLE
TabDisplay:CrearDivisor({ Texto = "End of Display Modules" })

-- ===================================================================
--  TAB 4: FLOATING HUD, FAB & MODIFIERS (LOCK, MODALS)
-- ===================================================================
local TabExtras = Ventana:CrearTab("Extras", "🧩")

local Sec4 = TabExtras:CrearSeccion("Floating Utilities")

-- 19. CREAR HUD (FLOATING STATS WINDOW)
local StatsHUD = LouisHub:CrearHUD({
    Titulo = "Live Session HUD",
    Ancho = 200,
    Visible = false
})
StatsHUD:AgregarFila("status", "Status", "Idle")
StatsHUD:AgregarFila("gold", "Coins Farmed", "0")

Sec4:HUDToggle(StatsHUD, {
    Texto = "Display Floating HUD",
    Defecto = false
})

-- 20. CREAR BOTON FLOTANTE (MOBILE FAB)
local MobileBtn = LouisHub:CrearBotonFlotante({
    Texto = "⚡ Action",
    Modo = "Click",
    Visible = false,
    Callback = function()
        LouisHub:Notificar({ Titulo = "Mobile FAB", Texto = "Tapped Floating Button!", Duracion = 1.5 })
    end
})

Sec4:BotonFlotanteToggle(MobileBtn, {
    Texto = "Display Mobile Action Button",
    Defecto = false
})

local Sec5 = TabExtras:CrearSeccion("Locking & Modals")

-- LOCK & HIGHLIGHT MODIFIER DEMO
local LockedBtn = Sec5:Boton({
    Texto = "Restricted Armory Teleport",
    Callback = function() print("Armory entered!") end
})
LockedBtn:Lock("Requires Level 50")

Sec5:Boton({
    Texto = "Toggle Armory Lock Status",
    Callback = function()
        if LockedBtn:IsLocked() then
            LockedBtn:Unlock()
            LockedBtn:Highlight(2) -- Pulse highlight stroke for 2 seconds
        else
            LockedBtn:Lock("Requires Level 50")
        end
    end
})

-- MODAL CONFIRMATION DIALOG
Sec5:Boton({
    Texto = "Trigger Factory Reset Dialog",
    Callback = function()
        LouisHub:Confirmar({
            Titulo = "Factory Reset",
            Contenido = "Do you want to reset all controls back to initial defaults?",
            Icono = "⚠️",
            Botones = {
                { Texto = "Cancel", Variante = "neutral" },
                {
                    Texto = "Reset",
                    Variante = "danger",
                    Callback = function()
                        Ventana:Resetear()
                        LouisHub:Notificar({ Titulo = "Reset Complete", Texto = "Controls restored.", Tipo = "Warning" })
                    end
                }
            }
        })
    end
})

-- ===================================================================
--  INITIALIZATION NOTIFICATION
-- ===================================================================
LouisHub:Notificar({
    Titulo = "Louis Hub Initialized",
    Texto = "100% of all UI components successfully registered.",
    Tipo = "Success",
    Duracion = 4
})
