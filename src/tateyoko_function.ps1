<#
.SYNOPSIS
    tateyoko - Transpose rows and columns

        tateyoko [-d|-Delimiter <String>]
    
    Expects space-separated values as input.
    The number of columns can be irregular.

.DESCRIPTION

    The main design pattern of this command was abstracted from
    Universal Shell Programming Laboratory's "Open-usp-Tukubai",
    Here is the original copyright notice for "Open-usp-Tukubai":
    
        The MIT License Copyright (c) 2011-2023 Universal Shell Programming Laboratory
        https://github.com/usp-engineers-community/Open-usp-Tukubai/blob/master/LICENSE

.EXAMPLE
    "1 2 3","4 5 6","7 8 9"
    1 2 3
    4 5 6
    7 8 9

    PS > "1 2 3","4 5 6","7 8 9" | tateyoko
    1 4 7
    2 5 8
    3 6 9

.EXAMPLE
    "1,2,3", "4,5", "7,8,9"
    1,2,3
    4,5
    7,8,9

    "1,2,3", "4,5", "7,8,9" | tateyoko -d ","
    1,4,7
    2,5,8
    3,,9

#>
function tateyoko{
    Param (    
        [Parameter( Mandatory=$False )]
        [Alias('d')]
        [string] $Delimiter = ' ',
        
        [parameter( ValueFromPipeline=$True )]
        [string[]] $Text
    )
    begin
    {
        [string[]] $RowAry = @()
        [int] $MaxColNum = 1
        [string] $writeLine = ''
        $RowList = New-Object 'System.Collections.Generic.List[System.String]'
    }
    process
    {
        # 1st pass
        [string] $readLine = [string] $_
        $RowList.Add($readLine)
        # get max col num
        if ( $Delimiter -eq '' ){
            [string[]] $ColAry = $readLine.ToCharArray()
        } else {
            [string[]] $ColAry = $readLine.Split( $Delimiter )
        }
        [int] $tmpColNum = @($ColAry).Count
        if( $tmpColNum -gt $MaxColNum ){
            [int] $MaxColNum = $tmpColNum
        }
    }
    end
    {
        # get max row
        [string[]] $RowAry = $RowList.ToArray()
        [int] $MaxRowNum = @($RowAry).Count
        # transpose rows and columns
        for( $j = 0; $j -lt $MaxColNum; $j++ ){
            $outputList = New-Object 'System.Collections.Generic.List[System.String]'
            [string[]]$outputAry = @()
            for( $i = 0; $i -lt $MaxRowNum; $i++ ){
                $outputList.Add(@($RowAry)[$i].Split($Delimiter)[$j])
            }
            [string[]] $outputAry = $outputList.ToArray()
            [string] $writeLine = $outputAry -Join $Delimiter
            # trim
            [string] $writeLine = $writeLine -Replace "($Delimiter)+$",''
            # output
            Write-Output $writeLine
            [string] $writeLine = ''
        }
    }
}
