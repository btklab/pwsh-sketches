<#
.SYNOPSIS
    Process-CsvColumn (Alias: csv2proc) - Runs a custom script on selected CSV columns.

    Process-CsvColumn (csv2proc)
        [-c|-Column] <Int32[]>
        [-s|-ScriptBlock] <ScriptBlock>
        [-d|-Delimiter <String>]
        [-Path <String>]
        [-Encoding <String>]
        [-nh|-NoHeader]
        [-KeepQuotes]

.LINK
    csv2txt, csv2sqlite,
    Process-CsvColumn (csv2proc),
    Replace-InQuote (qsed),
    Process-InQuote (qproc)

.DESCRIPTION
    Applies custom processing to specific CSV columns from a file or pipeline.
    Supports multiple columns, outputs to standard output, and uses streaming
    for memory efficiency. Handles complex CSV formats with quoted fields,
    embedded quotes, and delimiters.

        - Quoted fields containing quotes (e.g., "field with ""quotes""")
        - Remove quotes wherever possible.

    Note:
        By default, the first line is treated as a header row. When the -NoHeader option
        is specified, the first line is treated as data and the script block is applied to it.

    Note:
        Delimiters within double-quoted fields are ignored for field separation.
        For example, in "field1","field,with,commas","field3", the middle field
        "field,with,commas" will be treated as a single field despite containing commas.

    Note:
        This script has limitations in handling complex CSV patterns:

            - Fields containing newlines.


.PARAMETER InputObject
    Input data from pipeline. Accepts CSV formatted strings.

.PARAMETER Path
    Path to the input CSV file. Optional if using pipeline input.

.PARAMETER Column
    Array of column indices to process (1-based). Multiple columns can be specified.

.PARAMETER ScriptBlock
    PowerShell script block containing the processing logic. The current value is available as $_.

.PARAMETER Encoding
    Specifies the encoding for the input file. Default is UTF8.
    Valid values: ASCII, BigEndianUnicode, Default, Unicode, UTF7, UTF8, UTF32

.PARAMETER Delimiter
    Specifies the delimiter character for CSV parsing. Default is comma (,).

.PARAMETER NoHeader
    Specifies that the input CSV does not have a header row. When this parameter is used,
    the first row will be treated as data instead of column headers.

.NOTES
    Version:        1.0
    Author:         btklab
    Creation Date:  2024-03-21
    Requirements:   PowerShell 5.1 or later

.EXAMPLE
    # Process columns 6 from stdin, replacing " " with "-"
    $logEntries = @(
       '192.168.0.0 - - [25/Mar/2025:06:45:00 +0900] "GET /index.html HTTP/1.1" 200 1234',
       '192.168.0.1 - - [25/Mar/2025:06:45:02 +0900] "POST /api/data HTTP/1.1" 500 432',
       '192.168.0.2 - - [25/Mar/2025:06:45:04 +0900] "PUT /upload HTTP/1.1" 201 5678'
    )
    $logEntries | Process-CsvColumn -Column 6 -ScriptBlock {$_ -replace " ","-"} -Delimiter " " -NoHeader

        192.168.0.0 - - [25/Mar/2025:06:45:00 +0900] GET-/index.html-HTTP/1.1 200 1234
        192.168.0.1 - - [25/Mar/2025:06:45:02 +0900] POST-/api/data-HTTP/1.1 500 432
        192.168.0.2 - - [25/Mar/2025:06:45:04 +0900] PUT-/upload-HTTP/1.1 201 5678

    # Equivalent to the above example
    $logEntries | csv2proc -c 6 -s {$_ -replace " ","-"} -d " " -NoHeader

    # Equivalent to the above example
    $logEntries | csv2proc 6 {$_ -replace " ","-"} -d " " -NoHeader

.EXAMPLE
    # Process columns 1 and 2 from a file, replacing "o" with "*"
    $csv = @(
        'Name,Comment,Age,Title,Salary',
        '"John Doe","He said, ""Hello!""",30,"Engineer",50000',
        '"Jane Smith","Loves ""Python"" and coffee",27,"Developer",55000',
        '"Bob Johnson","Works on ""AI, ML"" projects",35,"Data Scientist",70000'
    )
    $csv | csv2proc -Column 1,2 -ScriptBlock { $_ -replace "o", "*" }

        Name,Comment,Age,Title,Salary
        J*hn D*e,"He said, ""Hell*!""",30,Engineer,50000
        Jane Smith,"L*ves ""Pyth*n"" and c*ffee",27,Developer,55000
        B*b J*hns*n,"W*rks *n ""AI, ML"" pr*jects",35,Data Scientist,70000

    # Process column 3 from pipeline input, multiplying values by 1.1
    $csv | csv2proc -c 3 -s { [int]$_ * 1.15 }

        Name,Comment,Age,Title,Salary
        John Doe,"He said, ""Hello!""",34.5,Engineer,50000
        Jane Smith,"Loves ""Python"" and coffee",31.05,Developer,55000
        Bob Johnson,"Works on ""AI, ML"" projects",40.25,Data Scientist,70000

