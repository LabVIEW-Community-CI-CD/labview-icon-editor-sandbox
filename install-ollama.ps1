# Installing Ollama CLI via PowerShell on Windows
# This script will download the installer and start it.
 = "https://ollama.com/download/OllamaSetup.exe"
 = Join-Path C:\Users\svelderr\AppData\Local\Temp "OllamaSetup.exe"
Write-Host "Downloading Ollama installer..." -ForegroundColor Cyan
Invoke-WebRequest -Uri  -OutFile 
Write-Host "Launching installer..." -ForegroundColor Cyan
Start-Process -FilePath  -Wait
Write-Host "Done. If prompted, reboot or restart shell to pick up PATH changes." -ForegroundColor Green
