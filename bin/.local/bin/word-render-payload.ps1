#Requires -Version 5.1
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$job = Split-Path -Parent $MyInvocation.MyCommand.Definition
$requestPath = Join-Path $job 'request'
$resultPath = Join-Path $job 'result.txt'
$errorPath = Join-Path $job 'error.txt'
$tracePath = Join-Path $job 'trace'

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

# --- export ---

$failure = $null
$word = $null
$doc = $null
$created = $false
$prevAlerts = $null
$pages = 0
$build = ''
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
  foreach ($key in @('docx', 'pdf')) {
    if (-not $request.ContainsKey($key)) { throw "the request names no $key" }
  }
  $docx = Join-Path $job $request['docx']
  $pdf = Join-Path $job $request['pdf']
  if (-not (Test-Path -LiteralPath $docx)) { throw "no staged document at $docx" }
  if (Test-Path -LiteralPath $pdf) { Remove-Item -LiteralPath $pdf -Force }

  $declared = Get-DeclaredFont $docx
  Write-Trace ('declared ' + ($declared -join ';'))
  $created = -not (Get-Process -Name WINWORD -ErrorAction SilentlyContinue)
  Write-Trace ('activating Word, created=' + $created)
  $word = New-Object -ComObject Word.Application
  Write-Trace 'activated'
  if ($created) { $word.Visible = $false }
  $prevAlerts = $word.DisplayAlerts
  $word.DisplayAlerts = 0
  $build = $word.Build
  $caption = $word.Caption
  Write-Trace ('build ' + $build + ', caption ' + $caption)
  if ($caption -match 'Unlicensed') {
    throw ("Word reports itself as '" + $caption + "': an unlicensed Word opens and paginates a document but blocks on every save and export behind a sign-in dialog no automation can answer, so this control cannot run until Office is signed in on that desktop")
  }
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
  $doc.ExportAsFixedFormat($pdf, 17, $false, 0, 0, 1, 1, 0, $true, $true, 0, $true, $true, $false)
  Write-Trace 'exported'
  if (-not (Test-Path -LiteralPath $pdf)) {
    throw "ExportAsFixedFormat wrote no file at $pdf"
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
  "pages=$pages",
  "build=$build",
  ('declared=' + ($declared -join ';')),
  ('missing=' + ($missing -join ';'))
)
exit 0
