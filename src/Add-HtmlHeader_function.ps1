<#
.SYNOPSIS
  Add-HtmlHeader - Wraps in a simple HTML5 structure.
  
  Wraps input text or objects in a simple HTML5 structure.

.DESCRIPTION

  This function takes text or object input from the pipeline
  and generates a simple HTML5 document.

  If the input is a full HTML document, the function will
  extract and use only the content within the <body> tag.

  It allows for customization of the title, language, CSS,
  and JavaScript libraries like MathJax.


  The output can be written to the pipeline or saved to a file.


.PARAMETER Title
  Specifies the title of the HTML document. Defaults to "Document".

.PARAMETER Lang
  Specifies the language of the HTML document (e.g., "en", "ja").
  Defaults to "ja".

.PARAMETER EncodeHtml
  If specified, encodes the input content into HTML-safe text.
  This is useful for displaying plain text that might contain
  characters like '<' or '>'.

.PARAMETER CssPath
  Specifies the path(s) to one or more external CSS files to be
  linked in the HTML head.

.PARAMETER OutFile
  Specifies the path to an output file. If provided, the generated
  HTML will be saved to this file instead of being written to the
  pipeline.

.PARAMETER UseWaterCss
  If specified, includes a link to the Water.css stylesheet for a clean,
  class-less design. This overrides the default built-in styles.

.PARAMETER UseMathJax
  If specified, includes the MathJax library to render mathematical
  formulas written in LaTeX or MathML.

.PARAMETER InputObject
  The content to be placed inside the <body> tag of the HTML document.
  This parameter accepts input from the pipeline.

.EXAMPLE
  PS C:\> Get-Content -Path .\my-text.txt | Add-HtmlHeader -Title "My First Document" | Out-File -FilePath .\output.html

  Description:
  Reads the content of 'my-text.txt', wraps it in an HTML structure with the title "My First Document", and saves the result to 'output.html'.

.EXAMPLE
  PS C:\> "## Hello World`n*This is a test.*" | Add-HtmlHeader -UseWaterCss -OutFile .\hello.html; Invoke-Item .\hello.html

  Description:
  Takes a string, wraps it in HTML using the Water.css theme, saves it to 'hello.html', and then opens the file in the default browser.

.EXAMPLE
  PS C:\> Get-Process | Out-String | Add-HtmlHeader -Title "Process List" -EncodeHtml

  Description:
  Gets the current list of processes, converts them to a string, and creates an HTML document. The -EncodeHtml switch ensures that the text is displayed correctly in the browser without being interpreted as HTML.

.EXAMPLE
  PS C:\> $latex = 'When $a \ne 0$, there are two solutions to \(ax^2 + bx + c = 0\) and they are $$x = {-b \pm \sqrt{b^2-4ac} \over 2a}.$$'
  PS C:\> $latex | Add-HtmlHeader -Title "Math Test" -UseMathJax

  Description:
  Creates an HTML document that correctly renders a LaTeX mathematical formula using MathJax.
