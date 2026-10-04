#Requires -Version 5.1
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$job = Split-Path -Parent $MyInvocation.MyCommand.Definition
$requestPath = Join-Path $job 'request'
$resultPath = Join-Path $job 'result.txt'
$errorPath = Join-Path $job 'error.txt'
$tracePath = Join-Path $job 'trace'

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public struct RECT { public int Left, Top, Right, Bottom; }
public class WordWin {
  public delegate bool Proc(IntPtr handle, IntPtr lparam);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool EnumWindows(Proc callback, IntPtr lparam);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr handle, StringBuilder text, int max);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr handle, out uint procId);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr handle, out RECT rect);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr handle);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr handle, int command);
}
"@

# --- helpers ---

function Write-Sentinel {
  param([string] $Path, [string[]] $Lines)
  [IO.File]::WriteAllText($Path, (($Lines -join "`r`n") + "`r`n"))
}

function Write-Trace {
  param([string] $Step)
  [IO.File]::AppendAllText($tracePath, ([DateTime]::Now.ToString('HH:mm:ss') + ' ' + $Step + "`r`n"))
}

function Read-Request {
  param([string] $Path)
  $fields = @{}
  foreach ($line in [IO.File]::ReadAllLines($Path)) {
    $split = $line.IndexOf('=')
    if ($split -gt 0) {
      $fields[$line.Substring(0, $split)] = $line.Substring($split + 1)
    }
  }
  return $fields
}

function Get-DeclaredFont {
  param([string] $Path)
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $names = @()
  $zip = [IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $entry = $zip.GetEntry('word/fontTable.xml')
    if ($null -ne $entry) {
      $stream = $entry.Open()
      try {
        $reader = New-Object IO.StreamReader($stream)
        try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
      } finally { $stream.Dispose() }
      foreach ($match in [regex]::Matches($text, '<w:font\s[^>]*w:name="([^"]+)"')) {
        $names += $match.Groups[1].Value
      }
    }
  } finally { $zip.Dispose() }
  return @($names | Sort-Object -Unique)
}

function Get-MissingFont {
  param($Word, [string[]] $Declared)
  $installed = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  for ($i = 1; $i -le $Word.FontNames.Count; $i++) {
    $null = $installed.Add($Word.FontNames.Item($i))
  }
  return @($Declared | Where-Object { -not $installed.Contains($_) })
}

function Hide-Overlay {
  $callback = [WordWin+Proc] {
    param($handle, $lparam)
    $procId = 0
    [void][WordWin]::GetWindowThreadProcessId($handle, [ref]$procId)
    $owner = ''
    try { $owner = (Get-Process -Id $procId -ErrorAction Stop).ProcessName } catch { $owner = '' }
    if ($owner -eq 'WINWORD') {
      $class = New-Object System.Text.StringBuilder 256
      [void][WordWin]::GetClassName($handle, $class, 256)
      if ($class.ToString() -eq 'NUIDialog') {
        [void][WordWin]::ShowWindow($handle, 0)
        $script:overlayHidden++
      }
    }
    return $true
  }
  $script:overlayHidden = 0
  [void][WordWin]::EnumWindows($callback, [IntPtr]::Zero)
  return $script:overlayHidden
}

