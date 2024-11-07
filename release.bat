@echo off

if [%1]==[] goto :help

setlocal enableDelayedExpansion
set /p "GH_TOKEN=" <GITHUB_TOKEN

git tag -a %1 -m "Release %1."
git push origin %1

gh release create %1 --notes-from-tag

goto :done

:help
echo Usage %0 version_number
goto :done

:done
