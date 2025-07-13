<#
.SYNOPSIS
    Decode-MimeHeader - Decodes a MIME-encoded header.

    Decodes MIME-encoded words within a string (e.g., email headers).

.DESCRIPTION
    This function finds and decodes MIME-encoded words (e.g., =?UTF-8?B?...?=)
    embedded in a string. It supports both Base64 ("B") and Quoted-Printable ("Q")
    encodings and can process full or partial MIME-encoded lines. Accepts pipeline input.

.EXAMPLE
    PS> "Re: =?UTF-8?B?44Oe44Kk?= + update" | Decode-MimeHeader

.EXAMPLE
    PS> Get-Content headers.txt | Decode-MimeHeader
#>
function Decode-MimeHeader {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [string]$InputString
    )

    begin {
        $mimePattern = '(=\?([^\?]+)\?([bBqQ])\?([^\?]+)\?=)'
    }

    process {
        if ([string]::IsNullOrWhiteSpace($InputString)) {
            return
        }

        $decodedString = [System.Text.RegularExpressions.Regex]::Replace($InputString, $mimePattern, {
            param($match)

            $charset     = $match.Groups[2].Value
            $encoding    = $match.Groups[3].Value.ToUpper()
            $encodedText = $match.Groups[4].Value

            switch ($encoding) {
                'B' {
                    try {
                        $bytes = [System.Convert]::FromBase64String($encodedText)
                    } catch {
                        return "[Invalid Base64]"
                    }
                }
                'Q' {
                    # Safely decode quoted-printable using Match object
                    $qpText = $encodedText -replace '_', ' '

                    $qpBytes = [System.Text.Encoding]::GetEncoding("iso-8859-1").GetBytes(
                        [System.Text.RegularExpressions.Regex]::Replace($qpText, '=([0-9A-Fa-f]{2})', {
                            param($m)
                            [char][int]"0x$($m.Groups[1].Value)"
                        })
                    )
                    $bytes = $qpBytes
                }
                default {
                    return "[Unsupported encoding: $encoding]"
                }
            }

            try {
                $decodedText = [System.Text.Encoding]::GetEncoding($charset).GetString($bytes)
            } catch {
                $decodedText = "[Unsupported charset: $charset]"
            }

            return $decodedText
        })

        Write-Output $decodedString
    }
}
