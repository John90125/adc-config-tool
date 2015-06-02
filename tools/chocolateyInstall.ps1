 $arguments = @{}   
 $PackageParameters = $env:chocolateyPackageParameters
 
if(![string]::IsNullOrWhiteSpace($PackageParameters)){
    if ($PackageParameters.Split('[/:]',$option).Count % 2 -ne 0){
         throw 'Invalid parameters'
    }

    
    $option = [System.StringSplitOptions]::RemoveEmptyEntries

    for ($i=0;$i -lt  $PackageParameters.Split('[/:]',$option).Count; $i++) {
          $arguments.Add($PackageParameters.Split('[/:]',$option)[$i], $PackageParameters.Split('[/:]',$option)[++$i])
    }    
}
$serverName = $arguments.Get_Item("Server") 

if([string]::IsNullOrWhiteSpace($serverName)){
    $serverName = $env:COMPUTERNAME + "_NT"
}elseif(!$serverName.EndsWith("NT")){
    $serverName = $serverName + "_NT"
}

$packageName = 'ADC_Config_Tool' 
$installerType = 'exe'
$url = 'http://ic-nexus.cloudapp.net/nexus/content/repositories/VersioCloud/'
$version = 'ADC/ADC_Config_Tool/12.23.36.0M/'
$url64 = $url
$validExitCodes = @(0)
$scriptPath = $(Split-Path $MyInvocation.MyCommand.Path)

# Create temp chocolatey dir in  %userprofile%\AppData\Local\Temp\chocolatey\ADC_Config
$chocTempDir = Join-Path $env:TEMP "chocolatey"   # add chocolatey dir
$tempDir = Join-Path $chocTempDir "$packageName"  # add package dir 
# create if it doesn't already exist
if (![System.IO.Directory]::Exists($tempDir)) { [System.IO.Directory]::CreateDirectory($tempDir) | Out-Null }


# Initial installer location variables
$fileSetupExe = Join-Path $tempDir "ADC_Config_Tool-setup.exe"
$setupExe = $url+$version+'ADC_Config_Tool-12.23.36.0M-setup.exe'
$fileInstallResponse = Join-Path $tempDir "ADC_Config_Tool-12.23.36.0M-install_response.iss"
$installResponseIss = $url+$version+'ADC_Config_Tool-12.23.36.0M-install_response.iss'
$fileUninstallResponse = Join-Path $tempDir "ADC_Config_Tool-uninstall_response.iss"
$uninstallResponseIss = $url+$version+'ADC_Config_Tool-12.23.36.0M-uninstall_response.iss'

# Get Common Powershell script
$fileCommonFnc = Join-Path $tempDir "CommonFnc.ps1"
$urlPS1 = $url+'psScripts/common/1.0/common-1.0-commonFunctions.ps1'
Get-WebFile $urlPS1 $fileCommonFnc

# Put Powershell script into memory
.$fileCommonFnc

# Check for previous installation and uninstall if found 
 if ((Test-Path $fileUninstallResponse) -and (isAppInstalled -DisplayName 'ADC Config Tool')){       
        $silentUninstall = '/s /uninst /f1' + $fileUninstallResponse       
        Try{
                Uninstall-ChocolateyPackage "$packageName" "$installerType" "$silentUninstall" "$fileSetupExe"  -validExitCodes $validExitCodes
           } catch {   
               throw $_.Exception.Message
           }
 }elseif (isAppInstalled -DisplayName 'ADC Config Tool') {
    throw 'Cannot find uninstall script.'
 }
 
# clear out dir and add updates 
Remove-Item $tempDir'\*.*'

# Download updated setup app and scripts
Get-WebFile $SetupExe  $fileSetupExe
Get-WebFile $installResponseIss  $fileInstallResponse
Get-WebFile $uninstallResponseIss  $fileUninstallResponse

# set up silent install parameters
$silentInstall = '/s /f1' + $fileInstallResponse

# Update Response file
(gc $fileInstallResponse).replace("szClientName=NTCONFIG_NT","szClientName=" + $serverName ) | sc $fileInstallResponse
(gc $fileInstallResponse).replace("szPassword=Imagine01","szPassword=imagine") | sc $fileInstallResponse

# Install app
Try{
     Install-ChocolateyInstallPackage "$packageName" "$installerType" "$silentInstall" "$fileSetupExe" -validExitCodes $validExitCodes 
} catch {
    throw $_.Exception.Message
}