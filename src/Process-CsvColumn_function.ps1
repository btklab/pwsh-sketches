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
        [-IncludeRow <Int32[]>]
        [-ExcludeRow <Int32[]>]

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
    Valid values:
        ansi, bigendianutf32, utf7, utf8NoBOM
        ascii, oem, utf8, utf32
        bigendianunicode, unicode, utf8BOM

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

    # Process columns 1 and 2 and rows 2 from a file, replacing "o" with "*" and keeping quotes
    $csv | csv2proc -Column 1,2 -ScriptBlock { $_ -replace "o", "*" } -IncludeRow 2
        Name,Comment,Age,Title,Salary
        J*hn D*e,"He said, ""Hell*!""",30,Engineer,50000
        Jane Smith,"Loves ""Python"" and coffee",27,Developer,55000
        Bob Johnson,"Works on ""AI, ML"" projects",35,Data Scientist,70000

    # Process columns 1 and 2 and rows 2 from a file, replacing "o" with "*" and keeping quotes
    $csv | csv2proc -Column 1,2 -ScriptBlock { $_ -replace "o", "*" } -FirstRow
        Name,Comment,Age,Title,Salary
        J*hn D*e,"He said, ""Hell*!""",30,Engineer,50000
        Jane Smith,"Loves ""Python"" and coffee",27,Developer,55000
        Bob Johnson,"Works on ""AI, ML"" projects",35,Data Scientist,70000

#>
function Process-CsvColumn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [Alias('c','Col')]
        [int[]]$Column,

        [Parameter(Mandatory=$true, Position=1)]
        [Alias('s','Script')]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory=$false)]
        [Alias('d')]
        [string]$Delimiter = ',',

        [Parameter(Mandatory=$false)]
        [Alias('f')]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [ValidateSet(
            'ansi','bigendianutf32','utf7','utf8NoBOM',
            'ascii','oem','utf8','utf32',
            'bigendianunicode','unicode','utf8BOM'
        )]
        [string]$Encoding = 'utf8',

        [Parameter(Mandatory=$false)]
        [Alias('nh')]
        [switch]$NoHeader,

        [Parameter(Mandatory=$false)]
        [switch]$KeepQuotes,

        [Parameter(Mandatory=$false)]
        [Alias('r', 'Row')]
        [int[]]$IncludeRow,

        [Parameter(Mandatory=$false)]
        [Alias('ex', 'exclude')]
        [int[]]$ExcludeRow,

        [Parameter(Mandatory=$false)]
        [Alias('first')]
        [switch]$FirstRow,

        [Parameter(ValueFromPipeline=$true)]
        [string[]]$InputObject
    )

    begin {
        # Initialize state variables before processing input
        [bool]$isFirstLine = $true
        [int]$lineNumber = 0
        [int]$totalLines = 0
        $linesBuffer = @()

        # Parse a single CSV line into fields considering quoted delimiters and escaped quotes
        function Parse-CsvLine {
            param([string]$line, [string]$delimiter)
            $fields = @()
            $currentField = ""
            $inQuotes = $false
            for ($i = 0; $i -lt $line.Length; $i++) {
                $char = $line[$i]
                if ($char -eq '"') {
                    # Handle escaped quote inside quoted field
                    if ($inQuotes -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '"') {
                        $currentField += '"'; $i++
                    } else {
                        # Toggle quoted field state
                        $inQuotes = -not $inQuotes
                    }
                } elseif ($char -eq $delimiter -and -not $inQuotes) {
                    # Field delimiter outside quotes ends the current field
                    $fields += $currentField
                    $currentField = ""
                } else {
                    # Regular character, append to current field
                    $currentField += $char
                }
            }
            # Add last field
            $fields += $currentField
            return $fields
        }

        # Format a CSV field by quoting if needed and escaping inner quotes
        function Format-CsvField {
            param([string]$field)
            if ($field -match '[",\r\n]') {
                # Quote and double quotes inside field
                return '"' + ($field -replace '"', '""') + '"'
            }
            return $field
        }

        # Decide whether the current line should be processed based on row filters and flags
        function ShouldProcessLine {
            param([int]$currentLine)
            if ($FirstRow) {
                # Process only first data row depending on header presence
                if ($NoHeader) {
                    return $currentLine -eq 1
                } else {
                    return $currentLine -eq 2
                }
            }
            if ($IncludeRow) {
                return $IncludeRow -contains $currentLine
            } elseif ($ExcludeRow) {
                return -not ($ExcludeRow -contains $currentLine)
            }
            return $true
        }

        # Process a CSV line by applying the script block to specified columns
        function Process-Line {
            param([string]$line, [int]$lineNumber)
            $fields = Parse-CsvLine -line $line -delimiter $Delimiter
            if (ShouldProcessLine -currentLine $lineNumber) {
                foreach ($colIndex in $Column) {
                    $i = $colIndex - 1
                    if ($i -lt $fields.Count) {
                        # Apply user scriptblock to the field, with $_ set to the field value
                        $fields[$i] = $ScriptBlock.InvokeWithContext($null, [psvariable]::new('_', $fields[$i]))
                    }
                }
            }
            # Recombine fields into a CSV line with proper formatting
            return ($fields | ForEach-Object { Format-CsvField $_ }) -join $Delimiter
        }
    }

    process {
        # Read lines from file if Path specified, else use pipeline input
        $lines = if ($Path) { Get-Content -LiteralPath $Path -Encoding $Encoding } else { $InputObject }
        foreach ($line in $lines) {
            $lineNumber++
            if ($isFirstLine) {
                if ($NoHeader) {
                    # If no header, process first line normally
                    Write-Output (Process-Line $line $lineNumber)
                } else {
                    # Otherwise output header line as is
                    Write-Output $line
                }
                $isFirstLine = $false
            } else {
                # Process subsequent lines
                Write-Output (Process-Line $line $lineNumber)
            }
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