function Save-Window {
  param([IntPtr] $Handle, [string] $Path)
  $rect = New-Object RECT
  [void][WordWin]::GetWindowRect($Handle, [ref]$rect)
  $width = $rect.Right - $rect.Left
  $height = $rect.Bottom - $rect.Top
  if ($width -lt 1 -or $height -lt 1) { throw 'the Word window reports an empty rectangle' }
  $bitmap = New-Object Drawing.Bitmap($width, $height)
  $graphics = [Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
    $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
  return ($width.ToString() + 'x' + $height.ToString())
}

# --- render ---

$failure = $null
$word = $null
$doc = $null
$created = $false
$prevAlerts = $null
$pages = 0
$captures = 0
$build = ''
$caption = ''
$mode = 'pdf'
$declared = @()
$missing = @()

try {
  Write-Trace 'start'
  if (-not [Environment]::UserInteractive) {
    throw 'this payload ran in a non-interactive Windows session, where Documents.Open returns null and wedges Word for every later activation'
  }
  Write-Trace 'session interactive'
  if (-not (Test-Path -LiteralPath $requestPath)) {
    throw "no request file at $requestPath"
  }
  $request = Read-Request $requestPath
  foreach ($key in @('docx', 'pdf', 'mode')) {
    if (-not $request.ContainsKey($key)) { throw "the request names no $key" }
  }
  $mode = $request['mode']
  if ($mode -ne 'pdf' -and $mode -ne 'capture') { throw "unknown mode $mode" }
  $docx = Join-Path $job $request['docx']
  $pdf = Join-Path $job $request['pdf']
  if (-not (Test-Path -LiteralPath $docx)) { throw "no staged document at $docx" }
  if (Test-Path -LiteralPath $pdf) { Remove-Item -LiteralPath $pdf -Force }

  $declared = Get-DeclaredFont $docx
  Write-Trace ('mode ' + $mode + ', declared ' + ($declared -join ';'))
  $created = -not (Get-Process -Name WINWORD -ErrorAction SilentlyContinue)
  if ($mode -eq 'capture' -and -not $created) {
    throw 'Word is already running on that desktop, and the capture takes over its window: close it there first'
  }
  Write-Trace ('activating Word, created=' + $created)
  $word = New-Object -ComObject Word.Application
  Write-Trace 'activated'
  $prevAlerts = $word.DisplayAlerts
  $word.DisplayAlerts = 0
  $build = $word.Build
  $caption = $word.Caption
  Write-Trace ('build ' + $build + ', caption ' + $caption)
  if ($mode -eq 'pdf' -and $caption -match 'Unlicensed') {
    throw ("Word reports itself as '" + $caption + "': an unlicensed Word opens and paginates a document but blocks on every save and export behind a sign-in dialog no automation can answer, so --capture is the only route until Office is signed in on that desktop")
  }
  if ($created) { $word.Visible = ($mode -eq 'capture') }
  $missing = Get-MissingFont $word $declared
  Write-Trace ('missing ' + ($missing -join ';'))

  $doc = $word.Documents.Open($docx, $false, $false, $false)
  if ($null -eq $doc) { throw "Documents.Open returned null for $docx" }
  Write-Trace 'opened'
  foreach ($toc in $doc.TablesOfContents) { $toc.Update() }
  foreach ($tof in $doc.TablesOfFigures) { $tof.Update() }
  Write-Trace 'tables updated'
  $null = $doc.Fields.Update()
  Write-Trace 'fields updated'
  $doc.Repaginate()
  $pages = $doc.ComputeStatistics(2)
  Write-Trace ('pages ' + $pages)

  if ($mode -eq 'pdf') {
    $doc.ExportAsFixedFormat($pdf, 17, $false, 0, 0, 1, 1, 0, $true, $true, 0, $true, $true, $false)
    Write-Trace 'exported'
    if (-not (Test-Path -LiteralPath $pdf)) {
      throw "ExportAsFixedFormat wrote no file at $pdf"
    }
  } else {
    [void][WordWin]::SetProcessDPIAware()
    $first = 1
    $last = $pages
    if ($request.ContainsKey('first') -and $request['first'] -ne '') { $first = [int]$request['first'] }
    if ($request.ContainsKey('last') -and $request['last'] -ne '') { $last = [int]$request['last'] }
    if ($last -gt $pages) { $last = $pages }
    if ($first -gt $pages) { throw "the document has $pages page(s), so page $first does not exist" }

    $word.WindowState = 1
    $window = $doc.ActiveWindow
    $window.View.Type = 3
    $window.View.ShowAll = $false
    try { $window.View.FullScreen = $true } catch { Write-Trace 'full screen refused' }
    $window.ActivePane.View.Zoom.PageFit = 1
    $handle = [IntPtr]$window.Hwnd
    [void][WordWin]::SetForegroundWindow($handle)
    Start-Sleep -Milliseconds 1500
    Write-Trace ('overlays hidden ' + (Hide-Overlay))
    Start-Sleep -Milliseconds 500

    for ($page = $first; $page -le $last; $page++) {
      $target = $doc.GoTo(1, 1, $page)
      $window.ScrollIntoView($target, $true)
      Start-Sleep -Milliseconds 1200
      $null = Hide-Overlay
      $name = 'page-{0:D3}.png' -f $page
      $size = Save-Window $handle (Join-Path $job $name)
      $captures++
      Write-Trace ('captured page ' + $page + ' at ' + $size)
    }
    try { $window.View.FullScreen = $false } catch { }
  }
} catch {
  $failure = $_
} finally {
  if ($null -ne $doc) {
    try {
      $doc.Saved = $true
      $doc.Close(0)
    } catch { }
    try { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($doc) } catch { }
  }
  if ($null -ne $word) {
    try {
      if ($null -ne $prevAlerts) { $word.DisplayAlerts = $prevAlerts }
    } catch { }
    try {
      if ($created) { $word.Quit(0) }
    } catch { }
    try { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($word) } catch { }
    if ($created) {
      Start-Sleep -Milliseconds 800
      $left = @(Get-Process -Name WINWORD -ErrorAction SilentlyContinue)
      if ($left.Count -gt 0) {
        foreach ($process in $left) {
          try { Stop-Process -Id $process.Id -Force } catch { }
        }
        Write-Trace ('Quit left ' + $left.Count + ' instance(s), ended by pid')
      }
    }
  }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
  Write-Trace 'word released'
}

if ($null -ne $failure) {
  Write-Sentinel $errorPath @($failure.Exception.Message, $failure.ScriptStackTrace)
  exit 1
}

Write-Sentinel $resultPath @(
  "mode=$mode",
  "pages=$pages",
  "captures=$captures",
  "build=$build",
  "caption=$caption",
  ('declared=' + ($declared -join ';')),
  ('missing=' + ($missing -join ';'))
)
exit 0
