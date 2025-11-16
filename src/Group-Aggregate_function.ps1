<#
.SYNOPSIS
    Group-Aggregate - Groups and aggregates CSV data with high performance.
    
    Groups and aggregates CSV data using a high-speed C# backend.
    Supports both pipeline input (slower) and direct file path (fastest).

.DESCRIPTION
    This function processes data in one of two modes:

    1. Pipeline Mode (Default):
       Processes objects from the pipeline (e.g., from Import-Csv).
       This is flexible but slower due to PowerShell-to-C# overhead for each row.
    
    2. File Mode (-Path):
       Reads the CSV file directly using a high-performance C# parser.
       This bypasses Import-Csv entirely and is *significantly* faster
       for large files.

    It supports grouping by specified columns and aggregating
    other columns using Sum, Average, Count, Max, and Min.
    
    Depends on 'Group-Aggregate_function.cs' being in the same directory.

.PARAMETER GroupBy
    An array of column names to be used for grouping.

.PARAMETER Aggregate
    An array of column names to perform aggregation on. 
    This is ignored when Method is 'Count'.

.PARAMETER Method
    The aggregation method to apply. Options: Sum, Average, Count, Max, Min.

.PARAMETER Path
    Specifies the path to the CSV file to be processed.
    Using this parameter enables the high-speed C# file processing mode.

.PARAMETER InputObject
    The input object from the pipeline (used in Pipeline Mode).

.PARAMETER Count
    A switch to add a "DataCount" column to the output,
    showing the number of records in each group.

.EXAMPLE
    # EXAMPLE 1: High-speed file mode (Recommended)
    # Reads 'iris.csv' directly using C# for maximum speed.
    Group-Aggregate -Path .\iris.csv -GroupBy species -Aggregate sepal_length, petal_width -Method Sum -Count

    species    sepal_length petal_width DataCount
    -------    ------------ ----------- ---------
    setosa           250.30       12.30        50
    versicolor       296.80       66.30        50
    virginica        329.40      101.30        50

.EXAMPLE
    # EXAMPLE 2: Pipeline mode (Slower, but flexible)
    # This is the original behavior. Good for smaller datasets or complex pre-filtering.
    Import-Csv .\iris.csv | Group-Aggregate -GroupBy species -Aggregate sepal_length, petal_width -Method Sum

    species    sepal_length petal_width
    -------    ------------ -----------
    setosa           250.30       12.30
    versicolor       296.80       66.30
    virginica        329.40      101.30

.EXAMPLE
    # EXAMPLE 3: High-speed file mode, counting groups
    Group-Aggregate -Path .\large_data.csv -GroupBy Department, Region -Method Count

    Department Region  Count
    ---------- ------  -----
    Sales      North   1502
    IT         South   890
    ...

.LINK
    Summary-Object,Group-Aggregate,
    Measure-Stats,Measure-Summary, Measure-Quartile,Measure-Object,
    Transpose-Property

.NOTES
    Author: ChatGPT, with significant modifications for streaming and performance by Gemini.
    The C# logic was refactored into a public 'CsvProcessor' class
    to handle both pipeline and direct file access paths.
