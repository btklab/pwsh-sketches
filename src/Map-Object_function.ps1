<#
.SYNOPSIS
    Map-Object (Alias: long2wide) -- Converts long-format data into wide-format data.

    Pivoting/Cross-tabulating with Grouping.

    Usage:
        Map-Object
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
            [-Ratio]

            [-Cast <string|int|double|decimal>]
            [-EmptyValue <value>]
            [-ReplaceComma]

            [-rsort|-RowSort <string|int|double|decimal>]
            [-csort|-ColSort <string|int|double|decimal>]
            [-vsort|-ValSort <string|int|double|decimal>]

            [-rdrop|-DropRowNA]
            [-cdrop|-DropColNA]
            [-vdrop|-DropValNA]

            [-rrep|-ReplaceRowNA <string>]
            [-crep|-ReplaceColNA <string>]
            [-vrep|-ReplaceValNA <string>]

.NOTES
    Group-Object (Microsoft.PowerShell.Utility) - PowerShell
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/group-object

.LINK
    Map-Object, UnMap-Object, Cross-CrossTabulation,
    Convert-DictionaryToPSCustomObject (dict2psobject),
    Edit-Property (editprop), Replace-ForEach,
    fillretu, addt, addl, addr

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

.EXAMPLE
    # Group aggregation by converting between long and wide formats.
    
    ## input data (csv)
    $widedata = @(
    "name,val1,val2,val3",
    "A,10,20,30",
    "B,15,25,35",
    "A,12,22,32",
    "C,18,28,38",
    "B,16,26,36")

    ## convert csv to object
    $widedata | ConvertFrom-Csv

    name val1 val2 val3
    ---- ---- ---- ----
    A    10   20   30
    B    15   25   35
    A    12   22   32
    C    18   28   38
    B    16   26   36

    ## convert wide-format to long-format
    $widedata `
        | ConvertFrom-Csv `
        | wide2long `
            -RowIdentifier name `
            -VariableColumnPrefix val `
            -ValueColumnName num

    name val  num
    ---- ---  ---
    A    val1 10
    A    val2 20
    A    val3 30
    B    val1 15
    B    val2 25
    B    val3 35
    A    val1 12
    A    val2 22
    A    val3 32
    C    val1 18
    C    val2 28
    C    val3 38
    B    val1 16
    B    val2 26
    B    val3 36
    
    # convert long-format to wide-format
    $widedata `
        | ConvertFrom-Csv `
        | wide2long `
            -RowIdentifier name `
            -VariableColumnPrefix val `
            -ValueColumnName num `
        | long2wide `
            -RowProperty name `
            -ColumnProperty val `
            -ValueProperty num
    
    name val1   val2   val3
    ---- ----   ----   ----
    A    10, 12 20, 22 30, 32
    B    15, 16 25, 26 35, 36
    C    18     28     38
    
    # sum each val<n> columns
    $widedata `
        | ConvertFrom-Csv `
        | wide2long `
            -RowIdentifier name `
            -VariableColumnPrefix val `
            -ValueColumnName num `
        | long2wide `
            -RowProperty name `
            -ColumnProperty val `
            -ValueProperty num `
            -Sum

    name  val1  val2  val3
    ----  ----  ----  ----
    A    22.00 42.00 62.00
    B    31.00 51.00 71.00
    C    18.00 28.00 38.00

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
        [string] $Join = ", "
        ,
        [Parameter(Mandatory=$false)]
        [Alias('Std')]
        [switch] $StandardDeviation
        ,
        [Parameter(Mandatory=$false)]
        [switch] $Ratio
        ,
        [Parameter(Mandatory=$false)]
        $EmptyValue = $Null
        ,
        [Parameter(Mandatory=$false)]
        [switch] $ReplaceComma
        ,
        [Parameter(Mandatory=$false)]
        [switch] $Descending
        ,
        [Parameter(Mandatory=$false)]
        [ValidateSet(
            "string", "int", "double",
            "decimal", "version", "datetime"
        )]
        [string] $Cast = 'string'
        ,
        [Parameter(Mandatory=$false)]
        [ValidateSet(
            "string", "int", "double",
            "decimal", "version", "datetime"
        )]
        [Alias('rsort')]
        [string] $RowSort = 'string'
        ,
        [Parameter(Mandatory=$false)]
        [ValidateSet(
            "string", "int", "double",
            "decimal", "version", "datetime"
        )]
        [Alias('csort')]
        [string] $ColSort = 'string'
        ,
        [Parameter(Mandatory=$false)]
        [ValidateSet(
            "string", "int", "double",
            "decimal", "version", "datetime"
        )]
        [Alias('vsort')]
        [string] $ValSort
        ,
        [Parameter(Mandatory=$false)]
        [Alias('rdrop')]
        [switch] $DropRowNA
        ,
        [Parameter(Mandatory=$false)]
        [Alias('cdrop')]
        [switch] $DropColNA
        ,
        [Parameter(Mandatory=$false)]
        [Alias('vdrop')]
        [switch] $DropValNA
        ,
        [Parameter(Mandatory=$false)]
        [Alias('rrep')]
        [string] $ReplaceRowNA
        ,
        [Parameter(Mandatory=$false)]
        [Alias('crep')]
        [string] $ReplaceColNA
        ,
        [Parameter(Mandatory=$false)]
        [Alias('vrep')]
        [string] $ReplaceValNA
        ,
        [Parameter(Mandatory=$false)]
        [string] $DateFormat = 'yyyy-MM-dd'
        ,
        [Parameter(Mandatory=$false)]
        [string] $Format
        ,
        [Parameter(Mandatory=$false)]
        [string] $SplitDelimiter = ", "
        ,
        [Parameter(Mandatory=$false)]
        [string] $ProxyDelimiter = '@p@r@o@x@y@'
        ,
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object[]] $InputObject
    )
    # private functions
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
    filter Drop-EmptyRow {
        [string] $JoinedRowProperty = ''
        foreach ( $rowprop in $RowProperty ){
            # replace empty column property value
            if ( $ReplaceRowNA -and $_.$rowprop -eq '' ){
                $_.$rowprop = $ReplaceRowNA
            }
            # Combine multiple RowProperty values to create row keys
            if ( $ReplaceComma ){
                $_.$rowprop = ($_.$rowprop).Replace($SplitDelimiter, $ProxyDelimiter)
            }
            $JoinedRowProperty += [string]($_.$rowprop)
        }
        if ( $JoinedRowProperty -eq '' ){
            # empty column property value
            if ( $DropRowNA ){
                #pass
            } else {
                # raise error
                #Write-Error "Detect null-value in Property:""$RowProperty"". Please specify the ""-DropRowNA"" or ""-ReplaceRowNA <string>""." -ErrorAction stop
                # skip raise error. 
                # Unlike columns, rows don't cause an error even if they have null values.
                return $_
            }
        } else {
            # not empty: output as-is
            return $_
        }
    }
    filter Drop-EmptyColumn {
        if ( $ReplaceColNA -and [string]($_.$ColumnProperty) -eq '' ){
            # replace empty column property value
            $_.$ColumnProperty = $ReplaceColNA
        }
        [string] $JoinedColProperty = [string] ($_.$ColumnProperty)
        if ( $JoinedColProperty -eq '' ){
            # empty column property value
            if ( $DropColNA ){
                #pass
            } else {
                # raise error
                Write-Error "Detect null-value in Property:""$ColumnProperty"". Please specify the ""-DropColNA"" or ""-ReplaceColNA <string>""." -ErrorAction stop
            }
        } else {
            # not empty: output as-is
            return $_
        }
    }
    # set variables
    if ( $Join ){
        [string] $ConcatDelimiter = $Join
    } elseif ( $Join -eq '' ){
        [string] $ConcatDelimiter = ''
    } else {
        [string] $ConcatDelimiter = $SplitDelimiter
    }
    if ( $Sum -or $Average -or $Median -or $Max -or $Min -or $StandardDeviation -or $Ratio ) {
        if ( $Cast -notin @('int', 'double', 'decimal') ) {
            # default calc cast
            $Cast = 'double'
        }
    }
    # Extract unique values for rows
    switch -Exact ( $RowSort ) {
        'string'   { $splatting = @{ Property = { [string]   $_ }; Descending = $Descending } }
        'int'      { $splatting = @{ Property = { [int]      $_ }; Descending = $Descending } }
        'double'   { $splatting = @{ Property = { [double]   $_ }; Descending = $Descending } }
        'decimal'  { $splatting = @{ Property = { [decimal]  $_ }; Descending = $Descending } }
        'version'  { $splatting = @{ Property = { [version]  $_ }; Descending = $Descending } }
        'datetime' { $splatting = @{ Property = { [datetime] $_ }; Descending = $Descending } }
        default    { $splatting = @{ Property = { [string]   $_ }; Descending = $Descending } }
    }
    $RowValues = @(
        $input `
            | Drop-EmptyRow `
            | Group-Object -Property $RowProperty -NoElement `
            | Select-Object -ExpandProperty Name `
            | Sort-Object @splatting
    )
    # Extract unique values for columns
    switch -Exact ( $ColSort ) {
        'string'   { $splatting = @{ Property = { [string]   $_ } } }
        'int'      { $splatting = @{ Property = { [int]      $_ } } }
        'double'   { $splatting = @{ Property = { [double]   $_ } } }
        'decimal'  { $splatting = @{ Property = { [decimal]  $_ } } }
        'version'  { $splatting = @{ Property = { [version]  $_ } } }
        'datetime' { $splatting = @{ Property = { [datetime] $_ } } }
        default    { $splatting = @{ Property = { [string]   $_ } } }
    }
    $ColumnValues = @(
        $input `
            | Drop-EmptyColumn `
            | Select-Object -ExpandProperty $ColumnProperty -Unique `
            | Sort-Object @splatting
    )
    # Hashtable to store the cross-tabulation results
    $CrossTab = @{}

    # Create hashtables for each row key
    foreach ($RowValue in $RowValues) {
        # init hash
        $CrossTab[$RowValue] = @{}
    }

    # Aggregate data and store it in the cross-tabulation table
    foreach ($Item in @($input | Drop-EmptyRow | Drop-EmptyColumn) ){
        # Combine values of multiple RowProperty to create the row key
        [string] $RowKey = @($RowProperty | ForEach-Object {$Item.$_}) -join $SplitDelimiter
        $Column = $Item.$ColumnProperty
        $Value  = $Item.$ValueProperty
        if ( $DropValNA ){
            # check for NA values
            if ( $Value -match '^NA$|^NaN$' ) {
                # skip NA values
                $Value = $Null
            }
        } elseif ( $ReplaceValNA ){
            # replace NA values
            if ( $Value -match '^NA$|^NaN$' ) {
                # replace NA values
                $Value = $Value -replace '^NA$|^NaN$', $ReplaceValNA
            }
        }
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
    } elseif ($Ratio) {
        [string] $AggregateFunction = "Ratio"
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
            $Values = $CrossTab[$RowValue][$ColumnValue]
            if ( $Values.Count -eq 0 ) {
                $Result = $EmptyValue
            } else {
                if ( $Cast -eq 'string' ){
                    # values -as string
                    if ( $Count ){
                        [int] $Result = $Values.Count
                    } elseif ( $ValSort ) {
                        [string] $Result = switch -Exact ( $ValSort ) {
                            'string'   {@($Values | Sort-Object -Property {[string]   $_}) -Join $ConcatDelimiter}
                            'int'      {@($Values | Sort-Object -Property {[int]      $_}) -Join $ConcatDelimiter}
                            'double'   {@($Values | Sort-Object -Property {[double]   $_}) -Join $ConcatDelimiter}
                            'decimal'  {@($Values | Sort-Object -Property {[decimal]  $_}) -Join $ConcatDelimiter}
                            'version'  {@($Values | Sort-Object -Property {[version]  $_}) -Join $ConcatDelimiter}
                            'datetime' {@($Values | Sort-Object -Property {[datetime] $_}) -Join $ConcatDelimiter}
                            default    {@($Values | Sort-Object -Property {[string]   $_}) -Join $ConcatDelimiter}
                        }
                    } else {
                        [string] $Result = $Values -Join $ConcatDelimiter
                    }
                } else {
                    # values -as numeric
                    $Result = switch -Exact ($AggregateFunction) {
                        "Sum"     {$Values | Measure-Object -Sum     | Select-Object -ExpandProperty Sum}
                        "Average" {$Values | Measure-Object -Average | Select-Object -ExpandProperty Average}
                        "Median"  {Get-Median @($Values)}
                        "Count"   {$Values.Count}
                        "Max"     {$Values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum}
                        "Min"     {$Values | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum}
                        "Std"     {$Values | Measure-Object -StandardDeviation | Select-Object -ExpandProperty StandardDeviation}
                        "Ratio"   {
                            $outCount = $Values.Count
                            $outSum = $Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                                if ( $outCount -eq 0 ){
                                    Write-Output 0
                                } else {
                                    Write-Output $($outSum / $outCount)
                                }
                            }
                        default   {$Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum} # Default to Sum
                    }
                }
                if ( $Result -eq $Null ) {
                    $Result = $EmptyValue
                }
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
                if ( $Format -and $Cast -ne 'string' ){
                    $o[$ColumnValue] = ($o[$ColumnValue]).ToString($Format)
                }
            } catch {
                Write-Error $error[0] -ErrorAction stop
            }
        }
        [pscustomobject]$o
        $o = [ordered] @{}
    }
}
# set alias
[String] $tmpAliasName = "long2wide"
[String] $tmpCmdName   = "Map-Object"
[String] $tmpCmdPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath $($MyInvocation.MyCommand.Name) `
    | Resolve-Path -Relative
if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }
# is alias already exists?
if ((Get-Command -Name $tmpAliasName -ErrorAction SilentlyContinue).Count -gt 0){
    try {
        if ( (Get-Command -Name $tmpAliasName).CommandType -eq "Alias" ){
            if ( (Get-Command -Name $tmpAliasName).ReferencedCommand.Name -eq $tmpCmdName ){
                Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                    | ForEach-Object{
                        Write-Host "$($_.DisplayName)" -ForegroundColor Green
                    }
            } else {
                throw
            }
        } elseif ( "$((Get-Command -Name $tmpAliasName).Name)" -match '\.exe$') {
            Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                | ForEach-Object{
                    Write-Host "$($_.DisplayName)" -ForegroundColor Green
                }
        } else {
            throw
        }
    } catch {
        Write-Error "Alias ""$tmpAliasName ($((Get-Command -Name $tmpAliasName).ReferencedCommand.Name))"" is already exists. Change alias needed. Please edit the script at the end of the file: ""$tmpCmdPath""" -ErrorAction Stop
    } finally {
        Remove-Variable -Name "tmpAliasName" -Force
        Remove-Variable -Name "tmpCmdName" -Force
    }
} else {
    Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
        | ForEach-Object {
            Write-Host "$($_.DisplayName)" -ForegroundColor Green
        }
    Remove-Variable -Name "tmpAliasName" -Force
    Remove-Variable -Name "tmpCmdName" -Force
}

