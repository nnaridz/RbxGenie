@echo off
title RbxGenie Build
cd /d "%~dp0"

echo [RbxGenie] Step 1: Bundling plugin...
node scripts/bundle.js
if errorlevel 1 (
    echo [RbxGenie] Plugin build FAILED.
    pause
    exit /b 1
)
echo.

echo [RbxGenie] Step 2: Copying plugin to Roblox Plugins folder...
copy /y "dist\RbxGenie.plugin.lua" "%LOCALAPPDATA%\Roblox\Plugins\RbxGenie.lua"
if errorlevel 1 (
    echo [RbxGenie] Copy FAILED - check Plugins folder path.
    pause
    exit /b 1
)
echo.

echo [RbxGenie] Step 3: Compiling TypeScript...
call npx tsc --outDir .build
if errorlevel 1 (
    echo [RbxGenie] TypeScript compilation FAILED.
    pause
    exit /b 1
)
echo.

echo [RbxGenie] Step 4: Packaging daemon to EXE...
call npx @yao-pkg/pkg .build/server.js --targets node18-win-x64 --output dist/RbxGenie.exe --compress GZip
if errorlevel 1 (
    echo [RbxGenie] EXE packaging FAILED.
    rd /s /q .build 2>nul
    pause
    exit /b 1
)
rd /s /q .build 2>nul
echo.

echo [RbxGenie] Done!
echo   dist\RbxGenie.plugin.lua  (Roblox plugin)
echo   dist\RbxGenie.exe         (Daemon)
pause
