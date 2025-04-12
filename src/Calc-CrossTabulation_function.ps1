<#
.SYNOPSIS
    Calc-CrossTabulation -- Cross-tabulate Data.

    Expand a long-format data into a wide-format data.
    The key column must not contain a comma and a space (", ").
    There is no need to pre-sort or deduplicate the key column.

    Usage:
        Calc-CrossTabulation
            [-r|-RowProperty] <String[]>
            [-c|-ColumnProperty] <String>
            [-v|-ValueProperty] <String>
            [-Sum]
            [-Mean|-Average]
            [-Median]
            [-Count]
            [-Max]
            [-Min]
            [-Std|-StandardDeviation]
            [-EmptyValue <Double>]
            [-Cast <int|double|decimal>]
            [-ReplaceComma]
            [-DropNA]
            [-ReplaceNA <regex>]

.LINK
    Convert-DictionaryToPSCustomObject (dict2psobject),
    Edit-Property (editprop), Get-Dataset (dataset)

.EXAMPLE
    $data = @(
        [ordered] @{ Category="A"; Product="X"; Count=10 },
        [ordered] @{ Category="A"; Product="Y"; Count=5  },
        [ordered] @{ Category="B"; Product="X"; Count=15 },
        [ordered] @{ Category="B"; Product="Z"; Count=8  },
        [ordered] @{ Category="A"; Product="X"; Count=7  }
    ) | dict2psobject

    Category Product Count
    -------- ------- -----
    A        X          10
    A        Y           5
    B        X          15
    B        Z           8
    A        X           7

    $data | Calc-CrossTabulation -r Category -c Product -v Count

    Category     X    Y    Z
    --------     -    -    -
    A        17.00 5.00 0.00
    B        15.00 0.00 8.00

