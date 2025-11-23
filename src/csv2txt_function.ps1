<#
    .SYNOPSIS
    csv2txt - Convert CSV to SSV (Space-Separated Values)
    
    Converts Comma-Separated-Values to Space-Separated-Values
    using a high-performance C# backend.

    csv2txt [-z|-NA] [-Path <String>]
        -z    : Fill blank data with "0"
        -NA  : Fill blank data with "NA"
        -Path : Specify input file path directly (Fastest mode)

    LF in cells in CSV output from Excel are converted to "\n" (literal string).

    Notes on conversion rules:
        - Output is space delimited
        - "\" converts to "\\"
        - LF converts to "\n"
        - Space in the data is converted to "_"
        - "_" in data is converted to "\_"
        - Empty fields are represented by "_" (default), "0", or "NA"

    .DESCRIPTION
    
    This function replaces the original slow string-processing approach
    with a compiled C# class.It supports two modes of operation:
    
    1. Pipeline Mode: Accepts strings or file objects from the pipeline.

       Example: cat data.csv | csv2txt

    2. Direct File Mode (-Path): Reads the file directly using C# stream readers.
       This is significantly faster for large files as it avoids PowerShell overhead.

       Example: csv2txt -Path data.csv

    .PARAMETER Path
        The path to the CSV file. using this parameter triggers the high-speed file processing mode.
    
    .PARAMETER z
        Switch to fill empty CSV cells with "0".
    
    .PARAMETER NA
        Switch to fill empty CSV cells with "NA".
        
    .EXAMPLE
        # Standard pipeline usage
       cat data.csv | csv2txt
    
    .EXAMPLE
        # Using the null placeholder options
        cat data.csv | csv2txt -z
        cat data.csv | csv2txt -NA
    
    .EXAMPLE
        # High-speed mode for large files
        csv2txt -Path large_dataset.csv
    
#>
function csv2txt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [Alias("p")]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [Alias("z")]
        [switch]$Zero,

        [Parameter(Mandatory=$false)]
        [switch]$NA,

        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object]$InputObject
    )

    begin {
        # --- 1. Determine the Null Placeholder ---
        $nullData = "_"
        if ($Zero) { $nullData = "0" }
        if ($NA) { $nullData = "NA" }

        # --- 2. Load C# Class ---
        # Locate the C# file relative to this script
        $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
        $csFilePath = Join-Path $scriptDir "csv2txt_function.cs"

        if (-not (Test-Path $csFilePath)) {
            Write-Error "Required file 'csv2txt_function.cs' not found in $scriptDir."
            return
        }

        # Compile C# if not already loaded
        if (-not ('CsvToSsvConverter' -as [type])) {
            $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
            
            # Paths to DLL and Source
            $dllFileName = "csv2txt_function.dll"
            $csFileName  = "csv2txt_function.cs"
            $dllPath = Join-Path $scriptDir $dllFileName
            $csPath  = Join-Path $scriptDir $csFileName
    
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
                Write-Warning "Compiling C# source at runtime. For better security and performance, run 'Build-ExpandDateDll.ps1' to generate the DLL."
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

        # --- 3. Initialize Processing Strategy ---
        if ($Path) {
            # Direct File Mode: No setup needed here, handled in 'end' block
            Write-Verbose "Mode: Direct File Processing (High Speed)"
        }
        else {
            # Pipeline Mode: Initialize the stateful converter
            Write-Verbose "Mode: Pipeline Processing"
            $converter = [CsvToSsvConverter]::new($nullData)
        }
    }

    process {
        if (-not $Path) {
            # Pipeline Mode Logic
            if ($InputObject -is [System.IO.FileInfo]) {
                # If user piped 'ls *.csv', read the file content
                $lines = Get-Content -Path $InputObject.FullName
                foreach ($line in $lines) {
                    $result = $converter.ProcessLine($line)
                    if ($null -ne $result) {
                        Write-Output $result
                    }
                }
            }
            else {
                # Standard string input
                $lineString = [string]$InputObject
                $result = $converter.ProcessLine($lineString)
                if ($null -ne $result) {
                    Write-Output $result
                }
            }
        }
    }

    end {
        if ($Path) {
            # Direct File Mode Logic
            # Resolve absolute path for C#
            $resolvedPath = (Resolve-Path $Path).Path

            try {
                # Execute static high-speed method
                $results = [CsvToSsvConverter]::ProcessFile($resolvedPath, $nullData)

                # Output results
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
