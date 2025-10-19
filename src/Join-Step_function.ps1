<#
.SYNOPSIS
  Join-Step (Alias: joins) - Fixed-line records to delimited single-line or vice versa.
  
  Converts text between a multi-line list format, where records are defined by a fixed number of lines (-Step), 
  and a single-line, delimited format. It also performs the reverse operation (-Reverse).

.DESCRIPTION
  This cmdlet is designed to efficiently reshape text data using PowerShell pipelines, specifically for fixed-line formats.

  In 'ToList' mode (default), it reads multi-line input and joins fields into a single, delimited line per record.
  A record is strictly defined by the mandatory -Step parameter (number of lines).
  Input lines containing the Delimiter are sanitized by replacing the delimiter with an underscore ('\_') to prevent field corruption.

  In 'FromList' mode (-Reverse), it takes single-line, delimited text and splits each line back into multiple fields, 
  each field placed on its own newline, with records separated by a blank line.

.PARAMETER InputObject
  The input text line by line to be processed. This parameter accepts input from the pipeline.

.PARAMETER Step
  Specifies the fixed and mandatory number of lines that constitute a single record (N). Every N input lines will be joined.

.PARAMETER Delimiter
  The character or string used for joining fields into a single line (ToList) or splitting a single line into fields (FromList).
  Defaults to a single space ' '.

.PARAMETER Reverse
  Switches the operation to 'FromList' mode, converting single-line delimited records back into a multi-line list format.

.EXAMPLE
  PS> Get-Content fixed_data.txt | Join-Step -Step 3 -Delimiter ','
  Description: Reads fixed_data.txt and treats every 3 lines as a single record, joining them with commas.

.EXAMPLE
  PS> Get-Content delimited_data.txt | Join-Step -Reverse -Delimiter ','
  Description: Converts comma-separated data back into a list format (fields on newlines, records separated by blank lines).

.LINK
  Join-While, Join-Until, Trim-EmptyLine,
  Join-Step, Join-BlankLine,
  list2txt, csv2txt

#>
function Join-Step {
    [CmdletBinding(DefaultParameterSetName = 'ToList')]
    [OutputType([string])]
    param(
        # --- ToList Parameter Set: Requires Step to define record length ---
        [Parameter(ParameterSetName = 'ToList', Mandatory = $true)]
        [Alias('s')]
        [int]$Step,

        # --- FromList (Reverse) Parameter Set: Only needs the Delimiter ---
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
        # Lists are generally more efficient for incremental additions than arrays.
        $recordBuffer = [System.Collections.Generic.List[string]]::new()
        
        # Flag to ensure the first record in FromList mode is not preceded by a blank line.
        if ($PSCmdlet.ParameterSetName -eq 'FromList') {
            $isFirstRecord = $true
        }
    }

    Process {
        # Determine the operation mode based on the parameter set.
        switch ($PSCmdlet.ParameterSetName) {
            'ToList' {
                # Input validation: Ensure Step is a positive integer.
                if ($Step -le 0) {
                    Write-Error "The -Step parameter must be a positive integer (Step > 0) when not using -Reverse." -ErrorAction Stop
                }
                
                # Sanitize input: Replace delimiter characters with '_' to preserve field count integrity.
                if ( $AsIs ){
                    $sanitizedLine = $InputObject
                } else {
                    $sanitizedLine = $InputObject.Replace($Delimiter, '\_')
                }
                $recordBuffer.Add($sanitizedLine)

                # Check if the buffer has reached the fixed step size.
                if ($recordBuffer.Count -ge $Step) {
                    # Join all fields in the buffer with the delimiter and output the single-line record.
                    Write-Output ($recordBuffer -join $Delimiter)
                    $recordBuffer.Clear() # Reset the buffer for the next record.
                }
            }
            'FromList' {
                # --- Reverse operation: Convert single-line to multi-line ---

                # Output a blank line as a record separator, but skip it for the very first record.
                if (-not $isFirstRecord) {
                    Write-Output ''
                }

                # Split the input line into individual fields based on the delimiter.
                $fields = $InputObject.Split($Delimiter)

                # Output each field on its own line.
                foreach ($field in $fields) {
                    Write-Output $field
                }
                
                $isFirstRecord = $false
            }
        }
    }

    End {
        # Finalization: Check for any remaining content in the buffer.
        if ($PSCmdlet.ParameterSetName -eq 'ToList' -and $recordBuffer.Count -gt 0) {
            # Output the partial record if the input ended prematurely.
            Write-Verbose "Input ended before a complete record of $Step lines was formed. Outputting partial record."
            Write-Output ($recordBuffer -join $Delimiter)
        }
    }
}
# set alias
[String] $tmpAliasName = "joins"
[String] $tmpCmdName   = "Join-Step"
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
