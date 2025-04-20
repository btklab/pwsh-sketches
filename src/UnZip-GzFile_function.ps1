<#
.SYNOPSIS
    UnZip-GzFile (Alias: unzipgz) -- Decompress .gz files to standard output.

    Decompresses one or more .gz files and writes the decompressed content to the console (standard output).

.DESCRIPTION
    This function takes one or more .gz files as input via parameters, decompresses the files, and writes
    their decompressed content directly to the standard output. It's designed to work with PowerShell 7+.

.PARAMETER Files
    A string array of one or more paths to .gz files that need to be decompressed.

.EXAMPLE
    UnZip-GzFile -Files "file1.gz", "file2.gz"
    # This will decompress "file1.gz" and "file2.gz", and output the content of each to the console.
#>
function UnZip-GzFile {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory=$True,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True
        )]
        [string[]] $Files
    )
    process {
        foreach ($file in $Files) {
            try {
                # Validate that the file exists
                if (-not (Test-Path -Path $file)) {
                    Write-Error "File not found: $file" -ErrorAction Stop
                    continue
                }
                # Open the GZip stream for reading
                $reader = [System.IO.Compression.GZipStream]::new(
                    [System.IO.File]::OpenRead($file),
                    [System.IO.Compression.CompressionMode]::Decompress
                )
                # Read from the stream and write to standard output
                $buffer = New-Object byte[] 4096
                while (($read = $reader.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    [Console]::OpenStandardOutput().Write($buffer, 0, $read)
                }
            } catch {
                Write-Error "Error reading from GZip stream: $file"
            } finally {
                # Close the stream
                $reader.Dispose > $Null
            } 
        }
    }
}
# set alias
[String] $tmpAliasName = "unzipgz"
[String] $tmpCmdName   = "UnZip-GzFile"
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

