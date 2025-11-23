<#
.SYNOPSIS
    csv2unquote - High-performance CSV Sanitizer.
    
    Removes double quotes from CSV data while intelligently handling internal commas.
    Designed for speed using a C# backend.

.DESCRIPTION
    This function strips double quotes (`"`) from CSV data to simplify downstream processing.
    It solves the problem of commas existing inside quoted fields by transforming them
    based on context.

    Transformation Rules:
    1. Quotes (`"`): Removed entirely.
    2. Numeric Commas (e.g., "1,200"): The comma is removed -> 1200.
    3. Text Commas (e.g., "Tokyo, Japan"): The comma is replaced with a dot -> Tokyo. Japan.
    4. Newlines: Multi-line fields inside quotes are NOT supported. 
       The parser processes line-by-line. Double-quoted newlines will break the row structure.

.LINK
    csv2txt, csv2unquote, Replace-InQuote

.PARAMETER Path
    Optional. The path to a CSV file. 
    Using this parameter triggers "Direct File Mode", which is significantly faster 
    than piping data because it bypasses the PowerShell pipeline overhead.

.PARAMETER InputObject
    Input from the pipeline (e.g., Get-Content).

.EXAMPLE
    # Pipeline Mode
    Get-Content data.csv | csv2unquote

.EXAMPLE
    # Direct File Mode (Recommended for large files)
    csv2unquote -Path large_data.csv > cleaned_data.csv

.EXAMPLE
    # Input:  "1,000","apple, orange"
    # Output: 1000,apple. orange
#>
function csv2unquote {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [Alias("p")]
        [string]$Path,

        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object]$InputObject
    )

    begin {
        # --- Load C# Class ---
        # Compile the C# class if it is not already loaded in the session
        if (-not ('CsvQuoteSanitizer' -as [type])) {
            $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
            
            # Paths to DLL and Source
            [string] $libFileName = "csv2unquote_function"
            [string] $dllFileName = "$libFileName.dll"
            [string] $csFileName  = "$libFileName.cs"
            [string] $dllPath = Join-Path $scriptDir $dllFileName
            [string] $csPath  = Join-Path $scriptDir $csFileName
    
            # Try loading the DLL first (Recommended for production)
            if (Test-Path $dllPath) {
                Write-Verbose "Loading compiled assembly: $dllPath"
                try {
                    Add-Type -Path $dllPath
                }
                catch {
                    Write-Error "Failed to load assembly '$dllPath': $_"
                    return
                }
            }
            # Fallback to C# source compilation (Dev/Test only)
            elseif (Test-Path $csPath) {
                Write-Verbose "Compiled assembly not found. Falling back to runtime compilation of: $csPath"
                Write-Warning "Compiling C# source at runtime. For better security and performance, run '${libFileName}_build.ps1' to generate the DLL."
                try {
                    Add-Type -Path $csPath
                }
                catch {
                    Write-Error "Failed to compile C# file: $_"
                    return
                }
            }
            else {
                Write-Error "Could not find '$dllFileName' or '$csFileName' in $scriptDir."
                return
            }
        }

        # Initialize the converter instance for Pipeline Mode
        if (-not $Path) {
            $sanitizer = [CsvQuoteSanitizer]::new()
            Write-Verbose "Mode: Pipeline Processing"
        }
        else {
            Write-Verbose "Mode: Direct File Processing (High Speed)"
        }
    }

    process {
        # --- Pipeline Processing Logic ---
        if (-not $Path) {
            if ($InputObject -is [System.IO.FileInfo]) {
                # Case: User piped a file object (ls *.csv | csv2unquote)
                $lines = Get-Content -Path $InputObject.FullName
                foreach ($line in $lines) {
                    Write-Output $sanitizer.ProcessLine($line)
                }
            }
            else {
                # Case: User piped string data (cat data.csv | csv2unquote)
                # Ensure input is treated as a string
                $lineString = [string]$InputObject
                Write-Output $sanitizer.ProcessLine($lineString)
            }
        }
    }

    end {
        # --- Direct File Processing Logic ---
        if ($Path) {
            $resolvedPath = (Resolve-Path $Path).Path

            try {
                # Call the static C# method for maximum throughput
                $results = [CsvQuoteSanitizer]::ProcessFile($resolvedPath)

                foreach ($line in $results) {
                    Write-Output $line
                }
            }
            catch {
                Write-Error "Error processing file '$resolvedPath': $_"
            }
        }
    }
}
