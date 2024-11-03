download from github and place new version here

https://github.kyndryl.net/Continuous-Engineering/sss-ansible

latest:
D:\scripts\py\tview\build\subSystemScanner\GitHub\subSystemScanner\sss-ansible-2.7-main
edit
D:\scripts\py\tview\build\subSystemScanner\GitHub\subSystemScanner\sss-ansible-2.7-main\sss-ansible-2.7-main\roles\sss-collector\files
edit subs_all.bat
change alle DEBUG_MODE=FALSE to DEBUG_MODE=TRUE

make a new zip called Windows.zip without any subfolder using 7zip
place the Unix.tar.gz Windows.zip in D:\scripts\py\tview\build\subSystemScanner\GitHub\subSystemScanner where the upload to hub takes it from



all output from subsysscan is place D:\scripts\py\tview\build\subSystemScanner\ITM_SSS_download and loaded into base_config_subsys and therefrom distributed to all base_dm[subsys]