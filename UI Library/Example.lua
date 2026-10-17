--[[
╔══════════════════════════════════════════════════════════════════════╗
                 ALANLUNA ULTIMATE MASTER DEMO HUB
        Contoh Implementasi Komprehensif Seluruh Fitur AlanLuna
╚══════════════════════════════════════════════════════════════════════╝
]]

local AlanLuna = loadstring(readfile("AlanLuna.lua"))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ══════════════════════════════════════════════════════════════
--  1. INISIALISASI VENTANA UTAMA
-- ══════════════════════════════════════════════════════════════
local Ventana = AlanLuna:CrearVentana({
    Titulo        = "Project AlanLuna",
    Subtitulo     = "Master Production Hub",
    TamanoX       = 640,
    TamanoY       = 410,
    TeclaToggle   = Enum.KeyCode.RightControl,
    Buscador      = true,
    AutoGuardar   = true,
    NombreConfig  = "AlanLuna_MasterConfig",
    Orientacion   = "vertical", -- "vertical" (sidebar) atau "horizontal" (topbar)
})

-- Terapkan tema Halloween
AlanLuna.ThemeManager:AplicarTema("Halloween")

-- ══════════════════════════════════════════════════════════════
--  2. EVENT BUS LISTENER DEMO (LOGGING GLOBAL)
-- ══════════════════════════════════════════════════════════════
AlanLuna.Eventos.FlagCambiada:Connect(function(flag, valor)
    print(string.format("[EventBus] Flag '%s' berubah menjadi: %s", tostring(flag), tostring(valor)))
end)

AlanLuna.Eventos.TabCambiada:Connect(function(cat, tab)
    print(string.format("[EventBus] Navigasi Tab: %s › %s", tostring(cat), tostring(tab)))
end)

AlanLuna.Eventos.SubTabCambiada:Connect(function(cat, tab, sub)
    print(string.format("[EventBus] Navigasi Sub-Tab: %s › %s › %s", tostring(cat), tostring(tab), tostring(sub)))
end)

-- ══════════════════════════════════════════════════════════════
--  3. LUNA HOME TAB DASHBOARD
-- ══════════════════════════════════════════════════════════════
Ventana:CreateHomeTab({
    Icon = 1,
    SupportedExecutors = {"Synapse X", "Krnl", "Fluxus", "Delta", "Vega X", "Nihon", "Xeno"},
    DiscordInvite = "alanluna-hub"
})

-- ══════════════════════════════════════════════════════════════
--  4. KOMPONEN BARU: DUAL HUD OVERLAY (TOP & BOTTOM)
-- ══════════════════════════════════════════════════════════════
local TopHUD = AlanLuna:HUD({
    Nombre = "DiagnosticHUD",
    Posicion = "TopLeft",
    Draggable = true,
    Elementos = {
        { Flag = "fps", Label = "FPS", Valor = "60", Icono = "speed" },
        { Flag = "ping", Label = "Ping", Valor = "40", Sufijo = "ms", Icono = "wifi" },
        { Flag = "mem", Label = "Mem", Valor = "150", Sufijo = "MB", Icono = "memory" },
    }
})

TopHUD:Vincular("fps", function()
    return math.floor(1 / math.max(RunService.RenderStepped:Wait(), 0.001))
end, 0.5)

TopHUD:Vincular("ping", function()
    local s = game:GetService("Stats")
    local p = s and s:FindFirstChild("Network") and s.Network:FindFirstChild("ServerStatsItem") and s.Network.ServerStatsItem:FindFirstChild("Data Ping")
    return p and math.floor(p:GetValue()) or 35
end, 1)

local CombatHUD = AlanLuna:HUD({
    Nombre = "CombatHUD",
    Posicion = "BottomRight",
    Draggable = true,
    Elementos = {
        { Flag = "hp", Label = "HP", Valor = 100, Max = 100, Tipo = "bar", Icono = "favorite" },
        { Flag = "target", Label = "Target", Valor = "None", Icono = "gps_fixed" },
        { Flag = "mode", Label = "Mode", Valor = "PVP", Icono = "gavel" },
    }
})

-- Update Health HUD otomatis dari karakter
AlanLuna:RegistrarHilo(task.spawn(function()
    while task.wait(0.5) do
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            CombatHUD:Set("hp", math.floor(hum.Health))
        end
    end
end))

