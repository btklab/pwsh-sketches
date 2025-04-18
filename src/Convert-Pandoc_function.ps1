<#
.SYNOPSIS
    Convert-Pandoc - Converts text from one format to another using Pandoc.


    This script uses Pandoc for text conversion.
    Please note that Pandoc is licensed under
    the GNU General Public License (GPL), and its
    licensing terms apply to its use.
    For more details, please refer to the official
    Pandoc website <https://pandoc.org>

.DESCRIPTION
    This function accepts text input through the pipeline (for example, Markdown) and converts it to another format (for example, Dokuwiki) using Pandoc.
    The source format is specified with the -from parameter, and the target format is specified with the -to parameter. The defaults are "markdown" for the source and "html5" for the target.

.PARAMETER From
    Specifies the source format (e.g., "markdown"). The default value is "markdown".

.PARAMETER To
    Specifies the target format (e.g., "dokuwiki"). The default value is "dokuwiki".

.EXAMPLE
    Get-Content sample.md | Convert-PandocText -From markdown -To dokuwiki

.NOTES
    Pandoc must be installed and available in the PATH.
#>
function Convert-Pandoc {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False, Position=0)]
        [Alias('f')]
        [ValidateSet(
            "bibtex", "biblatex", "bits", "commonmark",
            "commonmark_x", "creole", "csljson", "csv",
            "tsv", "djot", "docbook", "docx",
            "dokuwiki", "endnotexml", "epub", "fb2",
            "gfm", "haddock", "html", "ipynb",
            "jats", "jira", "json", "latex",
            "markdown", "markdown_mmd", "markdown_phpextra",
            "markdown_strict", "mediawiki", "man", "mdoc",
            "muse", "native", "odt", "opml", "org",
            "pod", "ris", "rtf", "rst", "t2t", "textile",
            "tikiwiki", "twiki", "typst", "vimwiki"
        )]
        [string]$From = "markdown"
        ,
        [Parameter(Mandatory=$False, Position=1)]
        [Alias('t')]
        [ValidateSet(
            "ansi", "asciidoc", "asciidoc_legacy", "asciidoctor",
            "beamer", "bibtex", "biblatex", "chunkedhtml",
            "commonmark", "commonmark_x", "context", "csljson",
            "djot", "docbook", "docbook4", "docbook5", "docx",
            "dokuwiki", "epub", "epub3", "epub2", "fb2",
            "gfm", "haddock", "html", "html5", "html4",
            "icml", "ipynb", "jats_archiving", "jats_articleauthoring",
            "jats_publishing", "jats", "jira", "json",
            "latex", "man", "markdown", "markdown_mmd",
            "markdown_phpextra", "markdown_strict", "markua", "mediawiki",
            "ms", "muse", "native", "odt",
            "opml", "opendocument", "org", "pdf",
            "plain", "pptx", "rst", "rtf",
            "texinfo", "textile", "slideous", "slidy",
            "dzslides", "revealjs", "s5", "tei",
            "typst", "xwiki", "zimwiki"
        )]
        [string]$To = "html5"
        ,
        [Parameter(Mandatory=$False)]
        [Alias('v')]
        [switch]$Version
        ,
        [Parameter(Mandatory=$False)]
        [Alias('h')]
        [Alias('man')]
        [switch]$Help
        ,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$InputText
    )
    Begin {
        [string[]] $buffer = @()
        if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
            Write-Error "Pandoc is not installed or not found in the PATH. Please install Pandoc." -ErrorAction Continue
            Write-Error "winget install --id JohnMacFarlane.Pandoc --source winget -e" -ErrorAction Stop
            return
        }
        if ( $Version ){
            pandoc --version
            return
        }
        if ( $Help ){
            pandoc --help
            return
        }
    }
    Process {
        $buffer += [string] $_
    }
    End {
        # Join the lines received via the pipeline into a single string with newline characters.
        $inputContent = $buffer -join "`n"
        # Convert the text using Pandoc. The -s (standalone) option is included; remove it if not needed.
        $convertedText = $inputContent | pandoc -f $From -t $To --standalone
        Write-Output $convertedText
    }
}
# set alias
[String] $tmpAliasName = "convpandoc"
[String] $tmpCmdName   = "Convert-Pandoc"
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
