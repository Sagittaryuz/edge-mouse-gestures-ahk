#Requires AutoHotkey v2.0
#SingleInstance Force

; Edge Mouse Gestures para AutoHotkey v2
; Segure o botão direito, mova o mouse e solte para executar.
; Um clique direito comum continua funcionando quando não há gesto.

DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
CoordMode "Mouse", "Screen"
SendMode "Input"
SetMouseDelay -1
SetWinDelay -1

global CFG := Map(
    ; Reconhecimento
    "SampleMs",             8,
    "PointSpacingPx",       3,
    "ActivationDistancePx", 60,
    "DirectionBias",        1.60,
    "PathSamplePx",         10,

    ; Troca de guia: primeiro cima, depois horizontal
    "CompoundVerticalMinPx",   48,
    "CompoundHorizontalMinPx", 42,
    "CompoundAxisRatio",       2.5,

    ; Aparência do traço
    "TrailColorARGB",       0xFF078BE8,
    "TrailWidthPx",         4.0,

    ; Quadro de ação
    "HintWidthPx",          300,
    "HintHeightPx",         136,
    "HintRadiusPx",         18,
    "HintOffsetXPx",        22,
    "HintOffsetYPx",        22,
    "HintBackground",       "101116",
    "HintTextColor",        "F7F7F8",

    ; Volume via botão direito + roda
    "VolumeStep",           2,
    "VolumeStationaryPx",   8,

    ; Música via botão direito + botão do meio
    "MediaGestureThresholdPx", 120,
    "MediaGesturePollMs",      10
)

global GesturesEnabled := true
global GestureActive := false
global GestureClaimed := false
global GestureConsumed := false
global VolumeLockActive := false
global VolumeLockX := 0
global VolumeLockY := 0

global StartX := 0
global StartY := 0
global LastX := 0
global LastY := 0

global CurrentDirection := ""

global TrailPoints := []

global PathLastX := 0
global PathLastY := 0
global PathPendingX := 0
global PathPendingY := 0

global CompoundPhase := 0
global CompoundVerticalDistance := 0
global CompoundTurnX := 0
global CompoundTurnY := 0
global CompoundDirection := ""

global Trace := TraceSurface()
global Hint := ActionHint()

A_IconTip := "Gestos do Mouse — estilo Microsoft Edge"

A_TrayMenu.Delete()
A_TrayMenu.Add("Ativar/pausar gestos", ToggleGestures)
A_TrayMenu.Check("Ativar/pausar gestos")
A_TrayMenu.Add()
A_TrayMenu.Add("Sair", (*) => ExitApp())

OnExit Cleanup

; =========================
; GESTOS DO BOTÃO DIREITO
; =========================

#HotIf AreGesturesEnabled()

$*RButton::BeginGesture()

#HotIf IsGestureActive()

$*RButton Up::FinishGesture()
Esc::CancelGesture()

#HotIf

; =========================
; RODA COM BOTÃO DIREITO
; =========================

#HotIf IsRButtonVolumeReady()

$*WheelUp::AdjustVolumeWithRButton(1)
$*WheelDown::AdjustVolumeWithRButton(-1)

#HotIf

; =========================
; BOTÃO DIREITO + MÍDIA
; =========================

#HotIf IsRButtonMediaReady()

$*WheelRight::NextTrack()
$*WheelLeft::PreviousTrack()
$*MButton::HandleRButtonMediaGesture()

#HotIf

; =========================
; ATALHOS DE TECLADO
; =========================

^!g::ToggleGestures()
^!v::ProcessClipboardLines()

; =========================
; VERIFICAÇÕES
; =========================

AreGesturesEnabled(*) {
    global GesturesEnabled

    return GesturesEnabled
}

IsGestureActive(*) {
    global GestureActive

    return GestureActive
}

; =========================
; VOLUME
; =========================

IsRButtonVolumeReady(*) {
    global GestureActive, StartX, StartY, CFG, VolumeLockActive

    if !AreGesturesEnabled() || !GestureActive
        return false

    if !GetKeyState("RButton", "P")
        return false

    if VolumeLockActive
        return true

    MouseGetPos &x, &y

    dx := x - StartX
    dy := y - StartY

    distance := Sqrt(dx * dx + dy * dy)

    return distance <= CFG["VolumeStationaryPx"]
}

