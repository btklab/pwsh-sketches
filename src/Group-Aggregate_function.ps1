<#
.SYNOPSIS
    Group-Aggregate - Groups and aggregates with LINQ via C#.
    
    Groups and aggregates CSV data using a memory-efficient
    streaming model with LINQ via embedded C#.

.DESCRIPTION
    This function processes pipeline input object by object,
    using an inline C# class to maintain stateful aggregation.
    This avoids loading the entire dataset into memory, making
    it suitable for very large files.
    
    It supports grouping by specified columns and aggregating
    other columns using Sum, Average, Count, Max, and Min.

.PARAMETER GroupBy
    An array of column names to be used for grouping.

.PARAMETER Aggregate
    An array of column names to perform aggregation on. This is ignored when Method is 'Count'.

.PARAMETER Method
    The aggregation method to apply. Options: Sum, Average, Count, Max, Min.

.EXAMPLE
    # Group by Department and Region, then calculate the Sum of Salary and Bonus, processing the file in a stream
    Import-Csv large_data.csv | Group-Aggregate -GroupBy Department, Region -Aggregate Salary, Bonus -Method Sum

.LINK
    Group-Aggregate, Group-AggregateSimple

.NOTES
    Author: ChatGPT, with significant modifications for streaming and memory efficiency by Gemini.
    The C# logic was refactored into a stateful class to handle stream processing.
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
        # private function to convert dictionary to PSCustomObject
        function ConvDict2Obj {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
                [object[]] $Dictionary,
                [Parameter(Mandatory=$false)]
                [switch] $Recurse
            )
            process {
                # check input hash type
                try {
                    [System.Collections.Specialized.OrderedDictionary[]]$Hash = $Dictionary
                } catch {
                    try {
                        [System.Collections.Hashtable[]]$Hash = $Dictionary
                    } catch {
                        Write-Error $Error -ErrorAction Stop
                    }
                }
                foreach ( $eHash in $Hash) {
                    $oHash = [ordered] @{}
                    foreach ($key in $eHash.Keys) {
                        if ($eHash[$key] -as [System.Collections.Specialized.OrderedDictionary[]] -and $Recurse){
                            $oHash[$key] = $(Convert-DictionaryToPSCustomObject $eHash[$key] -Recurse)
                        } elseif ($Hash[$key] -as [System.Collections.Hashtable[]] -and $Recurse){
                            $oHash[$key] = $(Convert-DictionaryToPSCustomObject $eHash[$key] -Recurse)
                        } else {
                            $oHash[$key] = ($eHash[$Key])
                        }
                    }
                }
                [PSCustomObject]$oHash
            }
        }
        # Check if the type exists before trying to add it
        if (-not ('StreamAggregator' -as [type])) {
            $csCode = @"
using System;
using System.Collections.Generic;
using System.Linq;

// A stateful class to handle stream-based aggregation
public class StreamAggregator {
    // Internal class to hold intermediate aggregation data for each group
    private class GroupData {
        public long Count = 0;
        public Dictionary<string, double> Sums = new Dictionary<string, double>();
        public Dictionary<string, double> MaxValues = new Dictionary<string, double>();
        public Dictionary<string, double> MinValues = new Dictionary<string, double>();
        public readonly string[] KeyParts; // Store the original group-by values

        public GroupData(string[] keyParts, string[] aggregateColumns) {
            KeyParts = keyParts;
            foreach (var col in aggregateColumns) {
                Sums[col] = 0;
                MaxValues[col] = double.MinValue;
                MinValues[col] = double.MaxValue;
            }
        }
    }

    private readonly string[] _groupBy;
    private readonly string[] _aggregate;
    private readonly string _method;
    private readonly bool _count; // This flag indicates if an additional DataCount column should be added
    private readonly Dictionary<string, GroupData> _results;
    private const string keySeparator = "<|>";

    public StreamAggregator(string[] groupBy, string[] aggregate, string method, bool count = false) {
        _groupBy = groupBy;
        _aggregate = aggregate;
        _method = method;
        _count = count;
        _results = new Dictionary<string, GroupData>();
    }

    // Process a single row at a time
    public void AddRow(Dictionary<string, string> row) {
        var keyParts = _groupBy.Select(c => row.ContainsKey(c) ? row[c] : "").ToArray();
        var compositeKey = string.Join(keySeparator, keyParts);

        if (!_results.ContainsKey(compositeKey)) {
            _results[compositeKey] = new GroupData(keyParts, _aggregate);
        }

        var groupData = _results[compositeKey];
        groupData.Count++; // Increment count for this group

        // Only perform sum/min/max if the aggregation method is not "Count"
        if (_method != "Count") {
            foreach (var aggColumn in _aggregate) {
                if (row.ContainsKey(aggColumn) && double.TryParse(row[aggColumn], out var value)) {
                    groupData.Sums[aggColumn] += value;
                    if (value > groupData.MaxValues[aggColumn]) groupData.MaxValues[aggColumn] = value;
                    if (value < groupData.MinValues[aggColumn]) groupData.MinValues[aggColumn] = value;
                }
            }
        }
    }

    // Finalize the aggregation and return the results
    public List<Dictionary<string, object>> GetResult() {
        var finalResults = new List<Dictionary<string, object>>();

        foreach (var groupData in _results.Values) {
            if (groupData.Count == 0) continue; // Skip empty groups

            var resultRow = new Dictionary<string, object>();
            // Add group-by columns to the result row
            for (int i = 0; i < _groupBy.Length; i++) {
                resultRow[_groupBy[i]] = groupData.KeyParts[i];
            }

            // Handle the primary aggregation method (Sum, Average, Max, Min, or Count)
            if (_method == "Count") {
                // If the method is "Count", the primary aggregated value is the group count
                resultRow["Count"] = groupData.Count;
            } else {
                // For other methods, calculate based on sums, max, or min values
                foreach (var aggColumn in _aggregate) {
                    if (groupData.Sums.ContainsKey(aggColumn)) {
                        double result = 0;
                        switch (_method) {
                            case "Sum":     result = groupData.Sums[aggColumn]; break;
                            case "Average": result = groupData.Sums[aggColumn] / groupData.Count; break;
                            case "Max":     result = groupData.MaxValues[aggColumn]; break;
                            case "Min":     result = groupData.MinValues[aggColumn]; break;
                        }
                        //resultRow[aggColumn] = Math.Round(result, 2);
                        resultRow[aggColumn] = result; // Add the aggregated value
                    }
                }
            }

            // Add DataCount column if _count is true, regardless of the primary aggregation method.
            // This ensures DataCount is always present when requested, even if _method is "Count".
            if (_count == true) {
                resultRow["DataCount"] = groupData.Count;
            }

            finalResults.Add(resultRow);
        }
        return finalResults;
    }
}
"@
            Add-Type -TypeDefinition $csCode -Language CSharp
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
        $results = $script:aggregator.GetResult()

        # Output the results, converting each dictionary to a PSCustomObject
        if ( $Count ){
            $groupByArray += 'DataCount'
        }
        foreach ($res in $results) {
            #[PSCustomObject]$res
            $res `
                | ConvDict2Obj `
                | Select-Object -Property $groupByArray
         }
    }
}