-- ══════════════════════════════════════════════════════════════
--  5. KOMPONEN BARU: FLOATING ACTION BUTTONS (BOTON EXTERNO)
-- ══════════════════════════════════════════════════════════════
local ExtAim = AlanLuna:BotonExterno({
    Nombre = "FloatingAimbot",
    Icono = "crosshair",
    Tecla = Enum.KeyCode.V,
    Modo = "Toggle",
    Posicion = "RightCenter",
    Callback = function(estado)
        CombatHUD:Set("mode", estado and "AIMBOT ON" or "IDLE")
        AlanLuna:Notificar({
            Title = "Aimbot Trigger",
            Content = estado and "Aimbot Eksternal Aktif (Glow On)" or "Aimbot Eksternal Dinonaktifkan.",
            Type = estado and "Success" or "Info",
            Duration = 2,
            Icon = "crosshair"
        })
    end
})

local ExtBurst = AlanLuna:BotonExterno({
    Nombre = "FloatingBurst",
    Icono = "flash_on",
    Modo = "Once",
    Duracion = 2.5,
    Cooldown = 4,
    Posicion = "RightCenter", -- Collision handler otomatis menaruhnya di bawah tombol pertama
    Callback = function()
        AlanLuna:Notificar({
            Title = "Burst Activated",
            Content = "Overdrive aktif selama 2.5 detik! Cooldown 4 detik.",
            Type = "Warning",
            Duration = 3,
            Icon = "flash_on"
        })
    end
})

local ExtPanic = AlanLuna:BotonExterno({
    Nombre = "FloatingPanic",
    Icono = "close",
    Tecla = Enum.KeyCode.P,
    Modo = "Once",
    Duracion = 1,
    Cooldown = 2,
    Posicion = "LeftCenter",
    Callback = function()
        TopHUD:Alternar()
        CombatHUD:Alternar()
    end
})

-- ══════════════════════════════════════════════════════════════
--  KATEGORI 1: COMBAT & TARGETING
-- ══════════════════════════════════════════════════════════════
local CatCombat = Ventana:CrearCategoria({
    Nombre = "Combat",
    Icono = "crosshair",
    Colapsada = false,
})

local TabAimbot = CatCombat:CrearTab({
    Nombre = "Aimbot",
    Icono = "gps_fixed",
    ShowTitle = true
})

-- Sub-Tab: Silent Aim (Layout 2 Kolom)
local SubSilent = TabAimbot:CrearSubTab("Silent Aim")
local SecSilent = SubSilent:CrearSeccion("Configuración Principal", { Columnas = 2 })

SecSilent:Toggle({
    Texto = "Activar Silent Aim",
    Flag = "silent_aim_enabled",
    Defecto = false,
    Columna = 1,
    Tooltip = "Mengarahkan peluru secara instan ke target tanpa menggerakkan kamera.",
    Callback = function(v)
        CombatHUD:Set("mode", v and "SILENT AIM" or "PVP")
    end
})

SecSilent:Casilla({
    Texto = "Team Check",
    Flag = "silent_teamcheck",
    Defecto = true,
    Columna = 1,
    Tooltip = "Abaikan rekan satu tim.",
})

SecSilent:Casilla({
    Texto = "Wall Check",
    Flag = "silent_wallcheck",
    Defecto = true,
    Columna = 1,
    Tooltip = "Hanya target pemain yang terlihat (tidak terhalang dinding).",
})

SecSilent:Dropdown({
    Texto = "Hitbox Target",
    Flag = "silent_hitbox",
    Opciones = {"Head", "HumanoidRootPart", "Torso", "Random"},
    Defecto = "Head",
    Columna = 2,
    Tooltip = "Bagian tubuh musuh yang diprioritaskan.",
    Callback = function(op)
        CombatHUD:Set("target", op)
    end
})

SecSilent:Keybind({
    Texto = "Atajo Disparo",
    Flag = "silent_keybind",
    Defecto = Enum.KeyCode.E,
    ConModificadores = true,
    Columna = 2,
    Tooltip = "Tekan kombinasi tombol untuk memicu tembakan instan.",
    Callback = function(k)
        print("Kombinasi Keybind Silent Aim dipicu:", k)
    end
})