AdjustVolumeWithRButton(direction, *) {
    global CFG, GestureConsumed
    global VolumeLockActive, VolumeLockX, VolumeLockY

    if !VolumeLockActive {
        MouseGetPos &VolumeLockX, &VolumeLockY
        LockCursorAt(VolumeLockX, VolumeLockY)
        VolumeLockActive := true
    }

    step := CFG["VolumeStep"]
    delta := (direction > 0 ? "+" : "-") . step

    SoundSetVolume(delta)

    GestureConsumed := true

    if direction > 0
        ShowVol("Volume aumentado")
    else
        ShowVol("Volume reduzido")
}

LockCursorAt(x, y) {
    rect := Buffer(16, 0)

    NumPut("Int", x, rect, 0)
    NumPut("Int", y, rect, 4)
    NumPut("Int", x + 1, rect, 8)
    NumPut("Int", y + 1, rect, 12)

    DllCall("ClipCursor", "Ptr", rect)
    DllCall("SetCursorPos", "Int", x, "Int", y)
}

ReleaseCursorLock() {
    DllCall("ClipCursor", "Ptr", 0)
}

; =========================
; CONTROLE DE MÚSICA
; =========================

IsRButtonMediaReady(*) {
    return AreGesturesEnabled()
        && GetKeyState("RButton", "P")
}

NextTrack(*) {
    global GestureConsumed

    GestureConsumed := true

    SendInput("{Media_Next}")
    ShowAction("Próxima música")
}

PreviousTrack(*) {
    global GestureConsumed

    GestureConsumed := true

    SendInput("{Media_Prev}")
    ShowAction("Música anterior")
}

PlayPause(*) {
    global GestureConsumed

    GestureConsumed := true

    SendInput("{Media_Play_Pause}")
    ShowAction("Play / Pause")
}

HandleRButtonMediaGesture(*) {
    global CFG, GestureConsumed

    GestureConsumed := true
    triggered := false

    MouseGetPos(&startX, &startY)

    threshold := CFG["MediaGestureThresholdPx"]
    pollMs := CFG["MediaGesturePollMs"]

    while GetKeyState("MButton", "P")
        && GetKeyState("RButton", "P")
    {
        MouseGetPos(&x, &y)

        deltaX := x - startX

        if deltaX <= -threshold {
            PreviousTrack()
            triggered := true
            break
        }

        if deltaX >= threshold {
            NextTrack()
            triggered := true
            break
        }

        Sleep(pollMs)
    }

    if !triggered
        PlayPause()
}

; =========================
; MACRO CTRL + ALT + V
; =========================

ProcessClipboardLines(*) {
    text := A_Clipboard

    if !text {
        ShowAction("Área de transferência vazia")
        return
    }

    text := StrReplace(text, "`r`n", "`n")
    text := StrReplace(text, "`r", "`n")

    lines := StrSplit(text, "`n")
    processed := 0

    for line in lines {
        line := Trim(line)

        if line = ""
            continue

        SendText(line)
        Sleep(100)

        SendInput("{Enter}")
        Sleep(100)

        SendInput("s")
        Sleep(100)

        SendInput("{Enter}")
        Sleep(150)

        processed++
    }

    if processed > 0
        ShowAction(processed " itens processados")
}

; =========================
; TOOLTIPS
; =========================

ShowVol(prefix := "Volume") {
    vol := Round(SoundGetVolume())

    ToolTip(prefix ": " vol "%")
    SetTimer(RemoveToolTip, -900)
}

ShowAction(text) {
    ToolTip(text)
    SetTimer(RemoveToolTip, -900)
}

RemoveToolTip(*) {
    ToolTip()
}

; =========================
; ATIVAR / PAUSAR
; =========================

ToggleGestures(*) {
    global GesturesEnabled

    if IsGestureActive()
        CancelGesture()

    GesturesEnabled := !GesturesEnabled

    if GesturesEnabled
        A_TrayMenu.Check("Ativar/pausar gestos")
    else
        A_TrayMenu.Uncheck("Ativar/pausar gestos")

    TrayTip(
        GesturesEnabled ? "Ativados" : "Pausados",
        "Gestos do Mouse",
        1
    )
}

; =========================
; INÍCIO DO GESTO
; =========================

