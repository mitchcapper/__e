Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";
$ORIGINAL_WORKING_DIR = Get-Location;
$WorkingDir = split-path -parent $MyInvocation.MyCommand.Definition;
$CefDockerDir = Join-Path $WorkingDir "../CefSharpDockerfiles"

try{
	. (Join-Path $CefDockerDir 'functions.ps1')


	git config --global pack.windowMemory 512m

	$MonitorJob = Start-Job -ScriptBlock {
		while ( $true ) {
			Start-Sleep 120;
			$os = Get-Ciminstance Win32_OperatingSystem;
			$physFree = $os.FreePhysicalMemory/1mb;
			$pageFree = $os.FreeSpaceInPagingFiles/1mb;
			$space = Get-Volume |  Format-Wide   {$_.DriveLetter +": " + ($_.SizeRemaining/1gb).ToString("0.0").PadLeft(5) + "/" + ($_.Size/1gb).ToString("0.0 gb").PadLeft(8)} -AutoSize | Out-String
			Write-Host -ForegroundColor Yellow Physical Free Memory: $physFree.ToString("0.0") gb Page: $pageFree.ToString("0.0") gb disk usage: $space.Trim()
		}
	}


	Write-Host Updating Page Files
	$pagefile = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
	$pagefile.AutomaticManagedPagefile = $false
	$pagefile.Put()
	$pagefileset = Get-WmiObject Win32_pagefilesetting
	$pagefileset.InitialSize = 2048
	$pagefileset.MaximumSize = 10240
	$pagefileset.Put()

	Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{name="c:\pagefile.sys";InitialSize = 5096; MaximumSize = 20480;} -EnableAllPrivileges
	Get-WmiObject Win32_pagefilesetting



	Set-Location $CefDockerDir
	Copy (Join-Path $WorkingDir "our_versions.ps1") "versions.ps1"
	Copy (Join-Path $WorkingDir "our_Dockerfile_vs") "Dockerfile_vs"

	#frees up a good bit of spce on the c drive where docker runs
	Write-Host Freeing up space....
	$ToDelete = @("C:/Program Files/Microsoft Visual Studio", "C:/Program Files (x86)/Android", "C:/Program Files (x86)/Windows Kits", "C:/Program Files (x86)/Microsoft SDKs", "C:/Microsoft/AndroidNDK")
	$ToDelete | foreach { Write-Host Erasing $_; Remove-Item -Recurse -Force $_; }
	Write-Host Space Feed


	& "$CefDockerDir\build.ps1" -NoMemoryWarn -Verbose

	Write-Host -ForegroundColor Green Build completed successfully of test checkout!
}catch{
	WriteException $_;
	Set-Location $ORIGINAL_WORKING_DIR;
	Stop-Job $MonitorJob	
	throw $_;
}
Set-Location $ORIGINAL_WORKING_DIR;
Stop-Job $MonitorJob


#wmic pagefileset list /format:list
#wmic pagefileset where name="C:\\pagefile.sys" set InitialSize=2048,MaximumSize=2048

#there is a system managed D one and no C one so lets add em
