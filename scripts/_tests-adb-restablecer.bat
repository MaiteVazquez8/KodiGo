@echo off
REM ADB test: simula el deep link del APK sin esperar correo real.
REM Verifica que el APK abre la pantalla de cambio de contrasena.
REM
REM Requiere:
REM   - dispositivo conectado (adb devices debe listar el telefono)
REM   - APK debuggable instalado con la configuracion actualizada
REM     (MainActivity con <intent-filter> scheme kodigo)
REM   - adb en PATH (%%ANDROID_HOME%%\platform-tools\adb.exe)
REM
REM Uso:
REM   _tests-adb-restablecer.bat                       -> abre la pantalla en vacio
REM   _tests-adb-restablecer.bat <hash del callback>  -> simula respuesta correcta (demo)

set "ADB_DEFAULT=%ANDROID_HOME%\platform-tools\adb.exe"
if exist "%ADB_DEFAULT%" if defined ANDROID_HOME set "ADB=%ADB_DEFAULT%"
where adb >nul 2>&1 && set "ADB=adb"

if "%ADB%"=="" (
  echo adb no encontrado. Proba configurar ANDROID_HOME o agregar platform-tools al PATH.
  exit /b 1
)

echo == Kodigo :: prueba deep link restablecer ==

echo [1/3] Comprueba que hay dispositivo conectado...
"%ADB%" devices | findstr /v "List daemon" | findstr /v /c:"List of devices attached" >nul || (
  echo No hay ningun dispositivo conectado en este ADB.
  echo Conecta un telefono con depuracion USB y autoriza la maquina.
  exit /b 1
)

if "%~1"=="" (
  set "URL=kodigo://restablecer"
) else (
  set "URL=kodigo://restablecer#%~1"
)

echo [2/3] Lanza el APK con: %URL%
"%ADB%" shell am start -a android.intent.action.VIEW -d "%URL%" -n com.kodigo.app/.MainActivity

echo [3/3] Si la app abre en la pantalla de "Restablecer contrasena" ya esta todo ok.
echo       Si se queda en la pantalla de acceso o vuelve al inicio:
echo         - verifica que el APK instalado sea el ultimo (codigo phpmyadmin: %URL%)
echo         - verifica que AndroidManifest de Android tiene <data android:scheme="kodigo" />
echo         - revisa logs: adb logcat Kodigo:I *:S
pause
