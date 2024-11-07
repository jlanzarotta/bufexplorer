@echo off

if [%1]==[] goto :help

setlocal enableDelayedExpansion
set /p "GH_TOKEN=" <GITHUB_TOKEN

git tag -a %1 -m "Release %1."
git push origin %1

7z a bufexplorer-%1.zip plugin\bufexplorer.vim doc\bufexplorer.txt
gh release create %1 --notes-from-tag bufexplorer-%1.zip

::gh release create %1 --notes-from-tag

goto :done

:help
echo Usage %0 version_number
goto :done

:done
