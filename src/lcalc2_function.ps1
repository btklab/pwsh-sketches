<#
.SYNOPSIS
    lcalc2 - Column-to-column calculator
    
    Column-to-column calculations with script block
    on space delimited stdin.

        lcalc2 {expr; expr;...} [-d "delim"] [-c|-Calculator]
    
    Auto-Skip empty row.
    Multiple expr with ";" in scriptblock.

    Built-in variables:
      $1,$2,... : Column indexes starting with 1
      $NF       : Rightmost column
      $NR       : Row number of each records

    You can use the [math] type accelerator to call static
    methods from the System.Math class, such as [math]::Sqrt(),
    [math]::Pow(), or [math]::Round(), Etc....
    
    You can use "Tab-Completion" in the script block

    You can use conditional branching with if statement.

    See EXAMPLE section for more details.

.LINK
    lcalc, lcalc2, Process-CsvColumn

.DESCRIPTION

    The main design pattern of this command was abstracted from
    Universal Shell Programming Laboratory's "Open-usp-Tukubai",
    Here is the original copyright notice for "Open-usp-Tukubai":
    
        The MIT License Copyright (c) 2011-2023 Universal Shell Programming Laboratory
        https://github.com/usp-engineers-community/Open-usp-Tukubai/blob/master/LICENSE

.EXAMPLE
    # Multiple expr using ";" in scriptblock

    # data
    "8.3 70","8.6 65","8.8 63"
    8.3 70
    8.6 65
    8.8 63

    # calc
    "8.3 70","8.6 65","8.8 63" `
        | lcalc2 {$1+1;$2+10}
    8.3 70 9.3 80
    8.6 65 9.6 75
    8.8 63 9.8 73

.EXAMPLE
    # Output only result

    # input
    "8.3 70","8.6 65","8.8 63"
    8.3 70
    8.6 65
    8.8 63

    # output 1
    "8.3 70","8.6 65","8.8 63" `
        | lcalc2 {$1+1; $2+10} -OnlyOutputResult
    9.3 80
    9.6 75
    9.8 73

    # output 2
    #   Put result on the left,
    #   put original field on the right,
    #   with -OnlyOutputResult and $0
    "8.3 70","8.6 65","8.8 63" `
        | lcalc2 {$1+1; $2+10; $0} -OnlyOutputResult
    9.3 80 8.3 70
    9.6 75 8.6 65
    9.8 73 8.8 63

.EXAMPLE
    # Get row number of record
    1..5 | lcalc2 {$NR}
    1 1
    2 2
    3 3
    4 4
    5 5

.EXAMPLE
    # Calculator mode

    lcalc2 -Calculator {1+1}
    2

    # calculator mode does not require
    # standard input (from pipeline)

    lcalc2 -c {1+[math]::sqrt(4)}
    3

    lcalc2 -c {[math]::pi}
    3.14159265358979

    lcalc2 -c {[math]::Ceiling(1.1)}
    2

.EXAMPLE
    # Calculate average with sm2 and lcalc2 command

    ## input
    "A 1 10","B 1 10","A 1 10","C 1 10"
    A 1 10
    B 1 10
    A 1 10
    C 1 10

    ## sum up
    "A 1 10","B 1 10","A 1 10","C 1 10" `
        | sort `
        | sm2 +count 1 2 3 3
    2 A 1 20
    1 B 1 10
    1 C 1 10

    ## calc average
    "A 1 10","B 1 10","A 1 10","C 1 10" `
        | sort `
        | sm2 +count 1 2 3 3 `
        | lcalc2 {$NF/$1}
    2 A 1 20 10
    1 B 1 10 10
    1 C 1 10 10

    # Calculate and assign a new value to the third column.
    "A 1 10","B 1 10","A 1 10","C 1 10" `
        | sort `
        | sm2 +count 1 2 3 3 `
        | lcalc2  {$3=$3+$4}
    2 A 21 20
    1 B 11 10
    1 C 11 10

.EXAMPLE
    # Example of using the System.Math class in .NET Framework
    # You can use the [math] type accelerator to call static
    # methods from the System.Math class, such as Sqrt, Pow, or Round.
    # You can also use "Tab-Completion" in the script block

    lcalc2 {[math]::PI} -Calculator
    3.14159265358979

.EXAMPLE
    # Example of using the System.Math class in .NET Framework
    # Replace the third column with its squared values using [math]::Pow()

    "A 1 10","B 1 10","A 1 10","C 1 10" `
        | sort `
        | sm2 1 2 3 3
    A 1 20
    B 1 10
    C 1 10

    "A 1 10","B 1 10","A 1 10","C 1 10" `
        | sort `
        | sm2 1 2 3 3 `
        | lcalc2 {$3=[math]::Pow($3,2)}
    A 1 400
    B 1 100
    C 1 100

