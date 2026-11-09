# ChronaOverlay.ps1
# Fellowship — Aeona Chrona markers

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -------------------- SETTINGS --------------------

$FineOffsetX = 0
$FineOffsetY = 0

$Pink = [System.Drawing.Color]::FromArgb(255, 235, 90, 190)
$Blue = [System.Drawing.Color]::FromArgb(255, 70, 155, 255)

# State variables
$script:ActiveProfileName = ""
$script:isVertical = $false
$script:centerX = 0.0
$script:centerY = 0.0
$script:BarLengthPx = 0.0
$script:BarThicknessPx = 0.0
$script:halfLength = 0.0
$script:tickWidth = 0.0

# -------------------- FUNCTIONS --------------------

function Update-Geometry {
    param([bool]$ShowPicker = $false)

    $UserSettingsPaths = @(
        (Join-Path $env:LOCALAPPDATA 'fellowship\Saved\Config\WindowsClient\UserSettings.ini'),
        (Join-Path $env:LOCALAPPDATA 'fellowship\Saved\Config\Windows\UserSettings.ini')
    )

    $ProfilesPath = Join-Path $env:LOCALAPPDATA 'fellowship\Saved\UIProfiles'

    $GlobalUIScale = 1.0
    $profiles = @()

    # 1. Search in UserSettings.ini
    foreach ($path in $UserSettingsPaths) {
        if (Test-Path -LiteralPath $path) {
            $iniContent = Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue

            if ($iniContent -match '(?m)^CR\.UIScale=([0-9\.]+)') {
                $GlobalUIScale = [double]$Matches[1] / 100.0
            }

            $profileLines = [regex]::Matches($iniContent, '(?m)^HUDSettingsProfile=\((.*)$')

            foreach ($lineMatch in $profileLines) {
                $profileStr = $lineMatch.Groups[1].Value
                $nameMatch = [regex]::Match($profileStr, 'ProfileName="([^"]+)"')
                if (-not $nameMatch.Success) { continue }
                $profileName = $nameMatch.Groups[1].Value

                $posMatch = [regex]::Match($profileStr, '\("Aeona - Arcane Bar", \(X=([-\d\.]+),Y=([-\d\.]+)\)\)')
                if (-not $posMatch.Success) { continue }
                $barX = [double]$posMatch.Groups[1].Value
                $barY = [double]$posMatch.Groups[2].Value

                $anchorMatch = [regex]::Match($profileStr, '\("Aeona - Arcane Bar", ([A-Za-z]+)\)')
                $anchor = if ($anchorMatch.Success) { $anchorMatch.Groups[1].Value } else { "Center" }

                $angleMatch = [regex]::Match($profileStr, 'HeroHUDPrimaryAngle=.*?\(TagName="CharacterID\.Hero\.Lisa"\), ([-\d\.]+)')
                $angle = if ($angleMatch.Success) { [double]$angleMatch.Groups[1].Value } else { 270 }

                $scaleMatch = [regex]::Match($profileStr, 'HeroHUDPrimaryScale=.*?\(TagName="CharacterID\.Hero\.Lisa"\), ([-\d\.]+)')
                $scale = if ($scaleMatch.Success) { [double]$scaleMatch.Groups[1].Value } else { 100 }

                $profiles += [pscustomobject]@{
                    Name   = $profileName
                    X      = $barX
                    Y      = $barY
                    Anchor = $anchor
                    Angle  = $angle
                    Scale  = $scale
                }
            }
            break
        }
    }

    # 2. Fallback to .uiprofile
    if ($profiles.Count -eq 0) {
        if (Test-Path -LiteralPath $ProfilesPath) {
            $profileFiles = Get-ChildItem -LiteralPath $ProfilesPath -Filter '*.uiprofile' -File
            foreach ($file in $profileFiles) {
                try {
                    $json = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                    $profileName = [string]$json.profileName
                    if ([string]::IsNullOrWhiteSpace($profileName)) { $profileName = $file.BaseName }

                    $barPosition = $json.elementCanvasPositions.'Aeona - Arcane Bar'
                    $anchor = $json.elementCanvasAnchors.'Aeona - Arcane Bar'
                    $angleKey = '(TagName="CharacterID.Hero.Lisa")'

                    if ($null -eq $barPosition) { continue }

                    $profiles += [pscustomobject]@{
                        Name   = $profileName
                        X      = [double]$barPosition.x
                        Y      = [double]$barPosition.y
                        Anchor = [string]$anchor
                        Angle  = [double]$json.heroHUDPrimaryAngle.PSObject.Properties[$angleKey].Value
                        Scale  = [double]$json.heroHUDPrimaryScale.PSObject.Properties[$angleKey].Value
                    }
                } catch {}
            }
        }
    }

    if ($profiles.Count -eq 0) {
        if ($ShowPicker) {
            [System.Windows.Forms.MessageBox]::Show("Could not find any profiles.", 'Chrona Overlay') | Out-Null
        }
        return $false
    }

    # 3. Profile selection
    if ($ShowPicker) {
        $picker = New-Object System.Windows.Forms.Form
        $picker.Text = 'Chrona Overlay - Profile selection'
        $picker.StartPosition = 'CenterScreen'
        # Increased height from 150 to 190 to fit the hint text
        $picker.Size = New-Object System.Drawing.Size(430, 190)
        $picker.FormBorderStyle = 'FixedDialog'
        $picker.MaximizeBox = $false
        $picker.MinimizeBox = $false
        $picker.TopMost = $true

        $label = New-Object System.Windows.Forms.Label
        $label.Text = 'Select UI profile:'
        $label.AutoSize = $true
        $label.Location = New-Object System.Drawing.Point(12, 12)
        $picker.Controls.Add($label)

        $combo = New-Object System.Windows.Forms.ComboBox
        $combo.DropDownStyle = 'DropDownList'
        $combo.Location = New-Object System.Drawing.Point(12, 40)
        $combo.Size = New-Object System.Drawing.Size(390, 25)

        foreach ($p in $profiles) {
            [void]$combo.Items.Add($p.Name)
        }

        $combo.SelectedIndex = 0
        $picker.Controls.Add($combo)

        $ok = New-Object System.Windows.Forms.Button
        $ok.Text = 'Start'
        $ok.Location = New-Object System.Drawing.Point(302, 78)
        $ok.Size = New-Object System.Drawing.Size(100, 28)
        $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $picker.AcceptButton = $ok
        $picker.Controls.Add($ok)

        # Added hint label for hotkeys
        $hintLabel = New-Object System.Windows.Forms.Label
        $hintLabel.Text = "Hotkeys: F9 - Refresh position | Ctrl+0 - Exit`nOverlay hides automatically when game is not in focus."
        $hintLabel.AutoSize = $true
        $hintLabel.Location = New-Object System.Drawing.Point(12, 115)
        $hintLabel.ForeColor = [System.Drawing.Color]::DimGray
        $picker.Controls.Add($hintLabel)

        $picker.Add_Shown({
            $picker.Activate()
            $picker.BringToFront()
            $picker.Focus()
        })

        if ($picker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            return $false
        }

        $script:ActiveProfileName = $combo.SelectedItem.ToString()
    }

    $profile = $profiles | Where-Object { $_.Name -eq $script:ActiveProfileName } | Select-Object -First 1

    if (-not $profile) {
        if ($ShowPicker) {
            [System.Windows.Forms.MessageBox]::Show("Selected profile '$script:ActiveProfileName' was not found.", 'Chrona Overlay') | Out-Null
        }
        return $false
    }

    # 4. Geometry calculation
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds

    $script:BarLengthPx = (140.0 + (1.4 * $profile.Scale)) * $GlobalUIScale
    $script:BarThicknessPx = (12.0 + (0.12 * $profile.Scale)) * $GlobalUIScale

    $script:isVertical = ([int]$profile.Angle % 360 -eq 270)

    $anchorOffsetX = 0.0
    $anchorOffsetY = 0.0

    if ($profile.Anchor -match "Left") { $anchorOffsetX = $script:BarThicknessPx / 2.0 }
    elseif ($profile.Anchor -match "Right") { $anchorOffsetX = -($script:BarThicknessPx / 2.0) }

    if ($profile.Anchor -match "Top") { $anchorOffsetY = $script:BarLengthPx / 2.0 }
    elseif ($profile.Anchor -match "Bottom") { $anchorOffsetY = -($script:BarLengthPx / 2.0) }

    $script:centerX = $screen.Left + ($screen.Width / 2) + ($profile.X * $GlobalUIScale) + $anchorOffsetX + $FineOffsetX
    $script:centerY = $screen.Top + ($screen.Height / 2) + ($profile.Y * $GlobalUIScale) + $anchorOffsetY + $FineOffsetY

    $script:tickWidth = [Math]::Max(2, [Math]::Round($script:BarThicknessPx * 0.9))
    $script:halfLength = $script:BarLengthPx / 2.0

    return $true
}

