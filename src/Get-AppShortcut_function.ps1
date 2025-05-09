<#
.SYNOPSIS
    Get-AppShortcut -Llist up app-shortcuts


    App                  Act                       Key                      Fn Esc     Ano
    ---                  ---                       ---                      -- ---     ---
    IME                  Zenkaku alphanumeric mode Shift <Mu-Henkan>
    Windows Terminal     Split pane                Alt Shift +|-
    Windows Terminal     Switch pane               Alt Arrow
    Windows Terminal     Resize pane               Alt Shift Arrow
    Windows Terminal     Close pane                Ctrl Shift W
    Windows Terminal     Scroll by row             Ctrl Shift Arrow-Up|Down
    Windows Terminal     Scroll by screen          Ctrl Shift PgUp|PgDn
    Microsoft Excel      Full screen               Alt V U                     Esc     Ctrl Shift…
    Microsoft Powerpoint Full screen               Alt W D                  F5 Esc
    Microsoft Word       Full screen               Alt V U                     Esc
    Windows OS           Magnifying glass          Win +                       Win Esc


.EXAMPLE
    Get-AppShortcut  | ft

    App                  Act                       Key                      Fn Esc     Ano
    ---                  ---                       ---                      -- ---     ---
    IME                  Zenkaku alphanumeric mode Shift <Mu-Henkan>
    Windows Terminal     Split pane                Alt Shift +|-
    Windows Terminal     Switch pane               Alt Arrow
    Windows Terminal     Resize pane               Alt Shift Arrow
    Windows Terminal     Close pane                Ctrl Shift W
    Windows Terminal     Scroll by row             Ctrl Shift Arrow-Up|Down
    Windows Terminal     Scroll by screen          Ctrl Shift PgUp|PgDn
    Microsoft Excel      Full screen               Alt V U                     Esc     Ctrl Shift…
    Microsoft Powerpoint Full screen               Alt W D                  F5 Esc
    Microsoft Word       Full screen               Alt V U                     Esc
    Windows OS           Magnifying glass          Win +                       Win Esc


.EXAMPLE
    Get-AppShortcut | Select-Object App,Act,Key

    App                  Act                       Key
    ---                  ---                       ---
    IME                  Zenkaku alphanumeric mode Shift <Mu-Henkan>
    Windows Terminal     Split pane                Alt Shift +|-
    Windows Terminal     Switch pane               Alt Arrow
    Windows Terminal     Resize pane               Alt Shift Arrow
    Windows Terminal     Close pane                Ctrl Shift W
    Windows Terminal     Scroll by row             Ctrl Shift Arrow-Up|Down
    Windows Terminal     Scroll by screen          Ctrl Shift PgUp|PgDn
    Microsoft Excel      Full screen               Alt V U
    Microsoft Powerpoint Full screen               Alt W D
    Microsoft Word       Full screen               Alt V U
    Windows OS           Magnifying glass          Win +

#>
function Get-AppShortcut {
    
Param(
    [Parameter(Mandatory=$False)]
    [Alias('e')]
    [switch] $Excel,

    [Parameter(Mandatory=$False)]
    [Alias('')]
    [switch] $Word
)

$sJson = @"
[
    {
        "App": "Windows OS",
        "Act": "Rotate Screen",
        "Key": "Ctrl Alt Arrow-Up|Down|Left|Right",
        "Fn": "",
        "Esc": "",
        "Ano": "",
        "Uri": "",
        "Note": "",
        "tag": [
            "windows",
            "windows10",
            "windows11"
        ]
    },
    {
        "App": "Windows OS",
        "Act": "Magnifying Glass",
        "Key": "Win +",
        "Fn": "",
        "Esc": "Win Esc",
        "Ano": "",
        "Uri": "",
        "Note": "",
        "tag": [
            "windows",
            "windows10",
            "windows11"
        ]
    },
    {
        "App": "IME",
        "Act": "Zenkaku Alphanumeric Mode",
        "Key": "Shift <Mu-Henkan>",
        "Fn": "",
        "Esc": "",
        "Ano": "",
        "Uri": "",
        "Note": "",
        "tag": [
            "ime"
        ]
    },
    {
        "App": "IME",
        "Act": "Switch Input Language",
        "Key": "Left-Alt Shift",
        "Fn": "",
        "Esc": "",
        "Ano": "",
        "Uri": "",
        "Note": "",
        "tag": [
            "ime"
        ]
    },
    {
        "App": "Windows Terminal",
        "Act": "Split Pane",
        "Key": "Alt Shift +|-",
        "Fn": "",
        "Esc": "",
        "Ano": "",
        "Uri": "https://learn.microsoft.com/ja-jp/windows/terminal/panes",
        "Note": "",
        "tag": [
            "terminal"
        ]
    },
    {
        "App": "Windows Terminal",
        "Act": "Switch Pane",
        "Key": "Alt Arrow",
        "Fn": "",
        "Esc": "",
        "Ano": "",
        "Uri": "https://learn.microsoft.com/ja-jp/windows/terminal/panes",
        "Note": "",
        "tag": [
            "terminal"
        ]
    },
    {
        "App": "Windows Terminal",
        "Act": "Resize Pane",
        "Key": "Alt Shift Arrow",
        "Fn": "",
        "Esc": "",
        "Ano": "",
        "Uri": "https://learn.microsoft.com/ja-jp/windows/terminal/panes",
        "Note": "",
        "tag": [
            "terminal"
        ]
    },
    {
        "App": "Windows Terminal",
        "Act": "Close Pane",
        "Key": "Ctrl Shift W",
        "Fn": "",
        "Esc": "",
        "Ano": "",
        "Uri": "https://learn.microsoft.com/ja-jp/windows/terminal/panes",
        "Note": "",
        "tag": [
            "terminal"
        ]
    },
    {
        "App": "Windows Terminal",
        "Act": "Scroll by Row",
        "Key": "Ctrl Shift Arrow-Up|Down",
        "Fn": "",
        "Esc": "",
        "Ano": "",
        "Uri": "",
        "Note": "",
        "tag": [
            "terminal"
        ]
    },
    {
        "App": "Windows Terminal",
        "Act": "Scroll by Screen",
        "Key": "Ctrl Shift PgUp|PgDn",
        "Fn": "",
        "Esc": "",
        "Ano": "",
        "Uri": "",
        "Note": "",
        "tag": [
            "terminal"
        ]
    },
    {
        "App": "Microsoft Excel",
        "Act": "Full Screen",
        "Key": "Alt V U",
        "Fn": "",
        "Esc": "Esc",
        "Ano": "Ctrl Shift F1",
        "Uri": "",
        "Note": "",
        "tag": [
            "excel"
        ]
    },
    {
        "App": "Microsoft Powerpoint",
        "Act": "Full Screen",
        "Key": "Alt W D",
        "Fn": "F5",
        "Esc": "Esc",
        "Ano": "",
        "Uri": "",
        "Note": "",
        "tag": [
            "powerpoint"
        ]
    },
    {
        "App": "Microsoft Word",
        "Act": "Full Screen",
        "Key": "Alt V U",
        "Fn": "",
        "Esc": "Esc",
        "Ano": "",
        "Uri": "",
        "Note": "",
        "tag": [
            "word"
        ]
    }
]
"@
    $sObject = $sJson | ConvertFrom-Json
    return $sObject
}
