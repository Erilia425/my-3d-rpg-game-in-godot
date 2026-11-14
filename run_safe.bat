@echo off
rem ============================================================
rem  SAFE TEST LAUNCHER  (made for play-testing on Intel UHD)
rem  Runs the game with the Compatibility renderer + OpenGL,
rem  a small 960x540 window, and a 30 FPS cap.
rem  The Godot editor's Play button cannot do this, so use THIS.
rem ============================================================
title Hollow_3D - SAFE TEST (Compatibility / OpenGL)
cd /d "C:\Users\summe\Documents\The Hollow\Hollow_3D"

echo Starting Hollow_3D with the Compatibility renderer...
echo If the game window does NOT appear, read the red/white text below.
echo.

"C:\Users\summe\Downloads\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe" --path "C:\Users\summe\Documents\The Hollow\Hollow_3D" --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 960x540 --windowed --max-fps 30

echo.
echo ============================================================
echo  Game closed (or failed to start).
echo  If it closed on its own, copy the text above and show it.
echo ============================================================
pause
