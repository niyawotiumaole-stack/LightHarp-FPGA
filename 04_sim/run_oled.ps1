param([string]$VivadoBin='D:/XILINX/Vivado/2018.3/bin',[switch]$Staged)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if(!$Staged){
 $stage='D:/codex/oled_sim_'+[guid]::NewGuid().ToString('N')
 New-Item -ItemType Directory -Path $stage | Out-Null
 Copy-Item -LiteralPath ($root+'/01_RTL'),($root+'/03_projects'),($root+'/04_sim') -Destination $stage -Recurse
 & ($stage+'/04_sim/run_oled.ps1') -VivadoBin $VivadoBin -Staged
 Copy-Item ($stage+'/04_sim/*.log'),($stage+'/04_sim/oled_frames.hex') -Destination $PSScriptRoot -Force
 return
}
Push-Location $PSScriptRoot
try{
$src=@(Get-ChildItem ($root+'/01_RTL') -Filter *.v | ForEach-Object FullName)
foreach($test in @('tb_oled','tb_oled_audio')){
 & ($VivadoBin+'/xvlog.bat') -sv @src ../03_projects/harp8oled/harp8oled.v harp_core_base.v ($test+'.sv') *> ($test+'.compile.log')
 if($LASTEXITCODE -ne 0){throw "compile $test"}
 & ($VivadoBin+'/xelab.bat') $test -s $test --O2 *> ($test+'.elaborate.log')
 if($LASTEXITCODE -ne 0){throw "elaborate $test"}
 & ($VivadoBin+'/xsim.bat') $test -runall *> ($test+'.run.log')
 if($LASTEXITCODE -ne 0 -or !(Select-String ($test+'.run.log') -Pattern 'PASS ' -Quiet) -or (Select-String ($test+'.run.log') -Pattern 'Fatal:|FAIL ' -Quiet)){throw "simulation $test"}
 "PASS $test"
}
}finally{Pop-Location}