#>
function Calc-CrossTabulation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [Alias('r')]
        [string[]] $RowProperty
        ,
        [Parameter(Mandatory=$true, Position=1)]
        [Alias('c')]
        [string] $ColumnProperty
        ,
        [Parameter(Mandatory=$true, Position=2)]
        [Alias('v')]
        [string] $ValueProperty
        ,
        [Parameter(Mandatory=$false)]
        [switch] $Sum
        ,
        [Parameter(Mandatory=$false)]
        [Alias('Mean')]
        [switch] $Average
        ,
        [Parameter(Mandatory=$false)]
        [switch] $Median
        ,
        [Parameter(Mandatory=$false)]
        [switch] $Count
        ,
        [Parameter(Mandatory=$false)]
        [switch] $Max
        ,
        [Parameter(Mandatory=$false)]
        [switch] $Min
        ,
        [Parameter(Mandatory=$false)]
        [Alias('Std')]
        [switch] $StandardDeviation
        ,
        [Parameter(Mandatory=$false)]
        [double] $EmptyValue = 0
        ,
        [Parameter(Mandatory=$false)]
        [ValidateSet("int", "double", "decimal")]
        [string] $Cast = "double"
        ,
        [Parameter(Mandatory=$false)]
        [switch] $ReplaceComma
        ,
        [Parameter(Mandatory=$false)]
        [switch] $DropNA
        ,
        [Parameter(Mandatory=$false)]
        [string] $ReplaceNA
        ,
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object[]] $InputObject
    )
    # private function
    ## Function to get the median of an array
    function Get-Median {
        param (
            [Parameter(Mandatory=$true)]
            [double[]] $Numbers # Input array, specified as double type
        )
        # Get the number of elements in the array
        [int] $dataCount = $Numbers.Count
        # Handle the case where the array is empty
        if ($dataCount -eq 0) {
            #Write-Error "Array is empty. Cannot calculate the median." -ErrorAction SilentlyContinue
            return $Null # Returns $null in case of error, which is common
        }
        # Sort the array (necessary for median calculation)
        [double[]] $sortedNumbers = $Numbers | Sort-Object
        # If the number of elements is odd
        if ($dataCount % 2 -eq 1) {
            # The middle element is the median
            [double] $medianVal = $sortedNumbers[($dataCount - 1) / 2]
        } else {
            # If the number of elements is even
            # The average of the two middle elements is the median
            [double] $middleVal1 = $sortedNumbers[$dataCount / 2 - 1]
            [double] $middleVal2 = $sortedNumbers[$dataCount / 2]
            # Divide by 2.0 to ensure the result is a double
            [double] $medianVal = ($middleVal1 + $middleVal2) / 2.0
        }
        return $medianVal
    }
    # set variable
    [string] $ProxyDelimiter = '@p@r@o@x@y@'
    [string] $SplitDelimiter = ", "
    if ( $Count ) {
        $Cast = 'int'
    }
    # Combine multiple RowProperty values to create row keys
    if ( $ReplaceComma) {
        foreach ( $p in $RowProperty ) {
            $input = $input | Edit-Property -Property "$p" -Expression { $([string]($_."$p")).Replace($SplitDelimiter,$ProxyDelimiter)}
        }
    }
    $RowValues = @($input | Group-Object $RowProperty | Select-Object -ExpandProperty Name | Sort-Object)

    # Extract unique values for columns
    $ColumnValues = $input | Select-Object -ExpandProperty $ColumnProperty -Unique | Sort-Object

    # Hashtable to store the cross-tabulation results
    $CrossTab = @{}

    # Create hashtables for each row key
    foreach ($RowValue in $RowValues) {
        $CrossTab[$RowValue] = @{}
    }

    # Aggregate data and store it in the cross-tabulation table
    foreach ($Item in $input) {
        # Combine values of multiple RowProperty to create the row key
        [string] $RowKey = @($RowProperty | ForEach-Object {$Item.$_}) -join $SplitDelimiter
        [string] $RowKey = $RowKey
        $Column = $Item.$ColumnProperty
        $Value = $Item.$ValueProperty
        if ( $DropNA ){
            # check for NA values
            if ( $Value -match '^NA$|^NaN$' ) {
                # skip NA values
                $Value = $Null
            }
        } elseif ( $ReplaceNA ){
            # replace NA values
            if ( $Value -match '^NA$|^NaN$' ) {
                # replace NA values
                $Value = $Value -replace '^NA$|^NaN$', $ReplaceNA
            }
        }
        if (-not $CrossTab[$RowKey].ContainsKey($Column)) {
            # init array
            $CrossTab[$RowKey][$Column] = @()
        }
        try {
            # Add the casted value into the hash table
            $CrossTab[$RowKey][$Column] += switch -Exact ( $Cast ){
                'int'      { [int]      $Value }
                'double'   { [double]   $Value }
                'decimal'  { [decimal]  $Value }
                default    { [int]      $Value }
            }
        } catch {
            #Write-Error "Failed to add value '$Value' to CrossTab for RowKey '$RowKey' and Column '$Column'."
            Write-Error $error[0] -ErrorAction stop
        }
        Write-Debug "cast=$Cast; key=$RowKey; col=$Column; val=$($CrossTab[$RowKey][$Column] -join ', ')"
    }

    # Display the results
    if ( $Sum ){
        [string] $AggregateFunction = "Sum"
    } elseif ($Average) {
        [string] $AggregateFunction = "Average"
    } elseif ($Median) {
        [string] $AggregateFunction = "Median"
    } elseif ($Count) {
        [string] $AggregateFunction = "Count"
    } elseif ($Max) {
        [string] $AggregateFunction = "Max"
    } elseif ($Min) {
        [string] $AggregateFunction = "Min"
    } elseif ($StandardDeviation) {
        [string] $AggregateFunction = "Std"
    } else {
        [string] $AggregateFunction = 'Sum'
    }
    
    $o = [ordered] @{}
    [int] $i = 0
    foreach ($RowValue in $CrossTab.Keys | Sort-Object) {
        #$o[($RowProperty -join ", ")] = $RowValue
        foreach ($elm in @($RowProperty -split $SplitDelimiter )) {
            $o[$elm] = [string](@($RowValues -split $SplitDelimiter)[$i])
            if ( $ReplaceComma) {
                $o[$elm] = [string]($o[$elm]).Replace($SplitDelimiter,$ProxyDelimiter)
            }
            $o[$elm] = [string]($o[$elm]).Replace($ProxyDelimiter,$SplitDelimiter)
            $i++
        }
        foreach ($ColumnValue in $ColumnValues) {
            $Values = $CrossTab[$RowValue][$ColumnValue]
            if ( $Values.Count -eq 0 ) {
                $Result = $EmptyValue
            } else {
                $Result = switch -Exact ($AggregateFunction) {
                    "Sum"     {$Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum}
                    "Average" {$Values | Measure-Object -Average | Select-Object -ExpandProperty Average}
                    "Median"  {Get-Median $Values}
                    "Count"   {$Values.Count}
                    "Max"     {$Values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum}
                    "Min"     {$Values | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum}
                    "Std"     {$Values | Measure-Object -StandardDeviation | Select-Object -ExpandProperty StandardDeviation}
                    default   {$Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum} # Default to Sum
                }
                if ( $Result -eq $null ) {
                    $Result = $EmptyValue
                }
            }
            try {
                if ( $Cast ){
                    $Result = switch -Exact ( $Cast ) {
                        "int"     {[int]     $Result}
                        "double"  {[double]  $Result}
                        "decimal" {[decimal] $Result}
                        default   {$Result} # Default as-is
                    }
                }
                $o[$ColumnValue] = $Result
            } catch {
                Write-Error $error[0] -ErrorAction stop
            }
        }
        [pscustomobject]$o
        $o = [ordered] @{}
    }
}