# -------------------- MAIN --------------------

if (-not (Update-Geometry -ShowPicker $true)) { exit }

# -------------------- OVERLAY WINDOW & API --------------------

$source = @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class Win32 {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    
    // New functions for getting the active window
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll", SetLastError=true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
}

public class HotkeyWindow : NativeWindow {
    public event Action<int> Hotkey;
    protected override void WndProc(ref Message m) {
        if (m.Msg == 0x0312) { // WM_HOTKEY
            var h = Hotkey;
            if (h != null) h(m.WParam.ToInt32());
        }
        base.WndProc(ref m);
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies @("System.Windows.Forms", "System.Drawing") -ErrorAction Stop

$GWL_EXSTYLE       = -20
$WS_EX_LAYERED     = 0x80000
$WS_EX_TRANSPARENT = 0x20
$WS_EX_TOOLWINDOW  = 0x80

$HOTKEY_ID_REFRESH = 1
$HOTKEY_ID_EXIT    = 2

$VK_F9             = 0x78
$VK_0              = 0x30
$MOD_CONTROL       = 0x0002
$MOD_NOREPEAT      = 0x4000

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.StartPosition = 'Manual'
$form.Bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.BackColor = [System.Drawing.Color]::Magenta
$form.TransparencyKey = [System.Drawing.Color]::Magenta

$form.GetType().GetProperty(
    "DoubleBuffered",
    [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
).SetValue($form, $true, $null)

$hkWin = New-Object HotkeyWindow

$hkWin.add_Hotkey({
    param($id)
    switch ($id) {
        $HOTKEY_ID_REFRESH {
            if (Update-Geometry -ShowPicker $false) {
                $form.Invalidate()
                Write-Host "Overlay updated via F9 hotkey."
            }
        }
        $HOTKEY_ID_EXIT {
            $form.Close()
        }
    }
})

$script:baseStyle = 0

$form.Add_HandleCreated({
    # Make window click-through
    $script:baseStyle = [Win32]::GetWindowLong($form.Handle, $GWL_EXSTYLE) -bor $WS_EX_LAYERED -bor $WS_EX_TRANSPARENT -bor $WS_EX_TOOLWINDOW
    [Win32]::SetWindowLong($form.Handle, $GWL_EXSTYLE, $script:baseStyle) | Out-Null

    # Register global hotkeys
    [Win32]::RegisterHotKey($form.Handle, $HOTKEY_ID_REFRESH, $MOD_NOREPEAT, $VK_F9) | Out-Null
    [Win32]::RegisterHotKey($form.Handle, $HOTKEY_ID_EXIT, $MOD_CONTROL -bor $MOD_NOREPEAT, $VK_0) | Out-Null
    
    $hkWin.AssignHandle($form.Handle)
})

$form.Add_FormClosing({
    [Win32]::UnregisterHotKey($form.Handle, $HOTKEY_ID_REFRESH) | Out-Null
    [Win32]::UnregisterHotKey($form.Handle, $HOTKEY_ID_EXIT) | Out-Null
})

# -------------------- AUTO-HIDE TIMER --------------------
# Timer checks every 500 ms if the game is in focus
$visibilityTimer = New-Object System.Windows.Forms.Timer
$visibilityTimer.Interval = 500
$visibilityTimer.Add_Tick({
    $hwnd = [Win32]::GetForegroundWindow()
    
    # FIXED: Renamed $pid to $processId because $pid is a read-only built-in variable in PowerShell
    $processId = 0
    [void][Win32]::GetWindowThreadProcessId($hwnd, [ref]$processId)
    
    $isGameActive = $false
    if ($processId -gt 0) {
        try {
            $proc = Get-Process -Id $processId -ErrorAction Stop
            # Look for a process with "fellowship" in its name
            if ($proc.ProcessName -match "fellowship") {
                $isGameActive = $true
            }
        } catch {}
    }
    
    # Toggle visibility only if the state has changed
    if ($form.Visible -ne $isGameActive) {
        $form.Visible = $isGameActive
    }
})
$visibilityTimer.Start()

# -------------------- DRAW MARKERS --------------------

$form.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::None

    $values = @(
        @{ Value = 30; Color = $Pink }
        @{ Value = 50; Color = $Blue }
        @{ Value = 60; Color = $Pink }
        @{ Value = 90; Color = $Pink }
    )

    foreach ($mark in $values) {
        $fraction = $mark.Value / 100.0
        $pen = New-Object System.Drawing.Pen($mark.Color, 2)

        if ($script:isVertical) {
            $y = $script:centerY + $script:halfLength - ($script:BarLengthPx * $fraction)
            $x1 = $script:centerX - ($script:tickWidth / 2.0)
            $x2 = $script:centerX + ($script:tickWidth / 2.0)
            $g.DrawLine($pen, [single]$x1, [single]$y, [single]$x2, [single]$y)
        } else {
            $x = $script:centerX - $script:halfLength + ($script:BarLengthPx * $fraction)
            $y1 = $script:centerY - ($script:tickWidth / 2.0)
            $y2 = $script:centerY + ($script:tickWidth / 2.0)
            $g.DrawLine($pen, [single]$x, [single]$y1, [single]$x, [single]$y2)
        }
        $pen.Dispose()
    }
})

# -------------------- START --------------------

Write-Host ''
Write-Host 'F9  - Refresh position (re-read settings)'
Write-Host 'Ctrl+0 - Exit'
Write-Host 'Overlay will automatically hide when you switch to other windows.'
Write-Host ''

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run($form)

$form.Dispose()