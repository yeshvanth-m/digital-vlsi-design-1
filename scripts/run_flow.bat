@echo off
REM ===========================================================================
REM run_flow.bat  --  one-shot RTL flow: simulate + synthesize (generic & Sky130)
REM ---------------------------------------------------------------------------
REM   1. Icarus Verilog compile + vvp simulation   -> sim\<top>.vvp / .log / .vcd
REM   2. Generic (tech-independent) synthesis       -> build\<top>_gates.svg/.json
REM   3. Sky130 standard-cell synthesis             -> build\<top>_sky130.svg/.json
REM
REM USAGE (run from anywhere; paths resolve against the repo root):
REM   scripts\run_flow.bat <top> "<rtl files>" ["<tb files>"] [PARAM=VALUE] [/clean]
REM   scripts\run_flow.bat clean          (just wipe build\ and sim\, then exit)
REM
REM   /clean  wipes build\ and sim\ BEFORE running the flow.
REM
REM EXAMPLES:
REM   scripts\run_flow.bat counter "rtl/counter/counter.v" "rtl/counter/tb_counter.v"
REM   scripts\run_flow.bat moore_101_fsm "rtl/fsm/moore/moore_101_fsm.v" "rtl/fsm/moore/tb_moore_101_fsm.v"
REM   scripts\run_flow.bat state_encoding_demo "rtl/fsm/encoding/state_encoding_demo.v rtl/fsm/moore/moore_101_fsm.v" "rtl/fsm/encoding/tb_state_encoding_demo.v" ENCODING=ONEHOT
REM
REM ARGS:
REM   %1  top module name (also used as the output basename)
REM   %2  design source file(s), space-separated inside one quoted string
REM   %3  testbench file(s), quoted (optional; omit or "" to skip simulation)
REM   %4  optional parameter override NAME=VALUE, applied via `chparam`
REM ===========================================================================
setlocal enabledelayedexpansion

set "SCRIPTDIR=%~dp0"
pushd "%SCRIPTDIR%.."
set "ROOT=%CD%"

REM --- parse args (positional; /clean flag may appear anywhere) --------------
set "TOP="
set "RTL="
set "TB="
set "PARAM="
set "DOCLEAN="
set "CLEANONLY="
set "argidx=0"
:parse
if "%~1"=="" goto :parsed
if /i "%~1"=="/clean" ( set "DOCLEAN=1" & shift & goto :parse )
if /i "%~1"=="-clean" ( set "DOCLEAN=1" & shift & goto :parse )
if /i "%~1"=="clean" if "%~2"=="" ( set "CLEANONLY=1" & goto :parsed )
set /a argidx+=1
if !argidx!==1 set "TOP=%~1"
if !argidx!==2 set "RTL=%~1"
if !argidx!==3 set "TB=%~1"
if !argidx!==4 set "PARAM=%~1"
shift
goto :parse
:parsed

REM --- clean-only mode: wipe build\ and sim\ and exit ------------------------
if defined CLEANONLY (
  call :doclean
  echo Cleaned build\ and sim\.
  popd & endlocal & exit /b 0
)

if "%TOP%"=="" (
  echo Usage: scripts\run_flow.bat ^<top^> "^<rtl files^>" ["^<tb files^>"] [PARAM=VALUE] [/clean]
  echo        scripts\run_flow.bat clean       ^(just wipe build\ and sim\^)
  popd & endlocal & exit /b 1
)
set "NAME=%TOP%"
set "LIB=skywater-pdk/sky130_fd_sc_hd__tt_025C_1v80.lib"

REM --- load toolchain + graphviz --------------------------------------------
call "%ROOT%\oss-cad-suite\environment.bat" >nul
cd /d "%ROOT%"
set "PATH=%ROOT%\graphviz\bin;%PATH%"

REM --- optional clean before running ----------------------------------------
if defined DOCLEAN (
  echo Cleaning build\ and sim\ ...
  call :doclean
)

if not exist sim   mkdir sim
if not exist build mkdir build

REM read_verilog wants forward slashes; the `show` prefix wants backslashes.
set "RTLFWD=%RTL:\=/%"

REM optional chparam line (string value is quoted)
set "CHP="
if not "%PARAM%"=="" (
  for /f "tokens=1,2 delims==" %%a in ("%PARAM%") do set "CHP=chparam -set %%a "%%b" %TOP%"
)

REM ==========================================================================
REM 1) SIMULATION
REM ==========================================================================
echo.
echo === [1/3] Simulation (iverilog + vvp) ===
if not "%TB%"=="" (
  iverilog -o "sim\%NAME%.vvp" %RTL% %TB%
  if errorlevel 1 goto :err
  vvp "sim\%NAME%.vvp" > "sim\%NAME%.log" 2>&1
  type "sim\%NAME%.log"
  if exist "%NAME%.vcd" move /y "%NAME%.vcd" "sim\%NAME%.vcd" >nul
  echo   -^> sim\%NAME%.vvp, sim\%NAME%.log
) else (
  echo   (skipped: no testbench given^)
)

REM ==========================================================================
REM 2) GENERIC SYNTHESIS (technology-independent ABC gate mapping)
REM ==========================================================================
echo.
echo === [2/3] Generic synthesis (ABC gates) ===
set "YS=build\%NAME%_gates.ys"
> "%YS%" echo read_verilog %RTLFWD%
if defined CHP >> "%YS%" echo %CHP%
>> "%YS%" echo synth -top %TOP%
>> "%YS%" echo abc -g AND,NAND,OR,NOR,XOR,XNOR,ANDNOT,ORNOT,MUX
>> "%YS%" echo opt_clean
>> "%YS%" echo stat
>> "%YS%" echo write_json build/%NAME%_gates.json
>> "%YS%" echo show -format svg -viewer none -prefix build\%NAME%_gates
yosys -s "%YS%" > "build\%NAME%_gates.log" 2>&1
if errorlevel 1 goto :err
findstr /R /C:"^ *[0-9][0-9]* *\$_" /C:"Number of cells" "build\%NAME%_gates.log"
echo   -^> build\%NAME%_gates.svg, .json, .log

REM ==========================================================================
REM 3) SKY130 SYNTHESIS (SkyWater PDK standard cells)
REM ==========================================================================
echo.
echo === [3/3] Sky130 synthesis (SkyWater PDK) ===
set "YS=build\%NAME%_sky130.ys"
> "%YS%" echo read_verilog %RTLFWD%
if defined CHP >> "%YS%" echo %CHP%
>> "%YS%" echo synth -top %TOP%
>> "%YS%" echo dfflibmap -liberty %LIB%
>> "%YS%" echo abc -liberty %LIB%
>> "%YS%" echo clean
>> "%YS%" echo stat
>> "%YS%" echo write_json build/%NAME%_sky130.json
>> "%YS%" echo show -format svg -viewer none -prefix build\%NAME%_sky130
yosys -s "%YS%" > "build\%NAME%_sky130.log" 2>&1
if errorlevel 1 goto :err
findstr /R /C:"^ *[0-9][0-9]* *sky130" /C:"Number of cells" "build\%NAME%_sky130.log"
echo   -^> build\%NAME%_sky130.svg, .json, .log

echo.
echo DONE: %NAME%
popd & endlocal & exit /b 0

:doclean
if exist build rmdir /s /q build
if exist sim   rmdir /s /q sim
mkdir build
mkdir sim
exit /b

:err
echo.
echo *** FLOW FAILED (see logs in build\ or sim\) ***
popd & endlocal & exit /b 1
