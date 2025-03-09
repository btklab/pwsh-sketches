<#
.SYNOPSIS
    tarr - Expand wide data to long

    Convert wide data to long data using the specified
    columns as a key.

    Expects space-separated input without headers.
    No pre-sort required.
    Ignore case.

.DESCRIPTION

    The main design pattern of this command was abstracted from
    Universal Shell Programming Laboratory's "Open-usp-Tukubai",
    Here is the original copyright notice for "Open-usp-Tukubai":
    
        The MIT License Copyright (c) 2011-2023 Universal Shell Programming Laboratory
        https://github.com/usp-engineers-community/Open-usp-Tukubai/blob/master/LICENSE

.LINK
    tarr, yarr

.EXAMPLE
    cat a.txt
    2018 1 2 3
    2017 1 2 3 4
    2022 1 2

    PS > cat a.txt | grep . | tarr -n 1
    2018 1
    2018 2
    2018 3
    2017 1
    2017 2
    2017 3
    2017 4
    2022 1
    2022 2

    PS > cat a.txt | grep . | tarr -n 2
    2018 1 2
    2018 1 3
    2017 1 2
    2017 1 3
    2017 1 4
    2022 1 2

#>
function tarr {
    Param(
        [Parameter(Position=0,Mandatory=$False)]
        [Alias('n')]
        [int] $num = 1,

        [Parameter(Mandatory=$False)]
        [string] $Delimiter = ' ',

        [parameter(Mandatory=$False,ValueFromPipeline=$True)]
        [string[]] $Text
    )
    process {
        [string] $readLine = $_
        # is line empty?
        if ( $readLine -eq '' ){
            Write-Error "detect empty row: $line" -ErrorAction Stop
        }
        # split key
        if ( $Delimiter -eq '' ){
            [string[]] $keyValAry = $readLine.ToCharArray()
        } else {
            [string[]] $keyValAry = $readLine.Split( $Delimiter )
        }
        if ( $keyValAry.Count -le $num ){
            Write-Error "Detect key-only lines: $line"  -ErrorAction Stop
        }
        # set key, val into hashtable
        [int] $sKey = 0
        [int] $eKey = $num - 1
        [int] $sVal = $eKey + 1
        [int] $eVal = $keyValAry.Count - 1
        [string] $key = $keyValAry[($sKey..$eKey)] -Join $Delimiter
        foreach ($val in $keyValAry[($sVal..$eVal)]){
            [string] $writeLine = $key + $Delimiter + $val
            Write-Output $writeLine
        }
    }
}
