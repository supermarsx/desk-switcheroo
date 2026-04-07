# ===============================================================
# Desk Switcheroo - Windows Sandbox Setup & Test Runner
# This script runs inside the Windows Sandbox environment.
# It installs AutoIt, copies the project, and runs all tests.
# ===============================================================

$ErrorActionPreference = "Stop"

$projectSrc   = "C:\project"
$projectDst   = "C:\test_project"
$resultsDir   = "C:\results"
$autoitZipUrl = "https://www.autoitscript.com/cgi-bin/getfile.pl?autoit3/autoit-v3-setup.zip"
$autoitDir    = "C:\AutoIt3"
$downloadDir  = "C:\downloads"

# ---- Helper: write timestamped status lines ----
function Write-Status {
    param([string]$Message)
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] $Message"
}

# ---- Helper: write results to both console and log file ----
function Write-ResultFile {
    param(
        [string]$FileName,
        [string]$Content
    )
    $path = Join-Path $resultsDir $FileName
    Set-Content -Path $path -Value $Content -Encoding UTF8
    Write-Status "Wrote $path"
}

try {
    # ============================================================
    # 1. Create working directories
    # ============================================================
    Write-Status "Creating working directories..."
    New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
    New-Item -ItemType Directory -Force -Path $resultsDir  | Out-Null
    New-Item -ItemType Directory -Force -Path $autoitDir   | Out-Null

    # ============================================================
    # 2. Download and extract AutoIt
    # ============================================================
    Write-Status "Downloading AutoIt..."
    $zipPath = Join-Path $downloadDir "autoit-v3-setup.zip"

    # Use TLS 1.2 for the download
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $webClient = New-Object System.Net.WebClient
    try {
        $webClient.DownloadFile($autoitZipUrl, $zipPath)
        Write-Status "Download complete: $zipPath"
    }
    catch {
        Write-Status "WARNING: Primary download failed: $_"
        Write-Status "Attempting fallback download URL..."
        $fallbackUrl = "https://www.autoitscript.com/autoit3/files/archive/autoit/autoit-v3.3.16.1.zip"
        try {
            $webClient.DownloadFile($fallbackUrl, $zipPath)
            Write-Status "Fallback download complete."
        }
        catch {
            Write-Status "ERROR: All download attempts failed: $_"
            Write-ResultFile "setup_error.txt" "Failed to download AutoIt: $_"
            Write-ResultFile "exit_code.txt" "2"
            exit 2
        }
    }
    finally {
        $webClient.Dispose()
    }

    Write-Status "Extracting AutoIt..."
    Expand-Archive -Path $zipPath -DestinationPath $autoitDir -Force
    Write-Status "AutoIt extracted to $autoitDir"

    # Locate AutoIt3_x64.exe (may be in a subfolder)
    $autoitExe = Get-ChildItem -Path $autoitDir -Filter "AutoIt3_x64.exe" -Recurse | Select-Object -First 1
    if (-not $autoitExe) {
        # Fall back to 32-bit if 64-bit not found
        $autoitExe = Get-ChildItem -Path $autoitDir -Filter "AutoIt3.exe" -Recurse | Select-Object -First 1
    }
    if (-not $autoitExe) {
        Write-Status "ERROR: AutoIt3 executable not found after extraction."
        Write-Status "Contents of $autoitDir :"
        Get-ChildItem -Path $autoitDir -Recurse | ForEach-Object { Write-Status "  $($_.FullName)" }
        Write-ResultFile "setup_error.txt" "AutoIt3 executable not found after extraction."
        Write-ResultFile "exit_code.txt" "3"
        exit 3
    }
    $autoitExePath = $autoitExe.FullName
    Write-Status "Using AutoIt executable: $autoitExePath"

    # ============================================================
    # 3. Copy project to writable location
    # ============================================================
    Write-Status "Copying project to $projectDst..."
    Copy-Item -Path $projectSrc -Destination $projectDst -Recurse -Force
    Write-Status "Project copied."

    # Ensure results directory exists in the writable copy too
    $testResultsDir = Join-Path $projectDst "tests\results"
    New-Item -ItemType Directory -Force -Path $testResultsDir | Out-Null

    # ============================================================
    # 4. Run the main test suite (TestRunner.au3)
    # ============================================================
    Write-Status "Running TestRunner.au3..."
    $testRunnerScript = Join-Path $projectDst "tests\TestRunner.au3"
    $outputFile       = Join-Path $resultsDir "test_output.txt"
    $errorFile        = Join-Path $resultsDir "test_errors.txt"

    $process = Start-Process `
        -FilePath $autoitExePath `
        -ArgumentList "/ErrorStdOut", $testRunnerScript `
        -Wait -PassThru `
        -RedirectStandardOutput $outputFile `
        -RedirectStandardError $errorFile `
        -NoNewWindow

    $unitExitCode = $process.ExitCode
    Write-Status "TestRunner.au3 finished with exit code: $unitExitCode"

    # Display output in console for visibility
    if (Test-Path $outputFile) {
        Write-Status "--- Test Output ---"
        Get-Content $outputFile | ForEach-Object { Write-Host $_ }
        Write-Status "--- End Test Output ---"
    }
    if ((Test-Path $errorFile) -and (Get-Item $errorFile).Length -gt 0) {
        Write-Status "--- Test Errors ---"
        Get-Content $errorFile | ForEach-Object { Write-Host $_ }
        Write-Status "--- End Test Errors ---"
    }

    Write-ResultFile "unit_exit_code.txt" "$unitExitCode"

    # ============================================================
    # 5. Run E2E sandbox tests (E2E_Sandbox.au3)
    # ============================================================
    Write-Status "Running E2E_Sandbox.au3..."
    $e2eScript    = Join-Path $projectDst "tests\E2E_Sandbox.au3"
    $e2eOutput    = Join-Path $resultsDir "e2e_output.txt"
    $e2eErrors    = Join-Path $resultsDir "e2e_errors.txt"

    $e2eProcess = Start-Process `
        -FilePath $autoitExePath `
        -ArgumentList "/ErrorStdOut", $e2eScript `
        -Wait -PassThru `
        -RedirectStandardOutput $e2eOutput `
        -RedirectStandardError $e2eErrors `
        -NoNewWindow

    $e2eExitCode = $e2eProcess.ExitCode
    Write-Status "E2E_Sandbox.au3 finished with exit code: $e2eExitCode"

    if (Test-Path $e2eOutput) {
        Write-Status "--- E2E Output ---"
        Get-Content $e2eOutput | ForEach-Object { Write-Host $_ }
        Write-Status "--- End E2E Output ---"
    }
    if ((Test-Path $e2eErrors) -and (Get-Item $e2eErrors).Length -gt 0) {
        Write-Status "--- E2E Errors ---"
        Get-Content $e2eErrors | ForEach-Object { Write-Host $_ }
        Write-Status "--- End E2E Errors ---"
    }

    Write-ResultFile "e2e_exit_code.txt" "$e2eExitCode"

    # ============================================================
    # 6. Final summary
    # ============================================================
    $overallExit = 0
    if ($unitExitCode -ne 0) { $overallExit = 1 }
    if ($e2eExitCode -ne 0) { $overallExit = 1 }

    $summary = @"
Desk Switcheroo Sandbox Test Results
=====================================
Unit Tests (TestRunner.au3): Exit code $unitExitCode
E2E Tests  (E2E_Sandbox.au3): Exit code $e2eExitCode
Overall:   $(if ($overallExit -eq 0) { "PASS" } else { "FAIL" })
=====================================
"@
    Write-Status $summary
    Write-ResultFile "summary.txt" $summary
    Write-ResultFile "exit_code.txt" "$overallExit"
}
catch {
    Write-Status "FATAL ERROR: $_"
    Write-Status $_.ScriptStackTrace
    Write-ResultFile "setup_error.txt" "Fatal error: $_ `n$($_.ScriptStackTrace)"
    Write-ResultFile "exit_code.txt" "99"
    exit 99
}

Write-Status "Sandbox test run complete. Results written to $resultsDir"
