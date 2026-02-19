@echo off
title RbxGenie Daemon
cd /d "%~dp0"
echo [RbxGenie] Starting daemon on http://127.0.0.1:7766 ...
npm run dev
pause
