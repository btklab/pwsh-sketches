<#
.SYNOPSIS
    Group-Aggregate - Groups and aggregates with LINQ via C#.
    
    Groups and aggregates CSV data using a memory-efficient
    streaming model with LINQ via C#.

.DESCRIPTION
    This function processes pipeline input object by object,
    loading a companion C# file (Group-Aggregate_function.cs) to maintain
    stateful aggregation. This avoids loading the entire dataset
    into memory, making it suitable for very large files.
    
    It supports grouping by specified columns and aggregating
    other columns using Sum, Average, Count, Max, and Min.

.PARAMETER GroupBy
    An array of column names to be used for grouping.

.PARAMETER Aggregate
    An array of column names to perform aggregation on. This is ignored when Method is 'Count'.

.PARAMETER Method
    The aggregation method to apply. Options: Sum, Average, Count, Max, Min.

.PARAMETER InputObject
    The input object from the pipeline.

.EXAMPLE
    # Group by species and calculate total sepal_length
    Import-Csv iris.csv | Group-Aggregate -GroupBy species -Aggregate sepal_length, petal_width

    species    sepal_length petal_width
    -------    ------------ -----------
    setosa           250.30       12.30
    versicolor       296.80       66.30
    virginica        329.40      101.3

.EXAMPLE
    # Group by species and calculate sum of sepal_length
    # and petal_width, including count of records
    Import-Csv iris.csv | Group-Aggregate -GroupBy species -Aggregate sepal_length, petal_width -Count -Method Sum

    species    sepal_length petal_width DataCount
    -------    ------------ ----------- ---------
    setosa           250.30       12.30        50
    versicolor       296.80       66.30        50
    virginica        329.40      101.30        50


.EXAMPLE
    # Group by Department and Region, then calculate
    # the Sum of Salary and Bonus, processing the file in a stream
    Import-Csv large_data.csv | Group-Aggregate -GroupBy Department, Region -Aggregate Salary, Bonus -Method Sum

.LINK
    Summary-Object,Group-Aggregate,
    Measure-Stats,Measure-Summary, Measure-Quartile,Measure-Object,
    Transpose-Property

.NOTES
    Author: ChatGPT, with significant modifications for streaming and memory efficiency by Gemini.
    The C# logic was refactored into a stateful class to handle stream processing.
    This function now depends on 'Group-Aggregate_function.cs' being in the same directory.
#>
function Group-Aggregate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Alias('g')]
        [string[]]$GroupBy,

        [Parameter(Mandatory=$true)]
        [Alias('a')]
        [string[]]$Aggregate,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Sum", "Average", "Count", "Max", "Min")]
        [Alias('m')]
        [string]$Method = "Sum",

        [Parameter(Mandatory=$false)]
        [Alias('c')]
        [switch]$Count,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject
    )

    begin {
        # set variable
        if ( $Method -eq 'Count' ){
            [string[]]$groupByArray = @()
            [string[]]$groupByArray += $GroupBy
            [string[]]$groupByArray += 'Count'
        } else {
            [string[]]$groupByArray = @()
            [string[]]$groupByArray += $GroupBy
            [string[]]$groupByArray += $Aggregate
        }
                
        # Check if the type exists before trying to add it
        if (-not ('StreamAggregator' -as [type])) {
            
            # Construct the path to the companion C# file.
            $scriptDir = $null
            if ($PSScriptRoot) {
                $scriptDir = $PSScriptRoot
            } else {
                $scriptDir = (Get-Location).Path
            }
            $csFilePath = Join-Path $scriptDir "Group-Aggregate_function.cs"

            if (-not (Test-Path $csFilePath)) {
                Write-Error "The required C# file was not found. Ensure 'Group-Aggregate_function.cs' is in the same directory as this script. Searched path: $csFilePath"
                return
            }

            try {
                # Compile the C# file.
                Add-Type -Path $csFilePath
            }
            catch {
                Write-Error "Failed to compile C# file: $csFilePath. Error: $_"
                return
            }
        }

        # Instantiate the C# aggregator class
        $script:aggregator = [StreamAggregator]::new($GroupBy, $Aggregate, $Method, $Count)
    }

    process {
        # Convert the current PSObject to a dictionary for the C# class
        # Explicitly create the exact Dictionary type required by the C# method
        $rowDict = [System.Collections.Generic.Dictionary[string, string]]::new()
        foreach ($prop in $InputObject.PSObject.Properties) {
            $rowDict[$prop.Name] = [string]$prop.Value
        }

        # Add the row to the aggregator. No data is stored in PowerShell lists.
        $script:aggregator.AddRow($rowDict)
    }
    
    end {
        # Get the final aggregated results from the C# object
        [System.Collections.Hashtable[]] $results = $script:aggregator.GetResult()

        # Output the results, converting each dictionary to a PSCustomObject
        if ( $Count ){
            $groupByArray += 'DataCount'
        }
        foreach ($res in $results) {
            $res | Select-Object -Property $groupByArray
         }
    }
}