.EXAMPLE
    # Records are stored in the $self array.
    # Following approach allows you to work with the array object directly,
    # rather than using shorthand variables like $1, $2, etc.

    "A 1 10","B 1 10","A 1 10","C 1 10" `
        | sort
    A 1 10
    A 1 10
    B 1 10
    C 1 10

    "A 1 10","B 1 10","A 1 10","C 1 10" `
        | sort `
        | lcalc2 {$self[1]+0.1}
    A 1 10 1.1
    A 1 10 1.1
    B 1 10 1.1
    C 1 10 1.1

    "A 1 10","B 1 10","A 1 10","C 1 10" `
        | sort `
        | lcalc2 {$self.Count}
    A 1 10 3
    A 1 10 3
    B 1 10 3
    C 1 10

.EXAMPLE
    # An example of conditional branching using an if statement.
    # Apply the process only to the first record.

    "A 1 10","B 1 10","A 1 10","C 1 10" `
        | sort
    A 1 10
    A 1 10
    B 1 10
    C 1 10

    "A 1 10","B 1 10","A 1 10","C 1 10" `
        | sort `
        | lcalc2 {if($NR -eq 1){$3=[math]::Pow($3,2)}else{$3=$3}}
    A 1 100
    A 1 10
    B 1 10
    C 1 10

    # The following example is equivalent to the one above.

    "A 1 10","B 1 10","A 1 10","C 1 10" `
        | sort `
        | lcalc2 {if($NR -eq 1){$3=[math]::Pow($3,2)}}
    A 1 100
    A 1 10
    B 1 10
    C 1 10

    # If you do not overwrite the values in a column
    # (i.e., when creating a new column), it is recommended
    # to use else to specify a placeholder.

    "A 1 10","B 1 10","A 1 10","C 1 10" `
        | sort `
        | lcalc2 {if($NR -eq 1){[math]::Pow($3,2)}else{0}}
    A 1 10 100
    A 1 10 0
    B 1 10 0
    C 1 10 0