BeginGesture(*) {
    global GestureActive
    global GestureClaimed
    global GestureConsumed
    global VolumeLockActive

    global StartX
    global StartY
    global LastX
    global LastY

    global CurrentDirection
    global TrailPoints
    global CFG
    global Trace
    global Hint

    global PathLastX
    global PathLastY
    global PathPendingX
    global PathPendingY

    global CompoundPhase
    global CompoundVerticalDistance
    global CompoundTurnX
    global CompoundTurnY
    global CompoundDirection

    if GestureActive
        return

    VolumeLockActive := false

    ; Ativa imediatamente a janela sob o cursor.
    MouseGetPos &StartX, &StartY, &targetHwnd

    if targetHwnd
        && targetHwnd != Trace.Gui.Hwnd
        && targetHwnd != Hint.Gui.Hwnd
    {
        try WinActivate("ahk_id " targetHwnd)
    }

    LastX := StartX
    LastY := StartY

    PathLastX := StartX
    PathLastY := StartY
    PathPendingX := 0
    PathPendingY := 0

    CompoundPhase := 0
    CompoundVerticalDistance := 0
    CompoundTurnX := StartX
    CompoundTurnY := StartY
    CompoundDirection := ""

    TrailPoints := [
        {
            X: StartX,
            Y: StartY
        }
    ]

    CurrentDirection := ""
    GestureClaimed := false
    GestureConsumed := false
    GestureActive := true

    SetTimer(
        TrackGesture,
        CFG["SampleMs"]
    )
}

; =========================
; ACOMPANHAMENTO DO GESTO
; =========================

TrackGesture(*) {
    global GestureActive
    global GestureClaimed
    global StartX
    global StartY
    global LastX
    global LastY
    global CurrentDirection
    global TrailPoints
    global CFG
    global Trace
    global Hint

    if !GestureActive
        return

    MouseGetPos &x, &y

    UpdateGesturePath(x, y)

    stepX := x - LastX
    stepY := y - LastY

    if Sqrt(stepX * stepX + stepY * stepY) >= CFG["PointSpacingPx"] {
        TrailPoints.Push({
            X: x,
            Y: y
        })

        LastX := x
        LastY := y
    }

    dx := x - StartX
    dy := y - StartY

    distance := Sqrt(dx * dx + dy * dy)

    if !GestureClaimed
        && distance >= CFG["ActivationDistancePx"]
    {
        GestureClaimed := true
    }

    if GestureClaimed {
        Trace.Draw(TrailPoints)

        direction := RecognizeGesture(dx, dy)

        if direction != CurrentDirection {
            CurrentDirection := direction

            if direction
                Hint.ShowDirection(direction, StartX, StartY)
            else
                Hint.Hide()
        }
    }
}

; =========================
; RECONHECIMENTO DA TROCA DE GUIA
; =========================
; A troca de guia exige:
; 1. Movimento vertical para cima.
; 2. Distância vertical mínima.
; 3. Movimento horizontal brusco.
; 4. Distância horizontal mínima.
; 5. Os dois trechos precisam ser quase perpendiculares.

UpdateGesturePath(x, y) {
    global PathLastX
    global PathLastY
    global PathPendingX
    global PathPendingY
    global CFG

    global CompoundPhase
    global CompoundVerticalDistance
    global CompoundTurnX
    global CompoundTurnY
    global CompoundDirection

    stepX := x - PathLastX
    stepY := y - PathLastY

    PathLastX := x
    PathLastY := y

    PathPendingX += stepX
    PathPendingY += stepY

    distance := Sqrt(
        PathPendingX * PathPendingX
        + PathPendingY * PathPendingY
    )

    if distance < CFG["PathSamplePx"]
        return

    segmentX := PathPendingX
    segmentY := PathPendingY

    PathPendingX := 0
    PathPendingY := 0

    direction := RecognizeCompoundSegment(
        segmentX,
        segmentY
    )

    if !direction
        return

    ; Depois que a troca foi confirmada,
    ; ela não pode ser reclassificada.
    if CompoundPhase = 2
        return

    ; Fase 1: acumular somente movimento para cima.
    if CompoundPhase = 0 {
        if direction != "Up" {
            CompoundVerticalDistance := 0
            return
        }

        CompoundVerticalDistance += Abs(segmentY)

        if CompoundVerticalDistance >= CFG["CompoundVerticalMinPx"] {
            CompoundPhase := 1
            CompoundTurnX := x
            CompoundTurnY := y
        }

        return
    }

    ; Se continuar subindo, o ponto de mudança acompanha o cursor.
    if direction = "Up" {
        CompoundTurnX := x
        CompoundTurnY := y
        return
    }

    ; Se descer depois da subida, quebra a sequência.
    if direction = "Down" {
        CompoundPhase := 0
        CompoundVerticalDistance := 0
        CompoundTurnX := x
        CompoundTurnY := y
        return
    }

    ; Fase 2: aceitar somente movimento horizontal.
    horizontalDX := x - CompoundTurnX
    horizontalDY := y - CompoundTurnY

    horizontalDistance := Abs(horizontalDX)

    if horizontalDistance < CFG["CompoundHorizontalMinPx"]
        return

    ; O movimento horizontal precisa ser predominante.
    if horizontalDistance < Abs(horizontalDY) * CFG["CompoundAxisRatio"]
        return

    if direction = "Left"
        && horizontalDX < 0
    {
        CompoundDirection := "UpLeft"
        CompoundPhase := 2
    }
    else if direction = "Right"
        && horizontalDX > 0
    {
        CompoundDirection := "UpRight"
        CompoundPhase := 2
    }
}

