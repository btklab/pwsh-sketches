function Summary-Object {
<#
.SYNOPSIS
    Summary-Object - Calculates basic summary statistics
    .
    Calculates basic summary statistics for numeric properties from a pipeline or a CSV file.

.DESCRIPTION
    This function processes data in one of two modes:

    1. Pipeline Mode (Default):
       Processes objects from the pipeline (e.g., from Import-Csv).
       This is flexible but slower due to PowerShell-to-C# overhead for each row.
    
    2. File Mode (-Path):
       Reads the CSV file directly using a high-performance C# parser.
       This bypasses Import-Csv entirely and is significantly faster for large files.

    For each property that can be parsed as a number (or for properties specified
    with the -Property parameter), it calculates the count, mean, standard deviation,
    min, max, quantiles (Qt25, Median, Qt75), and outlier count.
    
    This function depends on the 'Summary-Object_function.cs' file
    being located in the same directory as this script.

.PARAMETER Property
    An array of property names to calculate statistics for.
    If not specified (in either mode), all properties on the first object/row 
    that can be parsed as a number will be automatically targeted.

.PARAMETER Path
    Specifies the path to the CSV file to be processed.
    Using this parameter enables the high-speed C# file processing mode.

.PARAMETER InputObject
    The input object from the pipeline. This parameter is mandatory for the 
    'Pipeline' parameter set.

.EXAMPLE
    # EXAMPLE 1: High-speed file mode (Recommended for large files)
    # Reads 'iris.csv' directly using C# and auto-detects all numeric columns.
    Summary-Object -Path iris.csv | ft

    Property     Count   SD  Min Qt25 Median Mean Qt75  Max Outlier
    --------     -----   --  --- ---- ------ ---- ----  --- -------
    petal_length   150 1.77 1.00 1.60   4.35 3.76 5.10 6.90       0
    petal_width    150 0.76 0.10 0.30   1.30 1.20 1.80 2.50       0
    sepal_length   150 0.83 4.30 5.10   5.80 5.84 6.40 7.90       0
    sepal_width    150 0.44 2.00 2.80   3.00 3.06 3.30 4.40       4

.EXAMPLE
    # EXAMPLE 2: High-speed file mode, specifying properties
    # Reads 'iris.csv' but only calculates stats for 'sepal_length' and 'petal_length'.
    Summary-Object -Path iris.csv -Property sepal_length, petal_length | ft

    Property     Count   SD  Min Qt25 Median Mean Qt75  Max Outlier
    --------     -----   --  --- ---- ------ ---- ----  --- -------
    petal_length   150 1.77 1.00 1.60   4.35 3.76 5.10 6.90       0
    sepal_length   150 0.83 4.30 5.10   5.80 5.84 6.40 7.90       0

.EXAMPLE
    # EXAMPLE 3: Pipeline mode (Slower, but flexible)
    # This is the original behavior. Good for smaller datasets or non-CSV input.
    Import-Csv iris.csv | Summary-Object | Format-Table

.EXAMPLE
    # EXAMPLE 4: Pipeline mode with other commands
    # Calculate statistics for 'WorkingSet' and 'PrivateMemorySize' of running processes.
    Get-Process | Summary-Object -Property WorkingSet, PrivateMemorySize

.LINK
    Summary-Object,Group-Aggregate,
    Measure-Stats,Measure-Summary, Measure-Quartile,Measure-Object,
    Transpose-Property

.NOTES    
    Author: ChatGPT, with significant modifications for performance and
    file-based processing by Gemini.
#>
    [CmdletBinding(DefaultParameterSetName = 'Pipeline')]
    param(
        [Parameter(Mandatory = $false)]
        [string[]] $Property,

        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [Alias('p')]
        [string]$Path = '',

        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
        [psobject] $InputObject
    )

    begin {
        # --- C# Compilation (runs once) ---

        # Check if the C# helper class is already compiled in this session
        # We check for the new static class name.
        if (-not ('SummaryObjectProcessor.CsvSummaryProcessor' -as [type])) {
            
            # Construct the path to the companion C# file.
            # $PSScriptRoot is the directory where the current script is located.
            $scriptDir = $null
            if ($PSScriptRoot) {
                [string]$scriptDir = $PSScriptRoot
            } else {
                # Fallback for interactive/ISE sessions
                [string]$scriptDir = (Get-Location).Path
            }
            $csFilePath = Join-Path $scriptDir "Summary-Object_function.cs"

            if (-not (Test-Path $csFilePath)) {
                Write-Error "The required C# file was not found. Ensure 'Summary-Object_function.cs' is in the same directory as this script. Searched path: $csFilePath"
                return
            }
            try {
                # Compile the C# file into memory.
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
            $aggregator = [SummaryObjectProcessor.CsvSummaryProcessor]::CreateAggregator($Property)
        }
    }


    process {
        if ( $Path -eq '' ){
            # Process block: This runs for *every* object in the pipeline.
            # It is skipped entirely when -Path is used.
            if ($PSCmdlet.ParameterSetName -eq 'Pipeline') {
                # We simply pass the current object ($InputObject) to the C# class.
                # All heavy lifting and state management happens in C#.
                $aggregator.AddObject($InputObject)
            }
        }
    }

    end {
        # End block: This runs *once* after all pipeline objects are processed
        # or immediately after 'begin' (for file mode).
        
        [System.Collections.IList]$results = $null # Results are List<OrderedDictionary>

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
                
                # Resolve the relative path to an absolute path before passing it to C#.
                $absolutePath = (Resolve-Path $Path).Path
                
                Write-Verbose "Using high-speed C# summary processor for file: $absolutePath"
                # Pass the -Property parameter to the C# processor
                $results = [SummaryObjectProcessor.CsvSummaryProcessor]::ProcessFile($absolutePath, $Property)
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

        # Define the exact order of properties for the output object.
        $outputColumns = @(
            'Property',
            'Count',
            'SD',
            'Min',
            'Qt25',
            'Median',
            'Mean',
            'Qt75',
            'Max',
            'Outlier'
        )
        
        # $results is a List<OrderedDictionary>.
        # We can cast it to an array of Hashtables for PowerShell.
        [System.Collections.Hashtable[]]$convertedResults = $results

        foreach ($res in $convertedResults) {
            # $res is now a Hashtable.
            # Pipe to Select-Object to ensure property order and create a PSCustomObject.
            $res | Select-Object -Property $outputColumns
        }
    }
}
