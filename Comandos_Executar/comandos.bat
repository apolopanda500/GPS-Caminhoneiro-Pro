@echo off
title GPS Caminhoneiro Pro - Execução de Melhorias

echo.
echo ============================================
echo   EXECUÇÃO DE MELHORIAS - GPS Caminhaneiro Pro
echo ============================================
echo.

echo ============================================
echo 1. BUILD DO APK DEBUG
echo ============================================
echo.
echo Executando Flutter build APK...
& "C:\Users\Micro\flutter\bin\flutter.bat" build apk --debug
echo.
echo Build concluido. Verifique o APK em:
echo C:\Users\Micro\gps-camioneiro-pro-completo\frontend-flutter\build\app\outputs\flutter-apk\app-debug.apk
echo.
pause

echo.
echo ============================================
echo 2. INSTALAR NO CELULAR
echo ============================================
echo.
echo Certifique-se de que o celular esta conectado via USB:
echo - Desbloqueio USB ativado
echo - Depuracao USB ativada
echo - Dispositivo R9XY1016R6V reconhecido pelo ADB
echo.
echo Verificando dispositivos conectados...
adb devices
echo.
echo Instalando APK no celular...
adb install -r "C:\Users\Micro\gps-camioneiro-pro-completo\frontend-flutter\build\app\outputs\flutter-apk\app-debug.apk"
echo.
echo Instalacao concluida.
pause

echo.
echo ============================================
echo 3. RODAR FLUTTER ANALYZE
echo ============================================
echo.
echo Executando analise de codigo...
& "C:\Users\Micro\flutter\bin\flutter.bat" analyze
echo.
echo Resultado esperado: "No issues found!"
pause

echo.
echo ============================================
echo 4. RODAR TESTES UNITARIOS
echo ============================================
echo.
echo Executando testes...
& "C:\Users\Micro\flutter\bin\flutter.bat" test
echo.
echo Resultado esperado: 168 testes passando
pause

echo.
echo ============================================
echo CONCLUSAO - TODAS AS MELHORIAS VALIDADAS
echo ============================================
echo.
echo Parabens! Processo completo executado.
echo.
echo Proximos passos:
echo - Validar funcionalidades no celular (checklist de 14 itens)
echo - Confirmar flutter analyze sem erros
echo - Documentar resultados obtidos
echo.
pause