SecSilent:RadioGroup({
    Texto = "Algoritmo de Predicción",
    Flag = "silent_prediction",
    Opciones = {"Linear", "Quadratic", "Simulation"},
    Defecto = "Linear",
    Columna = 2,
    Tooltip = "Model kalkulasi gerak peluru.",
})

-- Kontrol Full-Width (Otomatis spanning 2 kolom)
SecSilent:Slider({
    Texto = "Radio del FOV (Grados)",
    Flag = "silent_fov",
    Range = {10, 360},
    Increment = 5,
    CurrentValue = 90,
    Sufijo = "°",
    Tooltip = "Lingkaran sudut pandang deteksi musuh.",
    Callback = function(v)
        print("FOV Diubah:", v)
    end
})

SecSilent:RangeSlider({
    Texto = "Rango de Distancia Operativa",
    Flag = "silent_distance_range",
    Min = 5,
    Max = 600,
    Incremento = 5,
    Sufijo = " studs",
    Defecto = { min = 25, max = 350 },
    Tooltip = "Target hanya akan dikunci jika berada di dalam rentang jarak ini.",
    Callback = function(rango)
        print(string.format("Rentang deteksi: %d s/d %d studs", rango.min, rango.max))
    end
})

SecSilent:NumberStepper({
    Texto = "Escala de Hitbox (Multiplicador)",
    Flag = "silent_hitbox_scale",
    Min = 1.0,
    Max = 10.0,
    Incremento = 0.5,
    Decimales = 1,
    Defecto = 2.0,
    Prefijo = "x",
    Tooltip = "Memperbesar ukuran collision hitbox target.",
})

-- Demonstrasi Sistem Lock / VIP Exclusive
local SecVIP = SubSilent:CrearSeccion("Funciones Experimentales", { Columnas = 1 })

local vipAutoShoot = SecVIP:Toggle({
    Texto = "Auto-Shoot Instantáneo",
    Flag = "vip_autoshoot",
    Defecto = false,
    Locked = true,
    LockedTitle = "VIP Premium",
    Tooltip = "Menembak otomatis ketika crosshair mendeteksi target.",
    Callback = function(v)
        print("Auto-Shoot berjalan:", v)
    end
})

SecVIP:Boton({
    Texto = "Desbloquear Función VIP (Simulación)",
    Icono = "lock_open",
    Callback = function()
        if vipAutoShoot:IsLocked() then
            vipAutoShoot:Unlock()
            vipAutoShoot:Highlight(3)
            AlanLuna:Notificar({
                Title = "VIP Unlocked",
                Content = "Fitur Auto-Shoot telah dibuka!",
                Type = "Success",
                Duration = 3,
                Icon = "sparkle"
            })
        else
            vipAutoShoot:Lock("VIP Re-Locked")
        end
    end
})

-- Sub-Tab: Smooth Aim
local SubSmooth = TabAimbot:CrearSubTab("Smooth Aim")
local SecSmooth = SubSmooth:CrearSeccion("Parámetros de Suavizado", { Columnas = 2 })

SecSmooth:Toggle({
    Texto = "Habilitar Camera Smoothing",
    Flag = "smooth_aim_enabled",
    Defecto = true,
    Columna = 1,
})

SecSmooth:Slider({
    Texto = "Velocidad de Interpolación (Lerp)",
    Flag = "smooth_lerp",
    Min = 1,
    Max = 50,
    Incremento = 1,
    Defecto = 15,
    Columna = 1,
})

SecSmooth:Dropdown({
    Texto = "Modo de Puntería",
    Flag = "smooth_curve",
    Opciones = {"Exponential", "Linear", "Sine Wave", "Humanized Shake"},
    Defecto = "Humanized Shake",
    Columna = 2,
})

-- ══════════════════════════════════════════════════════════════
--  KATEGORI 2: VISUALS (ESP & DRAWING)
-- ══════════════════════════════════════════════════════════════
local CatVisuals = Ventana:CrearCategoria({
    Nombre = "Visuals",
    Icono = "visibility",
    Colapsada = false,
})

local TabESP = CatVisuals:CrearTab({
    Nombre = "ESP Engine",
    Icono = "view_in_ar",
    ShowTitle = true
})