RecognizeCompoundSegment(dx, dy) {
    global CFG

    ax := Abs(dx)
    ay := Abs(dy)
    ratio := CFG["CompoundAxisRatio"]

    ; Movimento vertical para cima.
    if dy < 0
        && ay >= ax * ratio
    {
        return "Up"
    }

    ; Movimento vertical para baixo.
    if dy > 0
        && ay >= ax * ratio
    {
        return "Down"
    }

    ; Movimento horizontal.
    if ax >= ay * ratio
        return dx < 0 ? "Left" : "Right"

    ; Diagonal não é aceita como troca de guia.
    return ""
}

RecognizeGesture(dx, dy) {
    global CompoundDirection

    ; A troca de guia só existe se as duas fases forem confirmadas.
    if CompoundDirection
        return CompoundDirection

    ; Gestos simples continuam funcionando.
    return RecognizeBasicDirection(dx, dy)
}

RecognizeBasicDirection(dx, dy) {
    global CFG

    ax := Abs(dx)
    ay := Abs(dy)
    bias := CFG["DirectionBias"]

    if ax >= ay * bias
        return dx < 0 ? "Left" : "Right"

    if ay >= ax * bias
        return dy < 0 ? "Up" : "Down"

    return ""
}

; =========================
; FINALIZAÇÃO
; =========================

FinishGesture(*) {
    global GestureActive
    global GestureClaimed
    global GestureConsumed
    global VolumeLockActive
    global CurrentDirection
    global Trace
    global Hint

    if !GestureActive
        return

    SetTimer TrackGesture, 0

    ; Última leitura antes de soltar.
    TrackGesture()

    GestureActive := false
    VolumeLockActive := false
    ReleaseCursorLock()

    Trace.Clear()
    Hint.Hide()

    ; Se volume ou música foi acionado,
    ; não envia clique direito.
    if GestureConsumed
        return

    if GestureClaimed {
        if CurrentDirection
            ExecuteDirection(CurrentDirection)

        return
    }

    ; Clique direito comum.
    SendEvent "{Blind}{RButton}"
}

; =========================
; CANCELAMENTO
; =========================

CancelGesture(*) {
    global GestureActive
    global VolumeLockActive
    global Trace
    global Hint

    if !GestureActive
        return

    SetTimer TrackGesture, 0

    GestureActive := false
    VolumeLockActive := false
    ReleaseCursorLock()

    Trace.Clear()
    Hint.Hide()
}

; =========================
; AÇÕES DOS GESTOS
; =========================

ExecuteDirection(direction) {
    switch direction {
        case "Left":
            Send "!{Left}"

        case "Right":
            Send "!{Right}"

        case "Up":
            Send "^{Home}"

        case "Down":
            Send "^{End}"

        case "UpLeft":
            Send "^+{Tab}"

        case "UpRight":
            Send "^{Tab}"
    }
}

; =========================
; LIMPEZA
; =========================

Cleanup(*) {
    global VolumeLockActive
    global Trace
    global Hint

    SetTimer TrackGesture, 0
    VolumeLockActive := false
    ReleaseCursorLock()

    try Hint.Hide()
    try Trace.Dispose()
}

; =========================
; QUADRO DE AÇÃO
; =========================

class ActionHint {
    __New() {
        global CFG

        this.Gui := Gui(
            "+AlwaysOnTop -Caption +ToolWindow "
            "+E0x20 +E0x08000000 -DPIScale"
        )

        this.Gui.BackColor := CFG["HintBackground"]
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0

        this.Gui.SetFont(
            "s42 c" CFG["HintTextColor"],
            "Segoe UI Symbol"
        )

        this.Arrow := this.Gui.AddText(
            "x0 y12 w" CFG["HintWidthPx"]
            " h64 Center +0x200",
            "↑"
        )

        this.Gui.SetFont(
            "s17 c" CFG["HintTextColor"],
            "Segoe UI"
        )

        this.Label := this.Gui.AddText(
            "x0 y78 w" CFG["HintWidthPx"]
            " h43 Center +0x200",
            "Rolar para cima"
        )

        this.Visible := false
    }

