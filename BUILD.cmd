@echo off
title RbxGenie Build Plugin
cd /d "%~dp0"
echo [RbxGenie] Bundling plugin...
node scripts/bundle.js
if errorlevel 1 (
    echo [RbxGenie] Build FAILED.
    pause
    exit /b 1
)
echo.
echo [RbxGenie] Copying to Roblox Plugins folder...
copy /y "dist\RbxGenie.plugin.lua" "%LOCALAPPDATA%\Roblox\Plugins\RbxGenie.lua"
if errorlevel 1 (
    echo [RbxGenie] Copy FAILED - check Plugins folder path.
    pause
    exit /b 1
)
echo.
echo [RbxGenie] Done! Restart Roblox Studio to load the updated plugin.
pause
