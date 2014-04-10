del /s.\bin\log\*.*
del /s.\bin\*.ldb

.\tool\7z.exe a %date:~0,4%%date:~5,2%%date:~8,2%%time:~0,2%%time:~3,2%_Bin.7z .\bin\ .\tool\ หตร๗.doc