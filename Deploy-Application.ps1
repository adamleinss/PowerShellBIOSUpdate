<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK 
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}
	
	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = ''
	[string]$appName = ''
	[string]$appVersion = ''
	[string]$appArch = ''
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '01/8/2018'
	[string]$appScriptAuthor = 'Adam Leinss'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = 'Firmware Updates'
	[string]$installTitle = 'Firmware Updates'
	
	##* Do not modify section below
	#region DoNotModify
	
	## Variables: Exit Code
	[int32]$mainExitCode = 0
	
	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.6.9'
	[string]$deployAppScriptDate = '02/12/2017'
	[hashtable]$deployAppScriptParameters = $psBoundParameters
	
	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent
	
	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}
	
	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================
		
	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'
		
		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -PersistPrompt
		
		## Show Progress Message (with the default message)
		Show-InstallationProgress
		
		## <Perform Pre-Installation tasks here>
		
		
		##*===============================================
		##* INSTALLATION 
		##*===============================================
		[string]$installPhase = 'Installation'
		
		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}
		
		## <Perform Installation tasks here>

        $FirmwareUpdateRan = 'FALSE'
        $ComputerModel = (Get-WmiObject Win32_ComputerSystem).Model
        $BIOSVersion = (Get-WmiObject Win32_BIOS).Name
   

        ## Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 

        if (($ComputerModel -eq 'XPS 13 9350') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt '1.6.1'))
        

        { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps and connect to AC power' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
          if ($Response -eq 'Cancel') { exit 12345 }

          New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

          set-location $dirfiles\XPS13
          Suspend-BitLocker -MountPoint C: -RebootCount 1 -Confirm:$false
          start-process XPS_9350_1.6.1.exe -ArgumentList '/r /s /l="C:\windows\temp\9350_firmwareupdate.txt"' -Wait -PassThru
          $FirmwareUpdateRan = 'TRUE'

        } 
        
        ## Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 Dell XPS 13 9350 

        ## IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s 

        if (($ComputerModel -eq '20F90038US') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'N1CET63W (1.31 )'))

        { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps and connect to AC power' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
          if ($Response -eq 'Cancel') { exit 12345 }

          New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String
        
          Suspend-BitLocker -MountPoint C: -RebootCount 1 -Confirm:$false
          set-location $dirFiles\T460s
          start-process winuptp.exe -ArgumentList '-s' -Wait -PassThru
          $FirmwareUpdateRan = 'TRUE'

        } 	

          if (($ComputerModel -eq '20F90039US') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'N1CET63W (1.31 )'))

        { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps and connect to AC power' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
          if ($Response -eq 'Cancel') { exit 12345 }

          New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String
        
          Suspend-BitLocker -MountPoint C: -RebootCount 1 -Confirm:$false
          set-location $dirFiles\T460s
          start-process winuptp.exe -ArgumentList '-s' -Wait -PassThru
          $FirmwareUpdateRan = 'TRUE'

        } 	

         if (($ComputerModel -eq '20F90076US') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'N1CET63W (1.31 )'))

        { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps and connect to AC power' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
          if ($Response -eq 'Cancel') { exit 12345 }

          New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

          Suspend-BitLocker -MountPoint C: -RebootCount 1 -Confirm:$false
          set-location $dirFiles\T460s
          start-process winuptp.exe -ArgumentList '-s' -Wait -PassThru
          $FirmwareUpdateRan = 'TRUE'

        }

           if (($ComputerModel -eq '20F9004FUS') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'N1CET63W (1.31 )'))

        { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps and connect to AC power' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
          if ($Response -eq 'Cancel') { exit 12345 }

          New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String
        
          Suspend-BitLocker -MountPoint C: -RebootCount 1 -Confirm:$false
          set-location $dirFiles\T460s
          start-process winuptp.exe -ArgumentList '-s' -Wait -PassThru
          $FirmwareUpdateRan = 'TRUE'

        }

        ## IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s IBM T460s 


        ## IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900

             if (($ComputerModel -eq '10FM0026US') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FWKT86A'))

            { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
              if ($Response -eq 'Cancel') { exit 12345 }

              New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

              set-location $dirfiles\M900
              start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
              $FirmwareUpdateRan = 'TRUE'
            }

            if (($ComputerModel -eq '10FM001UUS') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FWKT86A'))

            { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
              if ($Response -eq 'Cancel') { exit 12345 }

              New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

              set-location $dirfiles\M900
              start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
              $FirmwareUpdateRan = 'TRUE'
            }

              if (($ComputerModel -eq '10FM000CUK') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FWKT86A'))

            { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
              if ($Response -eq 'Cancel') { exit 12345 }

              New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

              set-location $dirfiles\M900
              start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
              $FirmwareUpdateRan = 'TRUE'
            }

              if (($ComputerModel -eq '10FLCTO1WW') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FWKT86A'))

            { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
              if ($Response -eq 'Cancel') { exit 12345 }

              New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

              set-location $dirfiles\M900
              start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
              $FirmwareUpdateRan = 'TRUE'
            }

       ## IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 IBM M900 

       ## IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q 

       if (($ComputerModel -eq '10MR0047US') -and ($FirmwareUpdateRan -eq 'FALSE'))

            { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
              if ($Response -eq 'Cancel') { exit 12345 }

              New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

              set-location $dirFiles\M710Q
              start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
              $FirmwareUpdateRan = 'TRUE'
            }

       ## IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q IBM M710Q 

       ## IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P 

       if (($ComputerModel -eq '10AB0010US') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FBKTCPAUS'))

            { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
              if ($Response -eq 'Cancel') { exit 12345 }

              New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

              set-location $dirfiles\M93P
              start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
              $FirmwareUpdateRan = 'TRUE'
            }

             if (($ComputerModel -eq '10AAS0UFUS') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FBKTCPAUS'))

            { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
              if ($Response -eq 'Cancel') { exit 12345 }

              New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

              set-location $dirfiles\M93P
              start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
              $FirmwareUpdateRan = 'TRUE'
            }

              if (($ComputerModel -eq '10AB002VUS') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FBKTCPAUS'))

            { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
              if ($Response -eq 'Cancel') { exit 12345 }

              New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

              set-location $dirfiles\M93P
              start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
              $FirmwareUpdateRan = 'TRUE'
            }

              if (($ComputerModel -eq '10AB003CUK') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FBKTCPAUS'))

            { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
              if ($Response -eq 'Cancel') { exit 12345 }

              New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

              set-location $dirfiles\M93P
              start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
              $FirmwareUpdateRan = 'TRUE'
            }

             if (($ComputerModel -eq '10AB001') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FBKTCPAUS'))

            { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
              if ($Response -eq 'Cancel') { exit 12345 }

              New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

              set-location $dirfiles\M93P
              start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
              $FirmwareUpdateRan = 'TRUE'
            }

            if (($ComputerModel -eq '10AB000XUK') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FBKTCPAUS'))

            { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
              if ($Response -eq 'Cancel') { exit 12345 }

              New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

              set-location $dirfiles\M93P
              start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
              $FirmwareUpdateRan = 'TRUE'
            }

             if (($ComputerModel -eq '10AB000KUS') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FBKTCPAUS'))

            { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
              if ($Response -eq 'Cancel') { exit 12345 }

              New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

              set-location $dirfiles\M93P
              start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
              $FirmwareUpdateRan = 'TRUE'
            }

             if (($ComputerModel -eq '10AB000') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FBKTCPAUS'))

            { $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
              if ($Response -eq 'Cancel') { exit 12345 }

              New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

              set-location $dirfiles\M93P
              start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
              $FirmwareUpdateRan = 'TRUE'
            }
       ## IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P IBM M93P 

       
        ## S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1

        if (($ComputerModel -eq '20CD00AVUS') -and ($FirmwareUpdateRan -eq 'FALSE')  -and ($BIOSVersion -lt 'B0ET39WW (1.26 )'))
        

        { 
		  $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps and connect to AC power' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
          if ($Response -eq 'Cancel') { exit 12345 }
		  set-location $dirfiles\YogaS1
          Suspend-BitLocker -MountPoint C: -RebootCount 1 -Confirm:$false
          start-process winuptp.exe -ArgumentList '-s' -Wait -PassThru
          $FirmwareUpdateRan = 'TRUE'

        } 

        
        if (($ComputerModel -eq '20C0003TUK') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'B0ET39WW (1.26 )'))
        

        { 
          $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps and connect to AC power' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
          if ($Response -eq 'Cancel') { exit 12345 }

          New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

          set-location $dirfiles\YogaS1
          Suspend-BitLocker -MountPoint C: -RebootCount 1 -Confirm:$false
          start-process winuptp.exe -ArgumentList '-s' -Wait -PassThru
          $FirmwareUpdateRan = 'TRUE'

        } 
        
        ## S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1 Yoga S1


        ## E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 

          if (($ComputerModel -eq '30A1002UUS') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FBTCPAUS'))
        

        { 
          $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
          if ($Response -eq 'Cancel') { exit 12345 }

          New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

          set-location $dirfiles\E32
          start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
          $FirmwareUpdateRan = 'TRUE'

        } 

         ## E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 E32 

         ## P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 
         <#
         if (($ComputerModel -eq '30AH000YUS') -and ($FirmwareUpdateRan -eq 'FALSE'))
        

        { 
          $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
          if ($Response -eq 'Cancel') { exit 12345 }

          New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

          set-location $dirfiles\P300
          start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
          $FirmwareUpdateRan = 'TRUE'

        } 

       if (($ComputerModel -eq '30AH004MUS') -and ($FirmwareUpdateRan -eq 'FALSE'))
        

        { 
          $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
          if ($Response -eq 'Cancel') { exit 12345 }

          New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

          set-location $dirfiles\P300
          start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
          $FirmwareUpdateRan = 'TRUE'

        } 
        #>
         ## P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 P300 
        
        ## P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 
        
        if (($ComputerModel -eq '30AV000EUS') -and ($FirmwareUpdateRan -eq 'FALSE') -and ($BIOSVersion -lt 'FWKT87A'))
        

        { 
          $Response = Show-InstallationPrompt -Message 'Executing BIOS update...please close all apps' -ButtonRightText 'Cancel' -ButtonLeftText 'Continue' -Timeout 600
          if ($Response -eq 'Cancel') { exit 12345 }

          New-Item -Path HKLM:SOFTWARE -Name ACMEDesktop -Force
              Set-ItemProperty -Path HKLM:SOFTWARE\ACMEDesktop -Name MeltdownFirmwareFix -Value "Yes" -Type String

          set-location $dirfiles\P310
          start-process flash.cmd -ArgumentList '/quiet' -Wait -PassThru
          $FirmwareUpdateRan = 'TRUE'

        } 

        ## P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 P310 
        	
		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'
		
		## <Perform Post-Installation tasks here>

        ## Force reboot after 10 minutes

        if ($FirmwareUpdateRan -eq 'TRUE')

        {

        Show-InstallationRestartPrompt -Countdownseconds 600 -CountdownNoHideSeconds 60

		}

		## Display a message at the end of the install
		## If (-not $useDefaultMsi) { Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait }
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'
		
		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60
		
		## Show Progress Message (with the default message)
		## Show-InstallationProgress
		
		## <Perform Pre-Uninstallation tasks here>
		
		
		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'
		
		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		
		# <Perform Uninstallation tasks here>
		
		
		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'
		
		## <Perform Post-Uninstallation tasks here>
		
		
	}
	
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================
	
	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}