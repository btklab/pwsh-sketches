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
        # Initialize row counters
        [int] $NR = 0
        [int] $rowCounter = 0
        
        # Determine input and output delimiters.
        # Prioritize explicit InputDelimiter and OutputDelimiter,
        # then fall back to Delimiter if only one is specified,
        # otherwise use Delimiter for both.
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
        
        # Check if the input delimiter is an empty string, indicating char-by-char processing.
        if ($iDelim -eq ''){
            [bool] $emptyDelimiterFlag = $True
        } else {
            [bool] $emptyDelimiterFlag = $False
        }
        
        # --- Helper Functions ---
        
        # Converts shorthand field variables (e.g., $1, $NF, $0) in the formula
        # to their internal array ($self) equivalents for execution.
        function replaceFieldStr ([string] $str){
            $str = " " + $str
            # Escape dollar signs within single/double quotes to prevent premature evaluation.
            $str = escapeDollarMarkBetweenQuotes $str
            # Replace $0 with the entire current record.
            $str = $str.Replace('$0','($self -join "$oDelim")')
            # Replace $NF (last field) with the last element of the $self array.
            $str = $str -replace('([^\\`])\$NF','$1$self[($self.Count - 1)]')
            # Replace $N (Nth field) with the N-1 element of the $self array.
            $str = $str -replace '([^\\`])\$(\d+)','$1$self[($2-1)]'
            # Unescape previously escaped dollar signs.
            $str = $str.Replace('\$','$').Replace('`$','$')
            $str = $str.Trim()
            return $str
        }
        
        # Escapes dollar signs ($) within quoted strings to prevent them from
        # being interpreted as variable references before formula evaluation.
        function escapeDollarMarkBetweenQuotes ([string] $str){
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
                        # If inside quotes and character is '$', escape it.
                        if (($escapeFlag) -and ($char -eq '$')){
                            $char = '\$'
                        }
                    }
                    Write-Output $char
                }
            [string] $ret = $strAry -Join ''
            return $ret
        }
        
        # Replaces semicolons (;) within quoted strings with underscores (_)
        # to prevent them from being treated as statement separators during splitting.
        function escapeSemiColonBetweenQuotes ([string] $str, [string] $quote = "'"){
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
                        # If inside quotes and character is ';', replace it.
                        if (($escapeFlag) -and ($char -eq ';')){
                            $char = '_'
                        }
                    }
                    Write-Output $char
                }
            [string] $ret = $strAry -Join ''
            return $ret
        }
        
        # Attempts to parse a string value into a Decimal,
        # preserving zero-padded numbers as strings.
        function tryParseDecimal {
            param(
                [parameter(Mandatory=$True, Position=0)]
                [string] $val
            )
            [string] $val = $val.Trim()
            
            # Preserve zero-padded numbers as strings to maintain format.
            if ($val -match '^0[0-9]+$'){
                return $val
            }
            
            # Attempt to parse the value as a Decimal.
            $valueObject = New-Object System.Decimal
            switch -Exact ($val) {
                {[Double]::TryParse($val.Replace('_',''), [ref] $valueObject)} {
                    Write-Debug "Converted to Decimal: $valueObject"
                    return $valueObject
                }
                default {
                    # If not a convertible number, return the original string.
                    Write-Debug "Not converted to Decimal: $val"
                    return $val
                }
            }
        }
        
        # Pre-process the formula script block:
        # 1. Convert to string.
        # 2. Replace user-friendly field variables with internal array access.
        [string] $FormulaBlockStr = $Formula.ToString().Trim()
        [string] $FormulaBlockStr = replaceFieldStr $FormulaBlockStr
        Write-Debug "Formula: $FormulaBlockStr"
        
        # Count the number of expressions in the formula by splitting on semicolons.
        # Semicolons within quotes are temporarily replaced to avoid miscounting.
        [string] $FBStrForCountFieldNum = escapeSemiColonBetweenQuotes $FormulaBlockStr "'"
        [string] $FBStrForCountFieldNum = escapeSemiColonBetweenQuotes $FBStrForCountFieldNum '"'
        [int] $CountFieldNumOfFormula = $FBStrForCountFieldNum.Split(";").Count
        Write-Debug "Rep-Formula: $FBStrForCountFieldNum"
        Write-Debug "FieldCountOfFormula: [$CountFieldNumOfFormula]"
    }
    process
    {
        # In calculator mode, the formula is executed only once in the 'end' block.
        if ( $Calculator ){
            return
        }
        
        $rowCounter++
        [string] $line = [string] $_
        
        # Skip the first line if SkipHeader switch is present.
        if ( $SkipHeader -and $rowCounter -eq 1 ){
            Write-Output $line
            return
        }
        
        # Skip empty lines.
        if ($line -eq ''){
            return
        }
        
        # Increment row number for current record processing.
        $NR++
        
        # Split the input line into fields based on the effective input delimiter.
        # If delimiter is empty, treat input as individual characters.
        if ( $emptyDelimiterFlag ){
            [string[]] $tmpAry = $line.ToCharArray()
        } else {
            [string[]] $tmpAry = $line.Split( $iDelim )
        }
        
        # Initialize $self array and populate it with parsed field values.
        # $self will hold the current record's fields, converted to numbers where possible.
        [object[]] $self = @()
        foreach ($element in $tmpAry){
            $self += tryParseDecimal $element
        }
        
        # Execute the pre-processed formula against the current record ($self).
        # Depending on -OnlyOutputResult, output either only the formula result
        # or the original record plus the formula result.
        if ( $OnlyOutputResult ){
            # Execute formula and output only the result, joined by the output delimiter.
            $self = Invoke-Expression -Command $FormulaBlockStr -ErrorAction Stop
            $self -Join "$oDelim"
        } else {
            # Append the formula result to the original fields and output the combined line.
            $self += Invoke-Expression -Command $FormulaBlockStr -ErrorAction Stop
            $self -Join "$oDelim"
        }
    }
    end
    {
        # If in calculator mode, execute the formula once at the end.
        # This handles cases where no pipeline input is provided.
        if( $Calculator ){
            Invoke-Expression -Command $FormulaBlockStr -ErrorAction Stop
        }
    }
}
