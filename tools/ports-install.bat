@echo off
Set filename=%1
For %%A in ("%filename%") do (
    Set folder=%%~dpA
    Set name=%%~nxA
)

scp -P 5522 %filename% root@localhost:/home/root/%name%
ssh -p 5522  root@localhost  '/usr/bin/opkg -o  / install %name%; luna-send -n 1 palm://com.palm.applicationManager/rescan {};'
@REM ssh -p 5522  root@localhost  'luna-send -n 6 palm://com.palm.appinstaller/installNoVerify '{"subscribe":true, "target":/home/root/%name%}'