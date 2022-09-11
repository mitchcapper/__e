[CmdletBinding()]
Param(
	[Switch] $VSCache,
	[Switch] $Passthru,
	[Switch] $NoFreeupSpace

)
Set-StrictMode -version latest;
Install-Module -Name Use-RawPipeline -Scope CurrentUser -AcceptLicense -AllowPrerelease -SkipPublisherCheck -Force;



$ErrorActionPreference = "Stop";
$ORIGINAL_WORKING_DIR = Get-Location;
$WorkingDir = split-path -parent $MyInvocation.MyCommand.Definition;
$CefDockerDir = Join-Path $WorkingDir "../CefSharpDockerfiles"

try{
	. (Join-Path $CefDockerDir 'functions.ps1')



	

function StatusPrint {
			$os = Get-Ciminstance Win32_OperatingSystem;
			$physFree = $os.FreePhysicalMemory/1mb;
			$pageFree = $os.FreeSpaceInPagingFiles/1mb;
			$space = Get-Volume |  Format-Wide   {$_.DriveLetter +": " + ($_.SizeRemaining/1gb).ToString("0.0").PadLeft(5) + "/" + ($_.Size/1gb).ToString("0.0 gb").PadLeft(8)} -AutoSize | Out-String
			Write-Host -ForegroundColor Yellow Physical Free Memory: $physFree.ToString("0.0") gb Page: $pageFree.ToString("0.0") gb disk free space: $space.Trim()
}


	Write-Host Updating Page Files shrinking main partition to add a second page file to drive
	#Resize-Partition -DriveLetter C -Size 220GB
	#New-Partition -DiskNumber 0 -UseMaximumSize -DriveLetter S
	#Format-Volume -DriveLetter S	
	#$pagefile = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
	#$pagefile.AutomaticManagedPagefile = $false
	#$pagefile.Put()
	#$pagefileset = Get-WmiObject Win32_pagefilesetting
	#$pagefileset.InitialSize = 20480
	#$pagefileset.MaximumSize = 40480
	#$pagefileset.Put()

	#Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{name="d:\pagefile.sys";InitialSize = 8192; MaximumSize = 10240;} -EnableAllPrivileges
	#Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{name="s:\pagefile.sys";InitialSize = 18432; MaximumSize = 28672;} -EnableAllPrivileges
	Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{name="c:\pagefile.sys";InitialSize = 28672; MaximumSize = 38912;} -EnableAllPrivileges


	Get-WmiObject Win32_pagefilesetting



	Set-Location $CefDockerDir
	Copy (Join-Path $WorkingDir "our_versions.ps1") "versions.ps1"
	Copy (Join-Path $WorkingDir "our_Dockerfile_vs") "Dockerfile_vs"
	Copy (Join-Path $WorkingDir "our_cef_build.ps1") "cef_build.ps1"
	Copy (Join-Path $WorkingDir "our_build.ps1") "build.ps1"
	Copy (Join-Path $WorkingDir "our_Dockerfile_cef") "Dockerfile_cef"
	Copy (Join-Path $WorkingDir "our_automate-git.py") "automate-git.py"
	
	
	git config --global core.packedGitLimit  128m
	git config --global core.packedGitWindowSize  128m
	git config --global pack.deltaCacheSize  128m
	git config --global pack.packSizeLimit  128m
	git config --global pack.windowMemory  128m	
	git config --global http.postbuffer  128m	
	#git config --global pack.threads 2

	# frees up a good bit of spce on the c drive where docker runs
	TimerNow("Starting");
	Write-Host Freeing up space....
	$ToDelete = @("C:/Program Files/Microsoft Visual Studio", "C:/Program Files (x86)/Android", "C:/Program Files (x86)/Windows Kits", "C:/Program Files (x86)/Microsoft SDKs", "C:/Microsoft/AndroidNDK")
	if (! $NoFreeupSpace){
		$ToDelete | foreach { Write-Host Erasing $_; Remove-Item -Recurse -Force $_; }
	}
	TimerNow("Freeing up Space");
	Write-Host Space Feed
	systeminfo
	StatusPrint
	New-Item -ItemType Directory -Force -Path c:/temp/artifacts
	if ($VSCache) {
		if (! (Test-Path -Path "zstd.exe" -PathType Leaf) ) {
			#libarchive
			Invoke-WebRequest 'https://page.ghfs.workers.dev/archive.dll' -OutFile 'archive.dll';
			Invoke-WebRequest 'https://page.ghfs.workers.dev/bsdtar.exe' -OutFile 'bsdtar.exe';
			Invoke-WebRequest 'https://page.ghfs.workers.dev/zstd.exe' -OutFile 'zstd.exe';
			TimerNow("Fetch libarchive items");

		}

		$tSize = ((Get-Item "c:/temp/artifacts/vs.tar.zstd").length/1GB).ToString("0.0 GB")
		Write-Host "The docker file size is: $tSize"
		Set-Location "c:/temp/artifacts/"
		dir		
		#for some reason just using the absolute path does not work
		#hrm it will load bz2 xz or gzip files our_automate-git
		run .\zstd.exe -d vs.tar.zstd -o d:/vs.tar
		docker load -i d:/vs.tar
		#run .\zstd.exe -d vs.tar.zstd | docker load | 2ps
		Set-Location $CefDockerDir
		TimerNow("Loaded vs into docker");
		#throw "WTF"
		& "$CefDockerDir\build.ps1" -NoMemoryWarn -Verbose -JustToCEFSource
	} else {
		& "$CefDockerDir\build.ps1" -NoMemoryWarn -Verbose -JustToVSCache
		Copy "c:/temp/vs.tar.zstd" "c:/temp/artifacts"
	}
	

	Write-Host -ForegroundColor Green Build completed successfully of test checkout!
}catch{
	WriteException $_;
	StatusPrint;
	Set-Location $ORIGINAL_WORKING_DIR;
	throw $_;
}
Set-Location $ORIGINAL_WORKING_DIR;


#wmic pagefileset list /format:list
#wmic pagefileset where name="C:\\pagefile.sys" set InitialSize=2048,MaximumSize=2048

#there is a system managed D one and no C one so lets add em



Get-Partition -DriveLetter C


