# =============================================================================
# Batch / single name-tag STL generator (Windows / PowerShell).
#
#   .\generate.ps1                  # read names from names.txt (one per line)
#   .\generate.ps1 "Anna" "Jörg"    # one STL per name argument
#
# Output goes to .\out\<sanitized-name>.stl
#
# If PowerShell blocks the script ("running scripts is disabled"), either run
# the bundled generate.bat, or start it with:
#   powershell -ExecutionPolicy Bypass -File .\generate.ps1
# =============================================================================
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Names
)

$ErrorActionPreference = 'Stop'

# --- Paths (relative to this script, so it works from any directory) ---------
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$Scad      = Join-Path $ScriptDir 'nametag.scad'
$OutDir    = Join-Path $ScriptDir 'out'
$NamesFile = Join-Path $ScriptDir 'names.txt'
Write-Host "Project folder: $ScriptDir"

# --- Locate openscad.exe -----------------------------------------------------
function Find-OpenSCAD {
    if ($env:OPENSCAD -and (Test-Path $env:OPENSCAD)) { return $env:OPENSCAD }
    $onPath = Get-Command openscad.exe -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    $candidates = @(
        (Join-Path $env:ProgramFiles 'OpenSCAD\openscad.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'OpenSCAD\openscad.exe'),
        (Join-Path $env:ProgramFiles 'OpenSCAD (Nightly)\openscad.exe')
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    throw "Could not find openscad.exe. Install OpenSCAD, or set `$env:OPENSCAD to its full path."
}
$OpenSCAD = Find-OpenSCAD
Write-Host "Using OpenSCAD: $OpenSCAD"

if (-not (Test-Path $Scad)) { throw "Model not found: $Scad" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Turn an arbitrary name into a safe filename:
#   lowercase, spaces -> _, keep Unicode letters (umlauts/accents),
#   drop only characters Windows forbids in a filename.
function Get-SafeName([string]$name) {
    $s = $name.ToLower().Replace(' ', '_')
    foreach ($c in [System.IO.Path]::GetInvalidFileNameChars()) {
        $s = $s.Replace([string]$c, '')
    }
    if ([string]::IsNullOrWhiteSpace($s)) { $s = 'tag' }
    return $s
}

function Invoke-Render([string]$name) {
    $safe = Get-SafeName $name
    $out  = Join-Path $OutDir "$safe.stl"
    Write-Host ">> $name  ->  $out"

    # Escape backslashes and double-quotes for the OpenSCAD string literal.
    $escaped = $name.Replace('\', '\\').Replace('"', '\"')

    # Write a tiny override file next to nametag.scad. It uses a relative
    # include (OpenSCAD resolves includes relative to the main file's folder)
    # and overrides `name` (last assignment wins) -- sidestepping all the
    # -D '...="..."' command-line quoting problems.
    $tmp = Join-Path $ScriptDir 'nametag_tmp.scad'
    $content = "include <nametag.scad>;`r`nname = `"$escaped`";`r`n"
    try {
        [System.IO.File]::WriteAllText($tmp, $content, $Utf8NoBom)
    }
    catch {
        throw "Could not write temp file '$tmp': $($_.Exception.Message)"
    }
    if (-not (Test-Path $tmp)) { throw "Temp file was not created: $tmp" }

    # Run OpenSCAD with its WORKING DIRECTORY set to the project folder and
    # only relative filenames on the command line. Start-Process -WorkingDirectory
    # actually sets the child process CWD (Push-Location does NOT), so OpenSCAD
    # finds the input, the include, and writes the output -- regardless of where
    # you launched the script from, and with no spaces/encoding in the paths.
    $argList = @('--enable=textmetrics', '-o', "out/$safe.stl", 'nametag_tmp.scad')
    if ($env:NAMETAG_DEBUG) {
        Write-Host "   cwd      = $ScriptDir"
        Write-Host "   args     = $($argList -join ' ')"
    }
    try {
        $proc = Start-Process -FilePath $OpenSCAD -ArgumentList $argList `
            -WorkingDirectory $ScriptDir -NoNewWindow -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            throw "OpenSCAD failed for '$name' (exit $($proc.ExitCode))"
        }
    }
    finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

# --- Collect names: from arguments, otherwise from names.txt -----------------
$list = @()
if ($Names -and $Names.Count -gt 0) {
    $list = $Names
}
elseif (Test-Path $NamesFile) {
    $list = Get-Content -LiteralPath $NamesFile -Encoding UTF8 |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' -and -not $_.StartsWith('#') }
}
else {
    throw "No names given and names.txt not found.`nUsage: .\generate.ps1 `"Name1`" `"Name2`"   or put names in names.txt"
}

if ($list.Count -eq 0) { throw "No names to render." }

foreach ($n in $list) { Invoke-Render $n }

Write-Host "Done. $($list.Count) tag(s) in $OutDir\"