#>
function Process-CsvColumn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [Alias('c')]
        [Alias('Col')]
        [int[]]$Column
        ,
        [Parameter(Mandatory=$true, Position=1)]
        [Alias('s')]
        [Alias('Script')]
        [scriptblock]$ScriptBlock
        ,
        [Parameter(Mandatory=$false)]
        [Alias('d')]
        [string]$Delimiter = ','
        ,
        [Parameter(Mandatory=$false)]
        [Alias('f')]
        [string]$Path
        ,
        [Parameter(Mandatory=$false)]
        [ValidateSet('ASCII', 'BigEndianUnicode', 'Default', 'Unicode', 'UTF7', 'UTF8', 'UTF32')]
        [string]$Encoding = 'UTF8'
        ,
        [Parameter(Mandatory=$false)]
        [Alias('nh')]
        [switch]$NoHeader
        ,
        [Parameter(Mandatory=$false)]
        [switch]$KeepQuotes
        ,
        [Parameter(ValueFromPipeline=$true)]
        [string[]]$InputObject
    )

    begin {
        # Initialize variables
        [bool] $isFirstLine = $true
        [string] $header = $null
        [int] $maxColumnIndex = 0

        # Test path
        if ( $Path ){
            if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
                Write-Error "Input file not found: $Path" -ErrorAction Stop
            }
        }

        # Helper function to parse CSV line
        function Parse-CsvLine {
            param(
                [string]$line,
                [string]$delimiter
            )
            
            [string[]] $fields = @()
            [string] $currentField = ""
            [bool] $inQuotes = $false
            [bool] $isQuotingRequired = $false
            [int] $i = 0
            
            while ($i -lt $line.Length) {
                [string] $char = $line[$i]
                
                if ($char -eq '"') {
                    if ($inQuotes -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '"') {
                        # Escaped quote
                        $currentField += '"'
                        $i++
                        $isQuotingRequired = $true
                    } else {
                        # Toggle quote state
                        $inQuotes = -not $inQuotes
                    }
                } elseif ($char -eq $delimiter -and -not $inQuotes) {
                    # End of field
                    if ( $isQuotingRequired -and $KeepQuotes ) {
                        # If quoting is required, add quotes around the field
                        $fields += '"' + $currentField + '"'
                        $isQuotingRequired = $false
                    } else {
                        $fields += $currentField
                    }
                    $currentField = ""
                } elseif ($char -eq $delimiter -and $inQuotes) {
                    $isQuotingRequired = $true
                    $currentField += $char
                } else {
                    $currentField += $char
                }
                $i++
            }
            # Add the last field
            $fields += $currentField
            return $fields
        }

        # Helper function to format CSV field
        function Format-CsvField {
            param(
                [string]$field
            )
            [string] $escapedDelimiter = [regex]::Escape($Delimiter)
            if ( $field -match '^".+"$' ){
                # Field needs quoting
                [string] $strippedField = $field -replace '^"|"$', ''
                return $('"' + ($strippedField -replace '"', '""') + '"')
            } elseif ($field -match '["' + $escapedDelimiter + '\r\n]') {
                # Field needs quoting
                return $('"' + ($field -replace '"', '""') + '"')
            }
            return $field
        }

        # Helper function to process a single line
        function Process-Line {
            param([string]$line)
            
            [string[]] $fields = Parse-CsvLine -line $line -delimiter $Delimiter
            
            # Process specified columns
            foreach ($colIndex in $Column) {
                $fieldIndex = $colIndex - 1
                if ($fieldIndex -lt $fields.Count) {
                    $currentValue = $fields[$fieldIndex]
                    $fields[$fieldIndex] = $ScriptBlock.InvokeWithContext($null, [psvariable]::new('_', $currentValue))
                }
            }
            # Format and output processed line
            return $(@($fields | ForEach-Object { Format-CsvField $_ }) -join $Delimiter)
        }
    }

    process {
        try {
            if ($isFirstLine) {
                # Process header line
                if ( $Path ){
                    [string] $header = Get-Content -Path $Path -TotalCount 1 -Encoding $Encoding
                } else {
                    if ( $InputObject.Count -eq 0) {
                        Write-Error "No input provided. Please specify either -Path or input from pipeline." -ErrorAction Stop
                    }
                    [string] $header = $InputObject[0]
                }
                [string[]] $headerAry = Parse-CsvLine -line $header -delimiter $Delimiter
                $maxColumnIndex = $headerAry.Count

                # Validate column indices
                $invalidIndices = $Column | Where-Object { $_ -lt 1 -or $_ -gt $maxColumnIndex }
                if ($invalidIndices) {
                    Write-Host "Invalid column indices specified: $($invalidIndices -join ', ')" -ForegroundColor Red
                    Write-Error "Valid range: 1 to $maxColumnIndex" -ErrorAction Stop
                }

                # Output header if not NoHeader, otherwise process first line
                if (-not $NoHeader) {
                    @($headerAry | ForEach-Object { Format-CsvField $_ }) -join $Delimiter
                } else {
                    Process-Line $header
                }
                $isFirstLine = $false

                # If input is from pipeline, process the rest of the first batch
                if ($InputObject -and $InputObject.Count -gt 1) {
                    $InputObject | Select-Object -Skip 1 | ForEach-Object {
                        Process-Line $_
                    }
                }
            } else {
                # Process data lines
                if ($InputObject) {
                    $InputObject | ForEach-Object {
                        Process-Line $_
                    }
                }
            }
        } catch {
            Write-Error $Error[0] -ErrorAction Stop
        }
    }

    end {
        try {
            # Process remaining lines if input is from file
            if ($Path -and $InputObject.Count -eq 0) {
                # Skip header line only if not NoHeader
                if ($NoHeader) {
                    Get-Content -Path $Path -Encoding $Encoding | ForEach-Object {
                        Process-Line $_
                    }
                } else {
                    Get-Content -Path $Path -Encoding $Encoding | Select-Object -Skip 1 | ForEach-Object {
                        Process-Line $_
                    }
                }
            }
        } catch {
            Write-Error $Error[0] -ErrorAction Stop
        }
    }
}
# set alias
[String] $tmpAliasName = "csv2proc"
[String] $tmpCmdName   = "Process-CsvColumn"
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
