<#
.SYNOPSIS
    Map-Object -- Converts long-format data into wide-format data.

    Pivoting/Cross-tabulating with Grouping.

    Usage:
        Map-Object
            [-r|-RowProperty] <String[]>
            [-c|-ColumnProperty] <String>
            [-v|-ValueProperty] <String>
            [-Sum]
            [-Average]
            [-Count]
            [-Max]
            [-Min]
            [-Std|-StandardDeviation]
            [-Cast <string|int|double|decimal>]
            [-EmptyValue <value>]
            [-ReplaceComma]

.NOTES
    Group-Object (Microsoft.PowerShell.Utility) - PowerShell
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/group-object

.LINK
    Map-Object, UnMap-Object,
    Convert-DictionaryToPSCustomObject (dict2psobject),
    Edit-Property (editprop), Replace-ForEach,
    fillrety, addt, addl, addr

.EXAMPLE
    $data = @(
        [ordered]@{ Category="A"; Product="X"; Count="C.1" },
        [ordered]@{ Category="A"; Product="Y"; Count="C.5" },
        [ordered]@{ Category="A"; Product="X"; Count="C.1" }
        [ordered]@{ Category="B"; Product="Z"; Count="C.8" }
        [ordered]@{ Category="A"; Product="X"; Count="C.7" }
    ) | dict2psobject

    Category Product Count
    -------- ------- -----
    A        X       C.1
    A        Y       C.5
    A        X       C.1
    B        Z       C.8
    A        X       C.7

    # Map the data to a cross-tabulation format
    $data `
        | Map-Object -r Category -c Count -v Product `
        | ft

    Category C.1  C.5 C.7 C.8
    -------- ---  --- --- ---
    A        X, X Y   X
    B                     Z

    # Unmap the data to a cross-tabulation format
    $data `
        | Map-Object -r Category -c Count -v Product `
        | UnMap-Object -r Category -VariableColumnPrefix 'C.' -VariableColumnName "Count" `
        | ft

    Category Count Value
    -------- ----- -----
    A        C.1   X, X
    A        C.5   Y
    A        C.7   X
    A        C.8
    B        C.1
    B        C.5
    B        C.7
    B        C.8   Z


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

    $data | Map-Object -r Category -c Product -v Count -Sum -Cast int

    Category  X Y Z
    --------  - - -
    A        17 5 0
    B        15 0 8
#>
function Map-Object {
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
        [switch] $Count
        ,
        [Parameter(Mandatory=$false)]
        [switch] $Max
        ,
        [Parameter(Mandatory=$false)]
        [switch] $Min
        ,
        [Parameter(Mandatory=$false)]
        [string] $Join = ", "
        ,
        [Parameter(Mandatory=$false)]
        [Alias('Std')]
        [switch] $StandardDeviation
        ,
        [Parameter(Mandatory=$false)]
        $EmptyValue = $Null
        ,
        [Parameter(Mandatory=$false)]
        [switch] $ReplaceComma
        ,
        [Parameter(Mandatory=$false)]
        [ValidateSet(
            "string",
            "int",
            "double",
            "decimal",
            "version",
            "datetime"
        )]
        [string] $Cast = 'string'
        ,
        [Parameter(Mandatory=$false)]
        [string] $DateFormat = 'yyyy-MM-dd'
        ,
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object[]] $InputObject
    )
    # set variables
    [string] $ProxyDelimiter = '@p@r@o@x@y@'
    [string] $SplitDelimiter = ", "
    if ( $Join ){
        [string] $ConcatDelimiter = $Join
    } elseif ( $Join -eq '' ){
        [string] $ConcatDelimiter = ''
    } else {
        [string] $ConcatDelimiter = $SplitDelimiter
    }
    if ( $Sum -or $Average -or $Max -or $Min -or $StandardDeviation ) {
        if ( $Cast -notin @('int', 'double', 'decimal') ) {
            # default calc cast
            $Cast = 'double'
        }
    }
    # Combine multiple RowProperty values to create row keys
    if ( $ReplaceComma) {
        foreach ( $p in $RowProperty ) {
            $input = $input `
                | Edit-Property `
                    -Property "$p" `
                    -Expression { $([string]($_."$p")).Replace($SplitDelimiter,$ProxyDelimiter) }
        }
    }
    $RowValues = @(
        $input `
            | Group-Object $RowProperty `
            | Select-Object -ExpandProperty Name `
            | Sort-Object
            )

    # Extract unique values for columns
    $ColumnValues = $input `
        | Select-Object -ExpandProperty $ColumnProperty -Unique `
        | Sort-Object

    # Hashtable to store the cross-tabulation results
    $CrossTab = @{}

    # Create hashtables for each row key
    foreach ($RowValue in $RowValues) {
        # init hash
        $CrossTab[$RowValue] = @{}
    }

    # Aggregate data and store it in the cross-tabulation table
    foreach ($Item in $input) {
        # Combine values of multiple RowProperty to create the row key
        [string] $RowKey = @($RowProperty | ForEach-Object {$Item.$_}) -join $SplitDelimiter
        [string] $RowKey = $RowKey
        $Column = $Item.$ColumnProperty
        $Value = $Item.$ValueProperty
        if (-not $CrossTab[$RowKey].ContainsKey($Column)) {
            # init array
            $CrossTab[$RowKey][$Column] = @()
        }
        try {
            # Add the casted value into the hash table
            $CrossTab[$RowKey][$Column] += switch -Exact ( $Cast ){
                'string'   { [string]   $Value }
                'int'      { [int]      $Value }
                'double'   { [double]   $Value }
                'decimal'  { [decimal]  $Value }
                'datetime' { [datetime] $Value }
                default    { [string]   $Value }
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
        # split row properties
        foreach ($elm in @($RowProperty -split $SplitDelimiter )) {
            $o[$elm] = [string](@($RowValues -split $SplitDelimiter)[$i])
            if ( $ReplaceComma) {
                $o[$elm] = [string]($o[$elm]).Replace($SplitDelimiter, $ProxyDelimiter)
            }
            $o[$elm] = [string]($o[$elm]).Replace($ProxyDelimiter, $SplitDelimiter)
            $i++
        }
        # split column properties
        foreach ($ColumnValue in $ColumnValues) {
            [string[]] $Values = $CrossTab[$RowValue][$ColumnValue]
            switch -Exact ( $Cast ){
                'string' {
                    # values -as string
                    if ( $Count ){
                        [int] $Result = $Values.Count
                    } else {
                        [string] $Result = $Values -Join $ConcatDelimiter
                    }
                }
                default {
                    # values -as numeric
                    $Result = switch -Exact ($AggregateFunction) {
                        "Sum"     {$Values | Measure-Object -Sum     | Select-Object -ExpandProperty Sum}
                        "Average" {$Values | Measure-Object -Average | Select-Object -ExpandProperty Average}
                        "Count"   {$Values.Count}
                        "Max"     {$Values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum}
                        "Min"     {$Values | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum}
                        "Std"     {$Values | Measure-Object -StandardDeviation | Select-Object -ExpandProperty StandardDeviation}
                        default   {$Values | Measure-Object -Sum     | Select-Object -ExpandProperty Sum} # Default to Sum
                    }
                }
            }
            if ( $Result.Count -eq 0 ) {
                $Result = $EmptyValue
            }
            try {
                # cast result
                if ( $Count ){
                    $o[$ColumnValue] = [int] $Result
                } else {
                    $o[$ColumnValue] = switch -Exact ( $Cast ){
                        "string"   { [string]   $Result }
                        "int"      { [int]      $Result }
                        "double"   { [double]   $Result }
                        "decimal"  { [decimal]  $Result }
                        "datetime" { [datetime] $Result }
                        default    { [string]   $Result }
                    }
                }
            } catch {
                Write-Error $error[0] -ErrorAction stop
            }
        }
        [pscustomobject]$o
        $o = [ordered] @{}
    }
}

