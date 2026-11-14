@echo on

:: Configure autotools_clang_conda flag
set "REMOVE_LIB_PREFIX=0"

:: Invoke official conda-forge autotools clang build wrapper
call "%BUILD_PREFIX%\Library\bin\run_autotools_clang_conda_build.bat"
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
