@echo off

TASKLIST /fi "WINDOWTITLE eq AFCServer" | FINDSTR "love"
IF ERRORLEVEL 1 START love ./networking/server

START love .