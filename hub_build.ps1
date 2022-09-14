[CmdletBinding()]
Param(
    [ValidateSet('','MakeVSCache','MakeCefSrcArtifact','RestoreVSCache', 'RestoreCefSrcArtifact', 'CefBuild')]
	[string] $Special="",
	[Switch] $NoSpaceFreeIfNeeded

)
Set-StrictMode -version latest;
Install-Module -Name Use-RawPipeline -Scope CurrentUser -AcceptLicense -AllowPrerelease -SkipPublisherCheck -Force;
Function WriteException2($exp){

	write-host "Caught an exception in hub:" -ForegroundColor Yellow -NoNewline
	write-host " $($exp.Exception.Message)" -ForegroundColor Red
	write-host "`tException Type: $($exp.Exception.GetType().FullName)"
	$stack = $exp.ScriptStackTrace;
	$stack = $stack.replace("`n","`n`t")
	write-host "`tStack Trace: $stack"
	if ($exp.Exception.InnerException){
		write-host "`tInnerException:" -ForegroundColor Yellow -NoNewline
		write-host " $($exp.Exception.InnerException.Message)" -ForegroundColor Red
	}
}
function StatusPrint {
			$os = Get-Ciminstance Win32_OperatingSystem;
			$physFree = $os.FreePhysicalMemory/1mb;
			$pageFree = $os.FreeSpaceInPagingFiles/1mb;
			$space = Get-Volume |  Format-Wide   {$_.DriveLetter +": " + ($_.SizeRemaining/1gb).ToString("0.0").PadLeft(5) + "/" + ($_.Size/1gb).ToString("0.0 gb").PadLeft(8)} -AutoSize | Out-String
			Write-Host -ForegroundColor Yellow Physical Free Memory: $physFree.ToString("0.0") gb Page: $pageFree.ToString("0.0") gb disk free space: $space.Trim()
}

$ErrorActionPreference = "Stop";
$ORIGINAL_WORKING_DIR = Get-Location;
$WorkingDir = split-path -parent $MyInvocation.MyCommand.Definition;
$CefDockerDir = Join-Path $WorkingDir "../CefSharpDockerfiles"

try{
	Copy (Join-Path $WorkingDir "our_functions.ps1") (Join-Path $CefDockerDir "functions.ps1")
	. (Join-Path $CefDockerDir 'functions.ps1')



	




	
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

	if (! [System.IO.File]::Exists("c:\pagefile.sys") ){ #test path ignores system files hahaha
		Write-Host Updating Page Files shrinking main partition to add a second page file to drive
		Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{name="c:\pagefile.sys";InitialSize = 10240; MaximumSize = 28672;} -EnableAllPrivileges
		systeminfo
	}

	#Get-WmiObject Win32_pagefilesetting



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

	$ToDelete = @("C:/Program Files/Microsoft Visual Studio", "C:/Program Files (x86)/Android", "C:/Program Files (x86)/Windows Kits", "C:/Program Files (x86)/Microsoft SDKs", "C:/Microsoft/AndroidNDK", "C:/Windows/Installer","C:/tools","C:/Program Files/LLVM");
	$ToDeleteImages = @("mcr.microsoft.com/dotnet/framework/aspnet", "mcr.microsoft.com/dotnet/framework/runtime","mcr.microsoft.com/dotnet/framework/sdk");
	if ($NoSpaceFreeIfNeeded -eq $false -and ($Special -eq "RestoreCefSrcArtifact" -or $Special -eq "CefBuild" -or $Special -eq "MakeCefSrcArtifact") ){
		TimerNow("Starting");
		Write-Host Freeing up space....
		$ToDelete | foreach { Write-Host Erasing $_; Remove-Item -Recurse -Force $_; }
		TimerNow("Freeing up Folder Space");
		$ToDeleteImages | foreach { docker rmi $_; }
		StatusPrint
		Write-Host Space Feed
	}

	#systeminfo
	#StatusPrint
	New-Item -ItemType Directory -Force -Path c:/temp/cache
	New-Item -ItemType Directory -Force -Path c:/temp/artifacts
	if ($Special -eq "RestoreVSCache") {
		Set-Location "c:/temp/cache/"
		if (! (Test-Path -Path "zstd.exe" -PathType Leaf) ) {
			#libarchive
			Invoke-WebRequest 'https://page.ghfs.workers.dev/archive.dll' -OutFile 'archive.dll';
			Invoke-WebRequest 'https://page.ghfs.workers.dev/bsdtar.exe' -OutFile 'bsdtar.exe';
			Invoke-WebRequest 'https://page.ghfs.workers.dev/zstd.exe' -OutFile 'zstd.exe';
			TimerNow("Fetch libarchive items");

		}

		$tSize = ((Get-Item "c:/temp/cache/vs.tar.zstd").length/1GB).ToString("0.0 GB")
		Write-Host "The docker file size is: $tSize"
		
		dir
		#for some reason just using the absolute path does not work
		#hrm it will load bz2 xz or gzip files our_automate-git
		#.\zstd.exe -d vs.tar.zstd -o c:/temp/vs.tar
		#docker load -i c:/temp/vs.tar
		Invoke-NativeCommand -FilePath ".\zstd.exe" -ArgumentList @("-d", "vs.tar.zstd", "--stdout") | run docker load | 2ps
		rm "vs.tar.zstd"
		Set-Location $CefDockerDir
		docker images
		TimerNow("Loaded vs into docker");
		#cp /c/ProgramData/docker/volumes/cefbuild_rnnda/_data
		exit 0;
	}
	if ($Special -eq "MakeVSCache") {
		& "$CefDockerDir\build.ps1" -NoMemoryWarn -Verbose -Special MakeVSCache
		exit 0;
	}

	if ($Special -eq "MakeCefSrcArtifact"){
		& "$CefDockerDir\build.ps1" -NoMemoryWarn -Verbose -Special MakeCefSrcArtifact
		exit 0;
	}
	& "$CefDockerDir\build.ps1" -NoMemoryWarn -Verbose -Special CefBuild
	#Move "c:/temp/src.tar.zstd" "c:/temp/artifacts"
	dir "c:/temp/artifacts"

	

	Write-Host -ForegroundColor Green Build completed successfully of test checkout!
}catch{
	WriteException2 $_;
	StatusPrint;
	Set-Location $ORIGINAL_WORKING_DIR;
	exit 1;
}
Set-Location $ORIGINAL_WORKING_DIR;


#wmic pagefileset list /format:list
#wmic pagefileset where name="C:\\pagefile.sys" set InitialSize=2048,MaximumSize=2048

#there is a system managed D one and no C one so lets add em



Get-Partition -DriveLetter C


