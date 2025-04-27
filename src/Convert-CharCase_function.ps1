<#
.SYNOPSIS
    Convert-CharCase (Alias: convChar) -- Capitalize the first letter of each word.

    Capitalize the first letter of each word by default.
    Accepts input from the pipeline.

    Parameters:
      -Delimiter:
        - Specifies the delimiter used to split the input string.
        - Default value is a space (" ").

      -ToLowerInvariant:
        - A switch parameter.
        - If specified, converts the remaining letters of each word to lowercase.
        - If omitted, does not convert the remaining letters.

      -AsTitle:
        - A switch parameter.
        - If specified, converts the string to title case format.
        - That is, it keeps specific words
            e.g., 
                "a", "an", "the", "at", "by", "for", "in", "of",
                "on", "to", "up", "and", "but", "or", "so", "yet", "as",
                "because", "with", "without", "from", "into", "onto", "out",
                "off", "than", "though", "till", "unless", "until", "when",
                "where", "while"
                in lowercase.

.NOTES
    String.ToUpperInvariant Method (System)
    <https://learn.microsoft.com/en-us/dotnet/api/system.string.toupperinvariant>


.EXAMPLE
    "hello world" | Convert-CharCase
    Hello World ## default
    
    "HELLO WORLD" | Convert-CharCase -ToLowerInvariant
    Hello world
    
    "one,two,three" | Convert-CharCase -Delimiter ","
    One,Two,Three
    
    "one,two,three" | Convert-CharCase -Delimiter "," -ReplaceDelimiter '-'
    One-Two-Three
    
    "the quick brown fox" `
        | Convert-CharCase -AsTitle
    The Quick Brown Fox

    "the quick brown fox" `
        | Convert-CharCase -AsTitle `
        | Convert-CharCase -AsSentence
    The Quick Brown Fox

    "the quick brown fox" `
        | Convert-CharCase -AsTitle `
        | Convert-CharCase -AsSentence -ToLowerInvariant
    The quick brown fox

    "The Quick Brown Fox" `
        | Convert-CharCase -AsKey
    the-quick-brown-fox

    "The Quick Brown Fox" `
        | Convert-CharCase -AsKey -ReplaceDelimiter '@'
    the@quick@brown@fox

#>
function Convert-CharCase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$False)]
        [Alias('d')]
        [string] $Delimiter = " "
        ,
        [Parameter(Mandatory=$False)]
        [Alias('r')]
        [string] $ReplaceDelimiter
        ,
        [Parameter(Mandatory=$False)]
        [Alias('li')]
        [switch] $ToLowerInvariant
        ,
        [Parameter(Mandatory=$False)]
        [Alias('Lower')]
        [switch] $ToLower
        ,
        [Parameter(Mandatory=$False)]
        [Alias('Upper')]
        [switch] $ToUpper
        ,
        [Parameter(Mandatory=$False)]
        [Alias('s')]
        [switch] $AsSentence
        ,
        [Parameter(Mandatory=$False)]
        [Alias('k')]
        [switch] $AsKey
        ,
        [Parameter(Mandatory=$False)]
        [Alias('t')]
        [switch] $AsTitle
        ,
        [Parameter(Mandatory=$False, ValueFromPipeline = $true)]
        [string] $InputString
    )
    begin {
        # set output delimiter
        if ( $ReplaceDelimiter) {
            [string] $OutDelimiter = $ReplaceDelimiter
        } else {
            [string] $OutDelimiter = $Delimiter
        }
    }
    process {
        # Returns input string as is if it is null or empty
        if ([string]::IsNullOrEmpty($InputString)) {
            return $InputString
        }
        if ( $AsSentence ){
            [string] $WriteLine = $InputString `
                | Convert-CharCase -Delimiter '. '  -ToLowerInvariant:$ToLowerInvariant `
                | Convert-CharCase -Delimiter '." ' -ToLowerInvariant:$ToLowerInvariant `
                | Convert-CharCase -Delimiter ".' " -ToLowerInvariant:$ToLowerInvariant `
                | Convert-CharCase -Delimiter '.” ' -ToLowerInvariant:$ToLowerInvariant `
                | Convert-CharCase -Delimiter '.) ' -ToLowerInvariant:$ToLowerInvariant `
                | Convert-CharCase -Delimiter '.> ' -ToLowerInvariant:$ToLowerInvariant `
                | Convert-CharCase -Delimiter '.} ' -ToLowerInvariant:$ToLowerInvariant `
                | Convert-CharCase -Delimiter '.] ' -ToLowerInvariant:$ToLowerInvariant
            if ( $ReplaceDelimiter ){
                [string] $WriteLine = $WriteLine.Replace($Delimiter, $ReplaceDelimiter)
            }
            return $WriteLine
        }
        if ( $ToUpper ){
            [string] $WriteLine = $InputString.ToUpper()
            if ( $ReplaceDelimiter ){
                [string] $WriteLine = $WriteLine.Replace($Delimiter, $ReplaceDelimiter)
            }
            return $WriteLine
        }
        if ( $ToLower ){
            [string] $WriteLine = $InputString.ToLower()
            if ( $ReplaceDelimiter ){
                [string] $WriteLine = $WriteLine.Replace($Delimiter, $ReplaceDelimiter)
            }
            return $WriteLine
        }
        if ( $AsKey ){
            [string] $WriteLine = $InputString.ToLower()
            if ( $ReplaceDelimiter ){
                [string] $WriteLine = $WriteLine.Replace($Delimiter, $ReplaceDelimiter)
            } else {
                [string] $WriteLine = $WriteLine.Replace($Delimiter, '-')
            }
            return $WriteLine
        }        
        # Splits the string into an array of words using the specified delimiter
        [string[]] $words = $InputString.Split($Delimiter)
        # Processes each word
        for ($i = 0; $i -lt $words.Length; $i++) {
            [string] $word = $words[$i]
            # Check if the word is not empty
            if ($word) {
                # Convert the first character to uppercase
                [string] $firstChar = [char]::ToUpperInvariant($word[0])
                [string] $restOfWord = $word.Substring(1)
                # Convert the rest of the word to lowercase if the ToLowerInvariant parameter is specified
                if ( $ToLowerInvariant ) {
                    [string] $restOfWord = $restOfWord.ToLowerInvariant()
                }
                [string] $convertedWord = $firstChar + $restOfWord
                 # Apply title case rules if the AsTitle parameter is specified
                if ($AsTitle) {
                    [string[]] $lowerCaseWords = @(
                        "a", "an", "the", "at", "by",
                        "for", "in", "of", "on", "to",
                        "up", "and", "but", "or", "so",
                        "yet", "as", "because", "with", "without",
                        "from", "into", "onto", "out", "off",
                        "than", "though", "till", "unless", "until",
                        "when", "where", "while", "is", "are"
                    )
                    # Capitalize the first word (titles should start with a capital letter)
                    if ($i -eq 0 -or $word -notin $lowerCaseWords) {
                         $words[$i] = $convertedWord
                    }
                    else{
                         $words[$i] = $word.ToLowerInvariant()
                    }
                }
                else{
                    $words[$i] = $convertedWord
                }
            }
            # Handles empty words, preserving original spacing (e.g., multiple spaces)
            else {
                $words[$i] = $word
            }
        }
        # Joins the converted words with the delimiter and returns the result
        [string] $WriteLine = $words -join $OutDelimiter
        return $WriteLine
    }
}
# set alias
[String] $tmpAliasName = "convChar"
[String] $tmpCmdName   = "Convert-CharCase"
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