#>
function lcalc2 {
    Param(
        [Parameter( Mandatory=$True, Position=0 )]
        [Alias('f')]
        [ScriptBlock] $Formula,

        [Parameter(Mandatory=$False)]
        [Alias('fs', 'd')]
        [string] $Delimiter = ' ',

        [Parameter(Mandatory=$False)]
        [Alias('ifs')]
        [string] $InputDelimiter,

        [Parameter(Mandatory=$False)]
        [Alias('ofs')]
        [string] $OutputDelimiter,

        [Parameter(Mandatory=$False)]
        [Alias('c', 'calc')]
        [switch] $Calculator,

        [Parameter(Mandatory=$False)]
        [Alias('o')]
        [switch] $OnlyOutputResult,

        [Parameter(Mandatory=$False)]
        [Alias('s')]
        [switch] $SkipHeader,

        [parameter(
            Mandatory=$False,
            ValueFromPipeline=$True)]
        [string[]] $InputObject
    )
    begin
    {
        # init var
        [int] $NR = 0
        [int] $rowCounter = 0
        # set input/output delimiter
        if ( $InputDelimiter -and $OutputDelimiter ){
            [string] $iDelim = $InputDelimiter
            [string] $oDelim = $OutputDelimiter
        } elseif ( $InputDelimiter ){
            [string] $iDelim = $InputDelimiter
            [string] $oDelim = $InputDelimiter
        } elseif ( $OutputDelimiter ){
            [string] $iDelim = $Delimiter
            [string] $oDelim = $OutputDelimiter
        } else {
            [string] $iDelim = $Delimiter
            [string] $oDelim = $Delimiter
        }
        # test is iDelim -eq empty string?
        if ($iDelim -eq ''){
            [bool] $emptyDelimiterFlag = $True
        } else {
            [bool] $emptyDelimiterFlag = $False
        }
        # private functions
        function replaceFieldStr ([string] $str){
            $str = " " + $str
            $str = escapeDollarMarkBetweenQuotes $str
            $str = $str.Replace('$0','($self -join "$oDelim")')
            $str = $str -replace('([^\\`])\$NF','$1$self[($self.Count - 1)]')
            $str = $str -replace '([^\\`])\$(\d+)','$1$self[($2-1)]'
            $str = $str.Replace('\$','$').Replace('`$','$')
            $str = $str.Trim()
            return $str
        }
        function escapeDollarMarkBetweenQuotes ([string] $str){
            # escape "$" to "\$" between single quotes
            [bool] $escapeFlag = $False
            [string[]] $strAry = $str.GetEnumerator() | ForEach-Object {
                    [string] $char = [string] $_
                    if ($char -eq "'"){
                        if ($escapeFlag -eq $False){
                            $escapeFlag = $True
                        } else {
                            $escapeFlag = $False
                        }
                    } else {
                        if (($escapeFlag) -and ($char -eq '$')){
                            $char = '\$'
                        }
                    }
                    Write-Output $char
                }
            [string] $ret = $strAry -Join ''
            return $ret
        }
        function escapeSemiColonBetweenQuotes ([string] $str, [string] $quote = "'"){
            # delete ";" between single quotes
            [bool] $escapeFlag = $False
            [string[]] $strAry = $str.GetEnumerator() | ForEach-Object {
                    [string] $char = [string] $_
                    if ($char -eq "$quote"){
                        if ($escapeFlag -eq $False){
                            $escapeFlag = $True
                        } else {
                            $escapeFlag = $False
                        }
                    } else {
                        if (($escapeFlag) -and ($char -eq ';')){
                            $char = '_'
                        }
                    }
                    Write-Output $char
                }
            [string] $ret = $strAry -Join ''
            return $ret
        }
        function tryParseDecimal {
            param(
                [parameter(Mandatory=$True, Position=0)]
                [string] $val
            )
            [string] $val = $val.Trim()
            if ($val -match '^0[0-9]+$'){
                # Zero-padded numbers are output as-is
                # without converting to numeric values
                return $val
            }
            $valueObject = New-Object System.Decimal
            if ($false){
                switch -Exact ($val) {
                    "true"  { return $True }
                    "false" { return $False }
                    "yes"   { return $True }
                    "no"    { return $False }
                    "on"    { return $True }
                    "off"   { return $False }
                    "null"  { return $Null }
                    "nil"   { return $Null }
                    default {
                        #pass
                        }
                }
            }
            switch -Exact ($val) {
                {[Double]::TryParse($val.Replace('_',''), [ref] $valueObject)} {
                    Write-Debug "Converted to Decimal: $valueObject"
                    return $valueObject
                }
                default {
                    Write-Debug "Not converted to Decimal: $val"
                    return $val
                }
            }
        }
        # set formula
        [string] $FormulaBlockStr = $Formula.ToString().Trim()
        [string] $FormulaBlockStr = replaceFieldStr $FormulaBlockStr
        Write-Debug "Formula: $FormulaBlockStr"
        # Count field number in Formula
        [string] $FBStrForCountFieldNum = escapeSemiColonBetweenQuotes $FormulaBlockStr "'"
        [string] $FBStrForCountFieldNum = escapeSemiColonBetweenQuotes $FBStrForCountFieldNum '"'
        [int] $CountFieldNumOfFormula = $FBStrForCountFieldNum.Split(";").Count
        Write-Debug "Rep-Formula: $FBStrForCountFieldNum"
        Write-Debug "FieldCountOfFormula: [$CountFieldNumOfFormula]"
    }
    process
    {
        if ( $Calculator ){
            return
        }
        $rowCounter++
        [string] $line = [string] $_
        if ( $SkipHeader -and $rowCounter -eq 1 ){
            Write-Output $line
            return
        }
        if ($line -eq ''){
            return
        }
        # main
        $NR++
        if ( $emptyDelimiterFlag ){
            [string[]] $tmpAry = $line.ToCharArray()
        } else {
            [string[]] $tmpAry = $line.Split( $iDelim )
        }
        [object[]] $self = @()
        # output whole line
        foreach ($element in $tmpAry){
            $self += tryParseDecimal $element
        }
        #[int] $NF = $self.Count
        if ( $OnlyOutputResult ){
            $self = Invoke-Expression -Command $FormulaBlockStr -ErrorAction Stop
            $self -Join "$oDelim"
        } else {
            $self += Invoke-Expression -Command $FormulaBlockStr -ErrorAction Stop
            $self -Join "$oDelim"
        }
    }
    end
    {
        if( $Calculator ){
            Invoke-Expression -Command $FormulaBlockStr -ErrorAction Stop
        }
    }
}
