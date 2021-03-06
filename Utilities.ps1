Function Get-PowerShellEngine {

    [CmdletBinding()]
    Param([switch]$Detail)
    
    #get the current PowerShell process and the file that launched it
    $engine = Get-Process -id $pid | Get-Item
    if ($Detail) {
        [pscustomobject]@{
            Path           = $engine.Fullname
            FileVersion    = $engine.VersionInfo.FileVersion
            PSVersion      = $PSVersionTable.PSVersion.ToString()
            ProductVersion = $engine.VersionInfo.ProductVersion
            Edition        = $PSVersionTable.PSEdition
            Host           = $host.name
            Culture        = $host.CurrentCulture
            Platform       = $PSVersionTable.platform
        }
    }
    else {
        $engine.FullName
    }
}

Function Out-More {
    
    [cmdletbinding()]
    [alias("om")]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,
        [ValidateRange(1, 1000)]
        [Alias("i")]
        [int]$Count = 50,
        [Alias("cls")]
        [Switch]$ClearScreen
    )
    
    Begin {
        if ($ClearScreen) {
            Clear-Host
        }
        Write-Verbose "Starting: $($MyInvocation.Mycommand)"  
        Write-Verbose "Using a count of $count"
    
        #initialize an array to hold objects
        $data = @()
    
        #initialize some variables to control flow
        $ShowAll = $False
        $ShowNext = $False
        $Ready = $False
        $Quit = $False
    } #begin
    
    Process {
       
        if ($Quit) {
            Write-Verbose "Quitting"
            Break
        }
        elseif ($ShowAll) {
            $InputObject
        }
        elseif ($ShowNext) {
            Write-Verbose "Show Next"
            $ShowNext = $False
            $Ready = $True
            $data = , $InputObject
        }
        elseif ($data.count -lt $count) {
            Write-Verbose "Adding data"
            $data += $Inputobject
        }
        else {
            #write the data to the pipeline
            $data
            #reset data
            $data = , $InputObject
            $Ready = $True
        }
        
        If ($Ready) {   
            #pause
            Do {
                Write-Host "[M]ore [A]ll [N]ext [Q]uit " -ForegroundColor Green -NoNewline
                $r = Read-Host 
                if ($r.Length -eq 0 -OR $r -match "^m") {
                    #don't really do anything
                    $Asked = $True
                }
                else {
                    Switch -Regex ($r) {
            
                        "^n" {
                            $ShowNext = $True 
                            $InputObject 
                            $Asked = $True          
                        }
                        "^a" {
                            $InputObject
                            $Asked = $True
                            $ShowAll = $True
                        }
                        "^q" {
                            #bail out
                            $Asked = $True
                            $Quit = $True
                        }
                        Default {         
                            $Asked = $False
                        }
                    } #Switch
    
                } #else
            } Until ($Asked)
            
            $Ready = $False
            $Asked = $False
        } #else
    
    } #process
    
    End {
        #display whatever is left in $data
        if ($data -AND -Not $ShowAll) {
            Write-Verbose "Displaying remaining data"
            $data
        }
        Write-Verbose "Ending: $($MyInvocation.Mycommand)"
    } #end
    
} #end Out-More
    
Function Invoke-InputBox {
    
    [cmdletbinding(DefaultParameterSetName = "plain")]
    [alias("ibx")]
    [OutputType([system.string], ParameterSetName = 'plain')]
    [OutputType([system.security.securestring], ParameterSetName = 'secure')]
    
    Param(
        [Parameter(ParameterSetName = "secure")]
        [Parameter(HelpMessage = "Enter the title for the input box. No more than 25 characters.",
            ParameterSetName = "plain")]        
    
        [ValidateNotNullorEmpty()]
        [ValidateScript( {$_.length -le 25})]
        [string]$Title = "User Input",
    
        [Parameter(ParameterSetName = "secure")]        
        [Parameter(HelpMessage = "Enter a prompt. No more than 50 characters.", ParameterSetName = "plain")]
        [ValidateNotNullorEmpty()]
        [ValidateScript( {$_.length -le 50})]
        [string]$Prompt = "Please enter a value:",
            
        [Parameter(HelpMessage = "Use to mask the entry and return a secure string.",
            ParameterSetName = "secure")]
        [switch]$AsSecureString,
    
        [string]$BackgroundColor = "White"
    )
    
    if ($PSEdition -eq 'Core') {
        Write-Warning "Sorry. This command will not run on PowerShell Core."
        #bail out
        Return
    }
    
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    
    #remove the variable because it might get cached in the ISE or VS Code
    Remove-Variable -Name myInput -Scope script -ErrorAction SilentlyContinue
    
    $form = New-Object System.Windows.Window
    $stack = New-object System.Windows.Controls.StackPanel
    
    #define what it looks like
    $form.Title = $title
    $form.Height = 150
    $form.Width = 350
    
    $form.Background = $BackgroundColor
    
    $label = New-Object System.Windows.Controls.Label
    $label.Content = "    $Prompt"
    $label.HorizontalAlignment = "left"
    $stack.AddChild($label)
    
    if ($AsSecureString) {
        $inputbox = New-Object System.Windows.Controls.PasswordBox
    }
    else {
        $inputbox = New-Object System.Windows.Controls.TextBox
    }
    
    $inputbox.Width = 300
    $inputbox.HorizontalAlignment = "center"
    
    $stack.AddChild($inputbox)    
    
    $space = new-object System.Windows.Controls.Label
    $space.Height = 10
    $stack.AddChild($space)
    
    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "_OK"
    
    $btn.Width = 65
    $btn.HorizontalAlignment = "center"
    $btn.VerticalAlignment = "bottom"
    
    #add an event handler
    $btn.Add_click( {
            if ($AsSecureString) {
                $script:myInput = $inputbox.SecurePassword
            }
            else {
                $script:myInput = $inputbox.text
            }
            $form.Close()
        })
    
    $stack.AddChild($btn)
    $space2 = new-object System.Windows.Controls.Label
    $space2.Height = 10
    $stack.AddChild($space2)
    
    $btn2 = New-Object System.Windows.Controls.Button
    $btn2.Content = "_Cancel"
    
    $btn2.Width = 65
    $btn2.HorizontalAlignment = "center"
    $btn2.VerticalAlignment = "bottom"
    
    #add an event handler
    $btn2.Add_click( {
            $form.Close()
        })
    
    $stack.AddChild($btn2)
    
    #add the stack to the form
    $form.AddChild($stack)
    
    #show the form
    $inputbox.Focus() | Out-Null
    $form.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
    
    $form.ShowDialog() | out-null
    
    #write the result from the input box back to the pipeline
    $script:myInput
    
}
    
    