#>
function Group-Aggregate {
    [CmdletBinding(DefaultParameterSetName = 'Pipeline')]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [Alias('g')]
        [string[]]$GroupBy,

        [Parameter(Mandatory=$true, Position=1)]
        [Alias('a')]
        [string[]]$Aggregate,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Sum", "Average", "Count", "Max", "Min")]
        [Alias('m')]
        [string]$Method = "Sum",

        [Parameter(Mandatory=$false, ParameterSetName = 'File')]
        [Alias('p')]
        [string]$Path = '',

        [Parameter(Mandatory=$false, ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
        [object]$InputObject,

        [Parameter(Mandatory=$false)]
        [Alias('c')]
        [switch]$Count
    )

    begin {
        # --- C# Compilation (runs once) ---
        
        # Check if the C# helper class is already compiled in this session
        if (-not ('CsvProcessor' -as [type])) {
            
            # Find the C# file relative to this script
            $scriptDir = $null
            if ($PSScriptRoot) {
                $scriptDir = $PSScriptRoot
            } else {
                # Fallback for interactive/ISE sessions
                $scriptDir = (Get-Location).Path
            }
            $csFilePath = Join-Path $scriptDir "Group-Aggregate_function.cs"

            if (-not (Test-Path $csFilePath)) {
                Write-Error "The required C# file was not found. Ensure 'Group-Aggregate_function.cs' is in the same directory as this script. Searched path: $csFilePath"
                return
            }

            try {
                # Compile the C# file into memory
                Add-Type -Path $csFilePath
            }
            catch {
                Write-Error "Failed to compile C# file: $csFilePath. Error: $_"
                return
            }
        }

        # --- Initialization based on ParameterSet ---
        
        # If we are in Pipeline mode, we must create an aggregator instance
        # to store the state as rows come in.
        if ($PSCmdlet.ParameterSetName -eq 'Pipeline') {
            # Instantiate the C# aggregator class via the static factory method
            $aggregator = [CsvProcessor]::CreateAggregator($GroupBy, $Aggregate, $Method, $Count)
        }
        
        # Determine the final list of columns to output
        if ( $Method -eq 'Count' ){
            [string[]]$outputColumns = @()
            $outputColumns += $GroupBy
            $outputColumns += 'Count'
        } else {
            [string[]]$outputColumns = @()
            $outputColumns += $GroupBy
            $outputColumns += $Aggregate
        }
        if ( $Count ){
            $outputColumns += 'DataCount'
        }
    }

    process {
        if ( $Path -eq '' ){
            # This block ONLY runs for the 'Pipeline' ParameterSet.
            # It is skipped entirely when -Path is used.
            
            # Convert the current PSObject to a dictionary for the C# class
            $rowDict = [System.Collections.Generic.Dictionary[string, string]]::new()
            foreach ($prop in $InputObject.PSObject.Properties) {
                $rowDict[$prop.Name] = [string]$prop.Value
            }

            # Add the row to the C# aggregator instance
            $aggregator.AddRow($rowDict)
        }
    }
    
    end {
        # This block runs once, after all 'process' blocks (for pipeline)
        # or immediately after 'begin' (for file mode).

        [System.Collections.Generic.List[System.Collections.Generic.Dictionary[string, object]]] $results = $null

        try {
            # --- Get Results based on ParameterSet ---
            if ($PSCmdlet.ParameterSetName -eq 'Pipeline') {
                # Get final results from the stateful aggregator
                if ($null -ne $aggregator) {
                    $results = $aggregator.GetResult()
                }
            }
            else {
                # ($PSCmdlet.ParameterSetName -eq 'File')
                # Call the high-speed static method to process the entire file at once

                # FIX: Resolve the relative path to an absolute path before passing it to C#.
                # This ensures the C# System.IO.StreamReader can find the file correctly.
                $absolutePath = (Resolve-Path $Path).Path
                
                Write-Verbose "Using high-speed C# processor for file: $absolutePath"
                $results = [CsvProcessor]::ProcessFile($absolutePath, $GroupBy, $Aggregate, $Method, $Count)
            }
        }
        catch {
            Write-Error "An error occurred during C# aggregation: $_"
            return
        }

        # --- Output Formatting (common to both modes) ---
        if ($null -eq $results) {
            Write-Verbose "No results to output."
            return
        }

        Write-Verbose "Aggregation complete. Formatting $(@($results).Count) result rows."

        # FIX: Revert to PowerShell's simpler, more stable type conversion.
        try {
            # This cast iterates the C# List and converts each C# Dictionary into a PowerShell Hashtable.
            [System.Collections.Hashtable[]]$convertedResults = $results

            # Now, $convertedResults is an array of PowerShell Hashtables.
            # Pipe these directly to Select-Object to get the final PSCustomObject output.
            foreach ($res in $convertedResults) {
                # $res is a Hashtable.
                $res | Select-Object -Property $outputColumns
            }
        }
        catch {
            Write-Error "Failed to convert C# results to PowerShell objects. Error: $_"
            return
        }
    }
}