#>
function Add-HtmlHeader {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Title = "Document",

        [Parameter(Mandatory=$false)]
        [string]$Lang = "ja",

        [Parameter(Mandatory=$false)]
        [Alias('encode')]
        [switch]$EncodeHtml,

        [Parameter(Mandatory = $false)]
        [Alias('css')]
        [string[]]$CssPath,

        [Parameter(Mandatory = $false)]
        [Alias('o')]
        [string]$OutFile,

        [Parameter(Mandatory=$false)]
        [Alias('w', 'WaterCss')]
        [switch]$UseWaterCss,

        [Parameter(Mandatory=$false)]
        [Alias('wl', 'WaterCssLight', 'Light')]
        [switch]$UseWaterCssLight,

        [Parameter(Mandatory=$false)]
        [Alias('wd', 'WaterCssDark', 'Dark')]
        [switch]$UseWaterCssDark,

        [Parameter(Mandatory=$false)]
        [Alias('m', 'math', 'MathJax')]
        [switch]$UseMathJax,

        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object[]] $InputObject
    )

    # --- Read and Process Input ---
    # Read all input from the pipeline and combine it into a single string.
    # The $input automatic variable enumerates pipeline input.
    # Out-String is necessary to handle multi-line input and objects correctly.
    if ( $input.Count -gt 0 ){
        # Test if the input contains body tag
        [string] $inputString = $input | Out-String -Stream
        if ( $inputString -match '<body' ){
            [string[]]$rawContent = ($input | Out-String) -match '(?si)<body.*?>(.*)<\/body>' `
                | ForEach-Object { $matches[1] }
        } else {
            # If no body tag is found, treat the input as raw content.
            [string[]]$rawContent = $input | ForEach-Object { Write-Output $_ }
        }
    } else {
        return
    }

    # --- Prepare Content for HTML ---
    [string[]]$bodyContent = @()
    if ( $EncodeHtml ){
        # If the EncodeHtml switch is set, HTML-encode each line of content.
        foreach ( $line in $rawContent ){
            [string]$encodedContent = [System.Web.HttpUtility]::HtmlEncode($line)
            [string[]]$bodyContent += $encodedContent
        }
    } else {
        # Otherwise, use the raw content as is.
        foreach ( $line in $rawContent ){
            [string]$asisContent = $line
            [string[]]$bodyContent += $asisContent
        }
    }

    # --- Prepare Stylesheet ---
    if ($UseWaterCss -or $UseWaterCssLight -or $UseWaterCssDark) {
        [string[]]$stylesheetAry = @()
        # Use the external Water.css stylesheet for a clean, classless theme.
        if ( $UseWaterCssLight ) {
            [string[]]$stylesheetAry += '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/water.css@2/out/light.css">'
        }
        elseif ( $UseWaterCssDark ) {
            [string[]]$stylesheetAry += '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/water.css@2/out/dark.css">'
        }
        else {
            # Default to the standard Water.css stylesheet.
            [string[]]$stylesheetAry += '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/water.css@2/out/water.css">'
        }
    }
    else {
        # Use a basic, default inline style as a fallback.
        [string[]]$stylesheetAry = @()
        [string[]]$stylesheetAry +="<style>"
        [string[]]$stylesheetAry +="  body { "
        [string[]]$stylesheetAry +="    font-family: sans-serif;"
        [string[]]$stylesheetAry +="    line-height: 1.6;"
        [string[]]$stylesheetAry +="    padding: 1em;"
        [string[]]$stylesheetAry +="    margin: 0 auto;"
        [string[]]$stylesheetAry +="    max-width: 800px;"
        [string[]]$stylesheetAry +="    background-color: #f8f9fa;"
        [string[]]$stylesheetAry +="    color: #212529;"
        [string[]]$stylesheetAry +="  }"
        [string[]]$stylesheetAry +="  pre {"
        [string[]]$stylesheetAry +="    white-space: pre-wrap;"
        [string[]]$stylesheetAry +="    word-wrap: break-word;"
        [string[]]$stylesheetAry +="    background-color: #fff;"
        [string[]]$stylesheetAry +="    border: 1px solid #dee2e6;"
        [string[]]$stylesheetAry +="    padding: 1em;"
        [string[]]$stylesheetAry +="    border-radius: 0.25rem;"
        [string[]]$stylesheetAry +="  }"
        [string[]]$stylesheetAry +="</style>"
    }
    # Mathjax
    if ( $UseMathJax) {
        # Use a basic, default inline style as a fallback.
        [string[]]$mathjaxSctriptAry = @()
        [string[]]$mathjaxSctriptAry += '<script>'
        [string[]]$mathjaxSctriptAry += '  MathJax = {'
        [string[]]$mathjaxSctriptAry += '    chtml: {'
        [string[]]$mathjaxSctriptAry += '      matchFontHeight: false'
        [string[]]$mathjaxSctriptAry += '    },'
        [string[]]$mathjaxSctriptAry += '    tex: {'
        [string[]]$mathjaxSctriptAry += '      inlineMath: [["$", "$"], ["\\(", "\\)"]],'
        [string[]]$mathjaxSctriptAry += '      displayMath: [["$$", "$$"], ["\\[", "\\]"]]'
        [string[]]$mathjaxSctriptAry += '    }'
        [string[]]$mathjaxSctriptAry += '  };'
        [string[]]$mathjaxSctriptAry += '</script>'
        [string[]]$mathjaxSctriptAry += '<script type="text/javascript" id="MathJax-script" async'
        [string[]]$mathjaxSctriptAry += '  src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js">'
        [string[]]$mathjaxSctriptAry += '</script>'
    }
    # --- Assemble Final HTML ---
    [string[]]$outputHtmlAry = @()
    $outputHtmlAry += '<!DOCTYPE html>'
    if ( $Lang -ne '' ){
        $outputHtmlAry += "<html lang=""$Lang"">"
    }
    $outputHtmlAry += '<head>'
    $outputHtmlAry += '  <meta charset="UTF-8">'
    $outputHtmlAry += '  <meta name="viewport" content="width=device-width, initial-scale=1.0">'
    $outputHtmlAry += "  <title>$Title</title>"
    foreach ( $line in $stylesheetAry ) {
        # Output each line of stylesheet, ensuring proper HTML encoding.
        $outputHtmlAry += "  $line"
    }
    if ( $CssPath.Count -gt 0 ){
        foreach ( $cssFile in $CssPath ) {
            # Output each CSS file link, ensuring proper HTML encoding.
            [string] $cssFile = $cssFile.Replace('\', '/')
            $outputHtmlAry += "  <link rel=""stylesheet"" href=""$cssFile"">"
        }
    }
    if ( $UseMathJax ){
        foreach ( $line in $mathjaxSctriptAry ) {
            # Output each line of MathJax script, ensuring proper HTML encoding.
            $outputHtmlAry += "  $line"
        }
    }
    $outputHtmlAry += '</head>'
    $outputHtmlAry += '<body>'
    foreach ( $line in $bodyContent ) {
        # Output each line of content, ensuring proper HTML encoding.
        $outputHtmlAry +="  $line"
    }
    $outputHtmlAry += '</body>'
    $outputHtmlAry += '</html>'

    if ($PSBoundParameters.ContainsKey('OutFile')) {
        Set-Content -LiteralPath $OutFile -Value $outputHtmlAry -Encoding Utf8 -ErrorAction Stop
        Get-Item -LiteralPath $OutFile
    }
    else {
        Write-Output $outputHtmlAry
    }
}

