<#
.SYNOPSIS
    UnZip-GzFile (Alias: unzipgz) -- Decompress .gz files to standard output.

    Decompresses one or more .gz files and writes the decompressed
    text content to the console (standard output).

    Specifying the "[-a|-AutoDetectExtension]" switch will
    only unzip files with the ".gz" extension, and will use
    Get-Content for all other files as is.



.DESCRIPTION
    This function takes one or more .gz files as input via parameters, decompresses the files, and writes
    their decompressed content directly to the standard output. It's designed to work with PowerShell 7+.

.PARAMETER Path
    A string array of one or more paths to .gz files that need to be decompressed.

.EXAMPLE
    UnZip-GzFile -Name "file1.gz", "file2.gz"
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
        [Alias('p')]
        [string[]] $Path
        ,
        [Parameter(Mandatory=$False)]
        [Alias('a')]
        [switch] $AutoDetectExtension
        ,
        [Parameter(Mandatory=$False)]
        [Alias('v')]
        [switch] $WriteFileName
    )
    # private function
    function Expand-GzFileAsText {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$True)]
            [string] $f
        )
        try {
            # Open the GZip stream for reading
            $reader = [System.IO.Compression.GZipStream]::new(
                [System.IO.File]::OpenRead($f),
                [System.IO.Compression.CompressionMode]::Decompress
            )
            # Create a StreamReader for text-based reading
            $streamReader = [System.IO.StreamReader]::new($reader)
            # Read and output lines of text to the console
            while (-not $streamReader.EndOfStream) {
                [string] $line = $streamReader.ReadLine()
                Write-Output $line
                # raise error test
                #1/0
            }
        } catch {
            Write-Error "$($_.Exception.Message) - reading from GZip stream: $file" -ErrorAction Stop
        } finally {
            # Close the stream
            $streamReader.Dispose() > $Null
            $reader.Dispose() > $Null
        }
    }
    # main loop
    foreach ($file in $Path) {
        # Validate that the file exists
        if (-not (Test-Path -Path $file)) {
            Write-Error "File not found: $file" -ErrorAction Stop
        }
        # Get file object
        [System.IO.FileInfo] $fileInfo = Get-Item -LiteralPath $file
        [string] $fileExt = $fileInfo.Extension
        [string] $fileNam = $fileInfo.Name
        if ( $WriteFileName ) {
            Write-Host "File: $fileNam" -ForegroundColor Green
        }
        if ( $AutoDetectExtension -and $fileExt -notmatch '\.gz$' ){
            Get-Content -LiteralPath $file -Encoding utf8
        } else {
            # Call the private function to handle decompression for each file
            Expand-GzFileAsText -f $file
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