local SubPlayers = TabESP:CrearSubTab("Players ESP")
local SecESPConfig = SubPlayers:CrearSeccion("Elementos Visuales", { Columnas = 2 })

SecESPConfig:Toggle({
    Texto = "ESP Box (2D)",
    Flag = "esp_box_enabled",
    Defecto = true,
    Columna = 1,
})

SecESPConfig:Toggle({
    Texto = "ESP Health Bar",
    Flag = "esp_hp_enabled",
    Defecto = true,
    Columna = 1,
})

SecESPConfig:Toggle({
    Texto = "ESP Name & Distance",
    Flag = "esp_text_enabled",
    Defecto = true,
    Columna = 1,
})

-- Demonstrasi VISIBLE-SI (Kondisional)
SecESPConfig:Toggle({
    Texto = "Tracer Lines",
    Flag = "esp_tracers_enabled",
    Defecto = false,
    Columna = 2,
    Tooltip = "Garis pelacak dari layar ke musuh.",
})

SecESPConfig:Dropdown({
    Texto = "Origen de Tracers",
    Flag = "esp_tracer_origin",
    Opciones = {"Bottom", "Center", "Mouse"},
    Defecto = "Bottom",
    Columna = 2,
    VisibleSi = function()
        return AlanLuna.Flags.esp_tracers_enabled == true
    end,
})

SecESPConfig:Divider({ Texto = "Colores & Paletas", Columna = 1 })
SecESPConfig:Divider({ Texto = "Lista de Exclusión", Columna = 2 })

SecESPConfig:ColorPicker({
    Texto = "Color Visible",
    Flag = "esp_color_vis",
    Color = Color3.fromRGB(180, 240, 120),
    Columna = 1,
})

SecESPConfig:ColorPicker({
    Texto = "Color Tras Pared (Occluded)",
    Flag = "esp_color_occ",
    Color = Color3.fromRGB(255, 122, 24),
    Columna = 1,
})

SecESPConfig:TagInput({
    Texto = "Whitelist de Jugadores (Ignorar)",
    Flag = "esp_whitelist_tags",
    Placeholder = "Escribe nombre y pulsa Enter...",
    Defecto = {"Admin", "Moderator"},
    Columna = 2,
    Tooltip = "Pemain dalam daftar ini tidak akan dirender dalam ESP.",
})

-- Sub-Tab: World & Lighting
local SubWorld = TabESP:CrearSubTab("World & Ambient")
local SecWorld = SubWorld:CrearSeccion("Manipulación de Entorno", { Columnas = 2 })

SecWorld:Toggle({
    Texto = "Fullbright (Luz Máxima)",
    Flag = "world_fullbright",
    Defecto = false,
    Columna = 1,
    Callback = function(v)
        game:GetService("Lighting").Brightness = v and 2 or 1
        game:GetService("Lighting").ClockTime = v and 14 or 12
    end
})

SecWorld:ColorPicker({
    Texto = "Color de Cielo / Ambient",
    Flag = "world_ambient_color",
    Color = Color3.fromRGB(120, 80, 160),
    Columna = 2,
    Callback = function(c)
        game:GetService("Lighting").OutdoorAmbient = c
    end
})

-- ══════════════════════════════════════════════════════════════
--  KATEGORI 3: MOVEMENT & LOCALPLAYER
-- ══════════════════════════════════════════════════════════════
local CatMovement = Ventana:CrearCategoria({
    Nombre = "Movement",
    Icono = "directions_run",
})

local TabPlayer = CatMovement:CrearTab({
    Nombre = "Física Local",
    Icono = "speed",
})

local SubSpeed = TabPlayer:CrearSubTab("Speed & Jump")
local SecSpeed = SubSpeed:CrearSeccion("Modificadores de Movimiento", { Columnas = 2 })

SecSpeed:Slider({
    Texto = "Velocidad de Caminata (WalkSpeed)",
    Flag = "player_walkspeed",
    Min = 16,
    Max = 250,
    Incremento = 2,
    Defecto = 16,
    Columna = 1,
    Callback = function(v)
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end
})

SecSpeed:Slider({
    Texto = "Poder de Salto (JumpPower)",
    Flag = "player_jumppower",
    Min = 50,
    Max = 300,
    Incremento = 5,
    Defecto = 50,
    Columna = 2,
    Callback = function(v)
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = v end
    end
})