    ShowDirection(direction, anchorX, anchorY) {
        global CFG

        data := Map(
            "Left",    ["←", "Voltar"],
            "Right",   ["→", "Avançar"],
            "Up",      ["↑", "Rolar para cima"],
            "Down",    ["↓", "Rolar para baixo"],
            "UpLeft",  ["↖", "Alternar para a guia esquerda"],
            "UpRight", ["↗", "Alternar para a guia direita"]
        )[direction]

        this.Arrow.Text := data[1]
        this.Label.Text := data[2]

        w := CFG["HintWidthPx"]
        h := CFG["HintHeightPx"]

        x := anchorX + CFG["HintOffsetXPx"]
        y := anchorY + CFG["HintOffsetYPx"]

        GetMonitorBounds(
            anchorX,
            anchorY,
            &ml,
            &mt,
            &mr,
            &mb
        )

        if x + w > mr - 8
            x := anchorX - w - CFG["HintOffsetXPx"]

        if y + h > mb - 8
            y := anchorY - h - CFG["HintOffsetYPx"]

        x := Max(
            ml + 8,
            Min(x, mr - w - 8)
        )

        y := Max(
            mt + 8,
            Min(y, mb - h - 8)
        )

        this.Gui.Show(
            "NA x" Round(x)
            " y" Round(y)
            " w" w
            " h" h
        )

        WinSetRegion(
            "0-0 W" w
            " H" h
            " R" CFG["HintRadiusPx"]
            "-" CFG["HintRadiusPx"],
            "ahk_id " this.Gui.Hwnd
        )

        this.Visible := true
    }

    Hide() {
        if this.Visible {
            this.Gui.Hide()
            this.Visible := false
        }
    }
}

; =========================
; SUPERFÍCIE DO TRAÇO
; =========================

class TraceSurface {
    __New() {
        global CFG

        this.Left := SysGet(76)
        this.Top := SysGet(77)
        this.Width := SysGet(78)
        this.Height := SysGet(79)

        this.Gui := Gui(
            "+AlwaysOnTop -Caption +ToolWindow "
            "+E0x80000 +E0x20 +E0x08000000 -DPIScale"
        )

        this.Gui.Show(
            "NA x" this.Left
            " y" this.Top
            " w" this.Width
            " h" this.Height
        )

        this.Token := GdipStartup()

        screenDC := DllCall(
            "GetDC",
            "Ptr",
            0,
            "Ptr"
        )

        this.DC := DllCall(
            "CreateCompatibleDC",
            "Ptr",
            screenDC,
            "Ptr"
        )

        bi := Buffer(40, 0)

        NumPut("UInt", 40, bi, 0)
        NumPut("Int", this.Width, bi, 4)
        NumPut("Int", -this.Height, bi, 8)
        NumPut("UShort", 1, bi, 12)
        NumPut("UShort", 32, bi, 14)

        bits := 0

        this.Bitmap := DllCall(
            "CreateDIBSection",
            "Ptr",
            screenDC,
            "Ptr",
            bi,
            "UInt",
            0,
            "Ptr*",
            &bits,
            "Ptr",
            0,
            "UInt",
            0,
            "Ptr"
        )

        DllCall(
            "ReleaseDC",
            "Ptr",
            0,
            "Ptr",
            screenDC
        )

        this.OldBitmap := DllCall(
            "SelectObject",
            "Ptr",
            this.DC,
            "Ptr",
            this.Bitmap,
            "Ptr"
        )

        graphics := 0

        DllCall(
            "gdiplus\GdipCreateFromHDC",
            "Ptr",
            this.DC,
            "Ptr*",
            &graphics
        )

        this.Graphics := graphics

        DllCall(
            "gdiplus\GdipSetSmoothingMode",
            "Ptr",
            this.Graphics,
            "Int",
            4
        )

        pen := 0

        DllCall(
            "gdiplus\GdipCreatePen1",
            "UInt",
            CFG["TrailColorARGB"],
            "Float",
            CFG["TrailWidthPx"],
            "Int",
            2,
            "Ptr*",
            &pen
        )

        this.Pen := pen

        DllCall(
            "gdiplus\GdipSetPenStartCap",
            "Ptr",
            this.Pen,
            "Int",
            2
        )

        DllCall(
            "gdiplus\GdipSetPenEndCap",
            "Ptr",
            this.Pen,
            "Int",
            2
        )

        DllCall(
            "gdiplus\GdipSetPenLineJoin",
            "Ptr",
            this.Pen,
            "Int",
            2
        )

        this.Clear()
    }

