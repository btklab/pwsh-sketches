<#
.SYNOPSIS
  Join-Blank (Alias: joinb) - Blank-line records to delimited single-line or vice versa.
  
  Converts text between a multi-line list format, where records are separated by blank lines, 
  and a single-line, delimited format. It also performs the reverse operation (-Reverse).

.DESCRIPTION
  This cmdlet is designed to efficiently reshape text data using PowerShell pipelines, specifically for list formats 
  where records are naturally delimited by empty lines.

  In 'ToList' mode (default), it reads multi-line input and joins fields into a single, delimited line per record.
  A record is concluded when an empty or whitespace-only line is encountered.
  Input lines containing the Delimiter are sanitized by replacing the delimiter with an underscore ('\_') to prevent field corruption.

  In 'FromList' mode (-Reverse), it takes single-line, delimited text and splits each line back into multiple fields, 
  each field placed on its own newline, with records separated by a blank line.

.PARAMETER InputObject
  The input text line by line to be processed. This parameter accepts input from the pipeline.

.PARAMETER Delimiter
  The character or string used for joining fields into a single line (ToList) or splitting a single line into fields (FromList).
  Defaults to a single space ' '.

.PARAMETER Reverse
  Switches the operation to 'FromList' mode, converting single-line delimited records back into a multi-line list format.

.EXAMPLE
    1..9 | %{if($_ % 4 -eq 0){$_;""}else{$_}}
    
    1
    2
    3
    4

    5
    6
    7
    8

    9

    1..9 | %{ if($_ % 4 -eq 0){$_;""}else{$_} } | Join-Blank

    1 2 3 4
    5 6 7 8
    9

.EXAMPLE
    1..9 | %{ if($_ % 4 -eq 0){$_;""}else{$_} } | Join-Blank -d ","

    1,2,3,4
    5,6,7,8
    9

.LINK
  Join-While, Join-Until, Trim-EmptyLine,
  Join-Step, Join-Blank,
  list2txt, csv2txt

#>
function Join-Blank {
    [CmdletBinding(DefaultParameterSetName = 'ToList')]
    [OutputType([string])]
    param(
        # --- ToList Parameter Set ---
        [Parameter(Mandatory = $false, ParameterSetName = 'ToList')]
        [switch]$ToList, # Dummy switch for parameter set differentiation, although not strictly needed here.

        # --- FromList (Reverse) Parameter Set ---
        [Parameter(ParameterSetName = 'FromList', Mandatory = $true)]
        [Alias('r')]
        [switch]$Reverse,

        # --- Do not replace delimiter ---
        [Parameter(ParameterSetName = 'ToList')]
        [switch]$AsIs,

        # Delimiter is available in both sets
        [Parameter(Mandatory = $false, ParameterSetName = 'ToList')]
        [Parameter(Mandatory = $false, ParameterSetName = 'FromList')]
        [Alias('d')]
        [string]$Delimiter = ' ',

        # Accepts input from the pipeline, line by line
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string]$InputObject
    )

    Begin {
        # Initialize a buffer (List) to hold the fields of the current record.
        $recordBuffer = [System.Collections.Generic.List[string]]::new()
        
        # Flag to ensure the first record in FromList mode is not preceded by a blank line.
        if ($PSCmdlet.ParameterSetName -eq 'FromList') {
            [bool] $isFirstRecord = $true
        }
    }

    Process {
        # Determine the operation mode based on the parameter set.
        switch ($PSCmdlet.ParameterSetName) {
            'ToList' {
                # Check if the current line is blank or contains only whitespace.
                if ([string]::IsNullOrWhiteSpace($InputObject)) {
                    # Blank line signals the end of a record.
                    if ($recordBuffer.Count -gt 0) {
                        # Output the joined record and reset the buffer.
                        Write-Output ($recordBuffer -join $Delimiter)
                        $recordBuffer.Clear()
                    }
                }
                else {
                    # Data line: Sanitize and add to the current record buffer.
                    if ( $AsIs ){
                        [string] $sanitizedLine = $InputObject
                    } else {
                        [string] $sanitizedLine = $InputObject.Replace($Delimiter, '\_')
                    }
                    $recordBuffer.Add($sanitizedLine)
                }
            }
            'FromList' {
                # --- Reverse operation: Convert single-line to multi-line ---

                # Output a blank line as a record separator, but skip it for the very first record.
                if (-not $isFirstRecord) {
                    Write-Output ''
                }

                # Split the input line into individual fields based on the delimiter.
                [string[]] $fields = $InputObject.Split($Delimiter)

                # Output each field on its own line.
                foreach ($field in $fields) {
                    Write-Output $field
                }
                
                [bool] $isFirstRecord = $false
            }
        }
    }

    End {
        # Finalization: Check for any remaining content in the buffer.
        if ($PSCmdlet.ParameterSetName -eq 'ToList' -and $recordBuffer.Count -gt 0) {
            # Output the final record if the input ended without a trailing blank line.
            Write-Output ($recordBuffer -join $Delimiter)
        }
    }
}
# set alias
[String] $tmpAliasName = "joinb"
[String] $tmpCmdName   = "Join-Blank"
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