SecSpeed:Toggle({
    Texto = "Salto Infinito (Infinite Jump)",
    Flag = "player_inf_jump",
    Defecto = false,
    Columna = 1,
})

AlanLuna:RegistrarConexion(UserInputService.JumpRequest:Connect(function()
    if AlanLuna.Flags.player_inf_jump then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

SecSpeed:Keybind({
    Texto = "Sprint Temporal (Mantener)",
    Flag = "player_sprint_bind",
    Defecto = Enum.KeyCode.LeftShift,
    Columna = 2,
    Callback = function(activo)
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = activo and (AlanLuna.Flags.player_walkspeed or 16) * 1.6 or (AlanLuna.Flags.player_walkspeed or 16)
        end
    end
})

local SecPhysics = SubSpeed:CrearSeccion("Gravedad & Resistencia", { Columnas = 1 })

local staminaBar = SecPhysics:Progreso({
    Texto = "Reserva de Stamina Simulación",
    Flag = "stamina_reserva",
    Defecto = 100,
})

-- Heartbeat loop konsumsi stamina saat lari
AlanLuna:RegistrarHilo(task.spawn(function()
    local val = 100
    while task.wait(0.2) do
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            val = math.max(0, val - 3)
        else
            val = math.min(100, val + 5)
        end
        staminaBar:Set(val)
    end
end))

-- ══════════════════════════════════════════════════════════════
--  KATEGORI 4: INTERACTION, DIALOGS & SCHEMA BUILDER
-- ══════════════════════════════════════════════════════════════
local CatMisc = Ventana:CrearCategoria({
    Nombre = "Misc & Dialogs",
    Icono = "dashboard_customize",
})

local TabDialogs = CatMisc:CrearTab({
    Nombre = "Popups & Modales",
    Icono = "chat_bubble",
})

local SecModals = TabDialogs:CrearSeccion("Pruebas de Componentes", { Columnas = 2 })

SecModals:Boton({
    Texto = "Abrir Popup Stackeable (Nivel 1)",
    Icono = "open_in_new",
    Columna = 1,
    Callback = function()
        local pop1
        pop1 = AlanLuna:Popup({
            Titulo = "Modal Principal (ZIndex 500)",
            Contenido = "Este es un popup apilable con Glass Blur. Puedes abrir un segundo popup encima de este para probar la jerarquía de capas.",
            Icono = "info",
            Botones = {
                {
                    Texto = "Abrir Segundo Popup",
                    Variante = "primary",
                    Callback = function()
                        AlanLuna:Popup({
                            Titulo = "Modal Superpuesto (ZIndex 510)",
                            Contenido = "¡Excelente! Este segundo popup tiene prioridad de enfoque y su propio backdrop oscurecido.",
                            Icono = "sparkle",
                            Botones = {
                                { Texto = "Cerrar Todo", Variante = "danger", Callback = function() pop1:Cerrar() end },
                                { Texto = "Aceptar", Variante = "primary" }
                            }
                        })
                    end
                },
                { Texto = "Cerrar", Variante = "neutral" }
            }
        })
    end
})

SecModals:Boton({
    Texto = "Probar Diálogo Confirmar",
    Icono = "report_problem",
    Columna = 1,
    Callback = function()
        AlanLuna:Confirmar({
            Titulo = "Confirmación Crítica",
            Contenido = "¿Deseas restablecer todos los flags del script a sus valores predeterminados?",
            Icono = "warning",
            Botones = {
                { Texto = "Cancelar", Variante = "neutral" },
                {
                    Texto = "Restablecer",
                    Variante = "danger",
                    Callback = function()
                        Ventana:Resetear()
                        AlanLuna:Notificar({
                            Title = "Reset Completado",
                            Content = "Todos los controles han vuelto a su estado original.",
                            Type = "Warning",
                            Duration = 3,
                            Icon = "restore"
                        })
                    end
                }
            }
        })
    end
})

SecModals:Boton({
    Texto = "Lanzar Notificaciones Cascada",
    Icono = "notifications_active",
    Columna = 2,
    Callback = function()
        AlanLuna:Notificar({ Title = "Success Test", Content = "Inyección de datos completada.", Type = "Success", Duration = 2.5, Icon = "check_circle" })
        task.wait(0.2)
        AlanLuna:Notificar({ Title = "Warning Test", Content = "El servidor tiene ping elevado (>120ms).", Type = "Warning", Duration = 3, Icon = "warning" })
        task.wait(0.2)
        AlanLuna:Notificar({ Title = "Error Test", Content = "No se pudo sincronizar el archivo remoto.", Type = "Error", Duration = 3.5, Icon = "cancel" })
        task.wait(0.2)
        AlanLuna:Notificar({ Title = "Info Test", Content = "AlanLuna v3.0 está en ejecución.", Type = "Info", Duration = 4, Icon = "info" })
    end
})

SecModals:Boton({
    Texto = "Ejecutar Profiler en Consola",
    Icono = "assessment",
    Columna = 2,
    Callback = function()
        local stats = AlanLuna:Profiler()
        AlanLuna:Notificar({
            Title = "Profiler Ejecutado",
            Content = string.format("Flags: %d | Instancias: %d | Conexiones: %d", stats.Flags, stats.ObjetosGui, stats.Conexiones),
            Type = "Info",
            Duration = 4,
            Icon = "timeline"
        })
    end
})

-- Schema Automation Builder
local TabSchema = CatMisc:CrearTab({
    Nombre = "Schema Builder",
    Icono = "build",
})

local SecSchema = TabSchema:CrearSeccion("Generación Dinámica", { Columnas = 1 })

local ControlesGenerados = SecSchema:Construir({
    {
        Control = "Toggle",
        Texto = "Toggle Generado por Schema",
        Flag = "schema_toggle_1",
        Defecto = true,
        Callback = function(v) print("Schema Toggle:", v) end
    },
    {
        Control = "Slider",
        Texto = "Slider Generado por Schema",
        Flag = "schema_slider_1",
        Min = 0,
        Max = 100,
        Incremento = 10,
        Defecto = 50,
        Callback = function(v) print("Schema Slider:", v) end
    },
    {
        Control = "Dropdown",
        Texto = "Dropdown por Schema",
        Flag = "schema_drop_1",
        Opciones = {"Opción Alpha", "Opción Beta", "Opción Gamma"},
        Defecto = "Opción Alpha",
    },
    {
        Control = "Parrafo",
        Titulo = "Nota del Schema Builder",
        Contenido = "Este bloque completo fue generado pasando un array JSON-like directamente a Seccion:Construir().",
    }
})

-- ══════════════════════════════════════════════════════════════
--  KATEGORI 5: LUNA LEGACY DROP-IN DEMO
-- ══════════════════════════════════════════════════════════════
-- Menunjukkan bahwa sintaks Luna asli (CreateButton, CreateSlider, CreateToggle, dll.)
-- tetap berjalan 100% tanpa diubah di atas backend AlanLuna.
local TabLegacyLuna = CatMisc:CrearTab({
    Nombre = "Luna Drop-in API",
    Icono = "sparkle",
})

TabLegacyLuna:CreateButton({
    Name = "Luna Native Button",
    Description = "Tombol ini dipanggil memakai sintaks asli Luna UI!",
    Callback = function()
        AlanLuna:Notificar({
            Title = "Luna API",
            Content = "Panggilan Tab:CreateButton() berhasil!",
            Type = "Success",
            Icon = "sparkle"
        })
    end
})

TabLegacyLuna:CreateToggle({
    Name = "Luna Native Toggle",
    Description = "Toggle dengan signature Luna UI asli.",
    CurrentValue = true,
    Callback = function(v)
        print("Luna Native Toggle:", v)
    end
})

TabLegacyLuna:CreateSlider({
    Name = "Luna Native Slider",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 75,
    Callback = function(v)
        print("Luna Native Slider:", v)
    end
})

TabLegacyLuna:CreateInput({
    Name = "Luna Native Input",
    PlaceholderText = "Ketik teks di sini...",
    Callback = function(t)
        print("Luna Native Input:", t)
    end
})

-- ══════════════════════════════════════════════════════════════
--  NOTIFIKASI SELESAI INITIALIZE
-- ══════════════════════════════════════════════════════════════
AlanLuna:Notificar({
    Title = "Master Demo Inicializado",
    Content = "Presiona [RightControl] para alternar la visibilidad de la ventana.",
    Type = "Success",
    Duration = 5,
    Icon = "stars"
})
