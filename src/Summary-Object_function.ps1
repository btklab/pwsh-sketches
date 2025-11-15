function Summary-Object {
<#
.SYNOPSIS
    Summary-Object - Calculates basic summary statistics.

    Calculates basic summary statistics for numeric properties of pipeline objects at high speed.

.DESCRIPTION
    This function processes an object stream from the pipeline using LINQ and C#.
    It loads a companion C# file (Summary-Object_function.cs) for high-performance calculations.
    
    For each property that can be parsed as a number (or for properties specified
    with the -Property parameter), it calculates the count, mean, standard deviation,
    min, max, quantiles (Qt25, Median, Qt75), and outlier count.

.LINK
    Summary-Object,Group-Aggregate,
    Measure-Stats,Measure-Summary, Measure-Quartile,Measure-Object,
    Transpose-Property

.PARAMETER InputObject
    [System.Management.Automation.PSObject]
    The input object from the pipeline. This parameter is mandatory and accepts pipeline input.

.PARAMETER Property
    [string[]]
    An array of property names to calculate statistics for.
    If not specified, all properties on the first object that can be parsed as a
    number will be automatically targeted.

.EXAMPLE
    # Import 'iris.csv' and calculate statistics for all numeric columns.
    Import-Csv iris.csv | Summary-Object | ft

    Property     Count Mean   SD  Min Qt25 Median Qt75  Max Outlier
    --------     ----- ----   --  --- ---- ------ ----  --- -------
    sepal_length   150 5.84 0.83 4.30 5.10   5.80 6.40 7.90       0
    sepal_width    150 3.06 0.44 2.00 2.80   3.00 3.30 4.40       4
    petal_length   150 3.76 1.77 1.00 1.60   4.35 5.10 6.90       0
    petal_width    150 1.20 0.76 0.10 0.30   1.30 1.80 2.50       0

.EXAMPLE
    # Calculate statistics for 'WorkingSet' and 'PrivateMemorySize' of running processes.
    Get-Process | Summary-Object -Property WorkingSet, PrivateMemorySize

.NOTES    
    This function depends on the 'Summary-Object_function.cs' file
    being located in the same directory as this script.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]] $Property
        ,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject] $InputObject
    )

    begin {
        # Check if the C# types are already loaded in this session.
        # This prevents errors if the function is run multiple times.
        if (-not ('SummaryObject.StatisticsAggregator' -as [type])) {
            
            # Construct the path to the companion C# file.
            # $PSScriptRoot is the directory where the current script is located.
            # If $PSScriptRoot is not available (e.g., in console), use current directory.
            $scriptDir = $null
            if ($PSScriptRoot) {
                [string]$scriptDir = $PSScriptRoot
            } else {
                [string]$scriptDir = (Get-Location).Path
            }
            $csFilePath = Join-Path $scriptDir "Summary-Object_function.cs"

            if (-not (Test-Path $csFilePath)) {
                Write-Error "The required C# file was not found. Ensure 'Summary-Object_function.cs' is in the same directory as this script. Searched path: $csFilePath"
                return
            }

            try {
                # Compile the C# file.
                # We must also reference the System.Management.Automation DLL
                # because the C# code uses [PSObject].
                Add-Type -Path $csFilePath -ReferencedAssemblies "System.Management.Automation"
            }
            catch {
                Write-Error "Failed to compile C# file: $csFilePath. Error: $_"
                return
            }
        }

        # Instantiate the C# aggregator class.
        # Pass the user-provided -Property parameter to its constructor.
        $script:aggregator = [SummaryObject.StatisticsAggregator]::new($Property)
    }

    process {
        # Process block: This runs for *every* object in the pipeline.
        # We simply pass the current object ($InputObject) to the C# class.
        # All heavy lifting and state management happens in C#.
        $script:aggregator.AddObject($InputObject)
    }

    end {
        # End block: This runs *once* after all pipeline objects are processed.
        
        # Get the final list of results from the C# aggregator.
        # Each result is a Dictionary<string, object>.
        #$results = $script:aggregator.GetResult()
        [System.Collections.Hashtable[]]$results = $script:aggregator.GetResult()
        # Iterate the results and convert each dictionary to a PSCustomObject
        # for standard, user-friendly PowerShell output.
        $splatting = @{
            Property = 'Property','Count','Mean','SD','Min','Qt25','Median','Qt75','Max','Outlier'
        }
        foreach ($res in $results) {
            # This [PSCustomObject] cast automatically creates an object
            # with properties matching the dictionary keys.
            [PSCustomObject]$res | Select-Object @splatting
        }
    }
}