    Draw(points) {
        DllCall(
            "gdiplus\GdipGraphicsClear",
            "Ptr",
            this.Graphics,
            "UInt",
            0x00000000
        )

        if points.Length >= 2 {
            Loop points.Length - 1 {
                p1 := points[A_Index]
                p2 := points[A_Index + 1]

                DllCall(
                    "gdiplus\GdipDrawLine",
                    "Ptr",
                    this.Graphics,
                    "Ptr",
                    this.Pen,
                    "Float",
                    p1.X - this.Left,
                    "Float",
                    p1.Y - this.Top,
                    "Float",
                    p2.X - this.Left,
                    "Float",
                    p2.Y - this.Top
                )
            }
        }

        this.Present()
    }

    Clear() {
        DllCall(
            "gdiplus\GdipGraphicsClear",
            "Ptr",
            this.Graphics,
            "UInt",
            0x00000000
        )

        this.Present()
    }

    Present() {
        dst := Buffer(8, 0)
        size := Buffer(8, 0)
        src := Buffer(8, 0)
        blend := Buffer(4, 0)

        NumPut("Int", this.Left, dst, 0)
        NumPut("Int", this.Top, dst, 4)

        NumPut("Int", this.Width, size, 0)
        NumPut("Int", this.Height, size, 4)

        NumPut("Int", 0, src, 0)
        NumPut("Int", 0, src, 4)

        NumPut("UChar", 0, blend, 0)
        NumPut("UChar", 0, blend, 1)
        NumPut("UChar", 255, blend, 2)
        NumPut("UChar", 1, blend, 3)

        screenDC := DllCall(
            "GetDC",
            "Ptr",
            0,
            "Ptr"
        )

        DllCall(
            "UpdateLayeredWindow",
            "Ptr",
            this.Gui.Hwnd,
            "Ptr",
            screenDC,
            "Ptr",
            dst,
            "Ptr",
            size,
            "Ptr",
            this.DC,
            "Ptr",
            src,
            "UInt",
            0,
            "Ptr",
            blend,
            "UInt",
            2
        )

        DllCall(
            "ReleaseDC",
            "Ptr",
            0,
            "Ptr",
            screenDC
        )
    }

    Dispose() {
        if this.Pen
            DllCall(
                "gdiplus\GdipDeletePen",
                "Ptr",
                this.Pen
            )

        if this.Graphics
            DllCall(
                "gdiplus\GdipDeleteGraphics",
                "Ptr",
                this.Graphics
            )

        if this.OldBitmap
            DllCall(
                "SelectObject",
                "Ptr",
                this.DC,
                "Ptr",
                this.OldBitmap
            )

        if this.Bitmap
            DllCall(
                "DeleteObject",
                "Ptr",
                this.Bitmap
            )

        if this.DC
            DllCall(
                "DeleteDC",
                "Ptr",
                this.DC
            )

        if this.Token
            DllCall(
                "gdiplus\GdiplusShutdown",
                "Ptr",
                this.Token
            )

        try this.Gui.Destroy()
    }
}

; =========================
; GDI+
; =========================

GdipStartup() {
    input := Buffer(
        A_PtrSize = 8 ? 24 : 16,
        0
    )

    NumPut("UInt", 1, input, 0)

    token := 0

    status := DllCall(
        "gdiplus\GdiplusStartup",
        "Ptr*",
        &token,
        "Ptr",
        input,
        "Ptr",
        0
    )

    if status
        throw Error(
            "Não foi possível iniciar o GDI+ (código "
            status
            ")."
        )

    return token
}

; =========================
; MONITORES
; =========================

GetMonitorBounds(
    x,
    y,
    &left,
    &top,
    &right,
    &bottom
) {
    count := MonitorGetCount()

    Loop count {
        MonitorGet(
            A_Index,
            &ml,
            &mt,
            &mr,
            &mb
        )

        if x >= ml
            && x < mr
            && y >= mt
            && y < mb
        {
            left := ml
            top := mt
            right := mr
            bottom := mb

            return
        }
    }

    primary := MonitorGetPrimary()

    MonitorGet(
        primary,
        &left,
        &top,
        &right,
        &bottom
    )
}
