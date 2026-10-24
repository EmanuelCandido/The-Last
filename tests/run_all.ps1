# Roda os roteiros de tests/ (--run) um por um e diz quais passaram.
#
#   powershell -ExecutionPolicy Bypass -File tests\run_all.ps1            # todos
#   powershell -ExecutionPolicy Bypass -File tests\run_all.ps1 -Only f8   # só os que contêm "f8"
#
# Os roteiros salvam de verdade (dormir, Reciclagem, finais): antes de começar, os arquivos do
# jogador em %APPDATA%\Godot\app_userdata\Jogo Pessoal vão para um backup e, no fim (mesmo com
# erro), voltam como estavam. Cada roteiro termina com "[T] FIM: TUDO OK" ou "N FALHA(S)"; um
# roteiro passa se imprimir TUDO OK e não tiver SCRIPT ERROR, Parse Error nem ERROR: na saída.
# A saída de cada um fica em %TEMP%\toca_tests\<nome>.log.

param(
	[string]$Only = "",
	# Limite por roteiro (s): um roteiro preso não segura os outros.
	[int]$Timeout = 300,
	[string]$Godot = "C:\Users\emano\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
)

# "Continue": no PowerShell 5.1, o stderr do Godot (avisos) com 2>&1 vira erro e pararia tudo.
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$project = Split-Path -Parent $PSScriptRoot
$data = Join-Path $env:APPDATA "Godot\app_userdata\Jogo Pessoal"
$logs = Join-Path $env:TEMP "toca_tests"
$backup = Join-Path $env:TEMP ("toca_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
# Tudo o que o jogo escreve fora do projeto e um roteiro pode criar, mudar ou apagar.
$userFiles = @("save.json", "settings.cfg", "toca.cfg", "ciclo_346.sav", "leia_me_se_lembrar.txt")
$userDirs = @("playtest")

# Nome, arquivo e argumentos de cada caso. O f8 roda um final por vez.
$cases = @(
	@{ Name = "f1"; File = "test_f1.gd"; Args = @() },
	@{ Name = "f2"; File = "test_f2.gd"; Args = @() },
	@{ Name = "f3"; File = "test_f3.gd"; Args = @() },
	@{ Name = "f4"; File = "test_f4.gd"; Args = @() },
	@{ Name = "f5"; File = "test_f5.gd"; Args = @() },
	@{ Name = "f6"; File = "test_f6.gd"; Args = @() },
	@{ Name = "f7"; File = "test_f7.gd"; Args = @() },
	@{ Name = "f8-stay"; File = "test_f8.gd"; Args = @("--case=stay") },
	@{ Name = "f8-wake"; File = "test_f8.gd"; Args = @("--case=wake") },
	@{ Name = "f8-swap"; File = "test_f8.gd"; Args = @("--case=swap") },
	@{ Name = "f8-welcome"; File = "test_f8.gd"; Args = @("--case=welcome") },
	@{ Name = "f8-menu"; File = "test_f8.gd"; Args = @("--case=menu") },
	@{ Name = "f9"; File = "test_f9.gd"; Args = @() },
	@{ Name = "life"; File = "test_life.gd"; Args = @() }
)
# Roteiros novos entram sozinhos: qualquer test_*.gd que não esteja na lista acima.
$listed = $cases | ForEach-Object { $_.File }
Get-ChildItem (Join-Path $PSScriptRoot "test_*.gd") | Where-Object { $listed -notcontains $_.Name } | ForEach-Object {
	$cases += @{ Name = $_.BaseName -replace "^test_", ""; File = $_.Name; Args = @() }
}
if ($Only -ne "") {
	$cases = $cases | Where-Object { $_.Name -like "*$Only*" }
}

# Linhas de erro que não são falha: som tocando quando o teste fecha.
$ignored = "resources still in use|ObjectDB instances leaked|RID allocations"

New-Item -ItemType Directory -Force $logs | Out-Null
New-Item -ItemType Directory -Force $backup | Out-Null
foreach ($file in $userFiles) {
	$path = Join-Path $data $file
	if (Test-Path $path) { Copy-Item $path (Join-Path $backup $file) }
}
foreach ($dir in $userDirs) {
	$path = Join-Path $data $dir
	if (Test-Path $path) { Copy-Item $path (Join-Path $backup $dir) -Recurse }
}

$results = @()
try {
	foreach ($case in $cases) {
		# Cada roteiro começa sem save nem arquivos de história.
		foreach ($file in $userFiles) {
			$path = Join-Path $data $file
			if (Test-Path $path) { Remove-Item $path -Force }
		}
		$script = (Join-Path $PSScriptRoot $case.File) -replace "\\", "/"
		$arguments = @("--headless", "--path", $project, "--fixed-fps", "60", "--", "--frames=5", "--skip-intro", "--run=$script") + $case.Args
		$started = Get-Date
		$log = Join-Path $logs ($case.Name + ".log")
		$errLog = Join-Path $logs ($case.Name + ".err.log")
		# A saída vai direto para o arquivo (dá para acompanhar enquanto roda).
		$quoted = $arguments | ForEach-Object { if ($_ -match " ") { '"' + $_ + '"' } else { $_ } }
		$process = Start-Process -FilePath $Godot -ArgumentList $quoted -NoNewWindow -PassThru `
			-RedirectStandardOutput $log -RedirectStandardError $errLog
		$timedOut = -not $process.WaitForExit($Timeout * 1000)
		if ($timedOut) {
			# O console do Godot abre o jogo num processo filho: derruba a árvore toda.
			& taskkill /PID $process.Id /T /F | Out-Null
		}
		$seconds = ((Get-Date) - $started).TotalSeconds
		$output = @(Get-Content $log -Encoding utf8) + @(Get-Content $errLog -Encoding utf8)
		if ($timedOut) { $output += "ERROR: passou de $Timeout s e foi encerrado" }
		$errors = @($output | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|^ERROR:" -and $_ -notmatch $ignored })
		$failed = @($output | Where-Object { $_ -match "^\[T\] FALHOU" })
		$passed = ($output -match "\[T\] FIM: TUDO OK").Count -gt 0 -and $errors.Count -eq 0
		$results += [pscustomobject]@{
			Roteiro = $case.Name
			Resultado = if ($passed) { "ok" } else { "FALHOU" }
			Segundos = [math]::Round($seconds)
			Detalhe = if ($passed) { "" } elseif ($errors.Count -gt 0) { $errors[0] } elseif ($failed.Count -gt 0) { $failed[0] } else { "sem [T] FIM" }
		}
		Write-Host ("{0,-12} {1,-7} {2,4}s  {3}" -f $case.Name, $results[-1].Resultado, $results[-1].Segundos, $results[-1].Detalhe)
	}
}
finally {
	# Devolve os arquivos do jogador como estavam antes.
	foreach ($file in $userFiles) {
		$path = Join-Path $data $file
		if (Test-Path $path) { Remove-Item $path -Force }
		$saved = Join-Path $backup $file
		if (Test-Path $saved) { Copy-Item $saved $path }
	}
	foreach ($dir in $userDirs) {
		$path = Join-Path $data $dir
		$saved = Join-Path $backup $dir
		if (Test-Path $saved) {
			if (Test-Path $path) { Remove-Item $path -Recurse -Force }
			Copy-Item $saved $path -Recurse
		}
	}
	Remove-Item $backup -Recurse -Force
}

$bad = @($results | Where-Object { $_.Resultado -ne "ok" })
Write-Host ""
Write-Host ("{0} de {1} roteiros passaram. Saídas em {2}" -f ($results.Count - $bad.Count), $results.Count, $logs)
if ($bad.Count -gt 0) { exit 1 }
