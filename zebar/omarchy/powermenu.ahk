#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

; Omarchy power actions for the Zebar bar.
;   powermenu.ahk <lock|sleep|restart|shutdown|signout>  -> do it directly (used by the power popup)
;   powermenu.ahk                                        -> show a small menu at the cursor

DoAction(choice) {
    switch choice {
        case "lock":     DllCall("LockWorkStation")
        case "sleep":    DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)
        case "restart":  Run("shutdown.exe /r /t 0")
        case "shutdown": Run("shutdown.exe /s /t 0")
        case "signout":  Run("shutdown.exe /l")
    }
}

if A_Args.Length {
    DoAction(A_Args[1])
    ExitApp
}

choice := ""
m := Menu()
m.Add("&Lock", (*) => (choice := "lock"))
m.Add("S&leep", (*) => (choice := "sleep"))
m.Add("&Restart", (*) => (choice := "restart"))
m.Add("Shut &down", (*) => (choice := "shutdown"))
m.Add("Sign &out", (*) => (choice := "signout"))
m.Show()
Sleep 150
DoAction(choice)
ExitApp
