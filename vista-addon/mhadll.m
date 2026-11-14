mhadll ; Name the MHA instrument DLL CPRS loads (Morse Fall Scale, Braden Scale in VAAES). Idempotent.
 ; VEHU ships YS MHA_A DLL NAME empty, so CPRS reports "parameter is not setup" on any instrument.
 S U="^"
 I '$G(DUZ) S DUZ=.5,DUZ(0)="@"
 N WANT,CUR,ERR
 S WANT="YS_MHA_A_XE10.dll"
 S CUR=$$GET^XPAR("SYS","YS MHA_A DLL NAME")
 I CUR'="" W !,"YS MHA_A DLL NAME = ",CUR," (already set)",!,"MHADLL done",! Q
 D EN^XPAR("SYS","YS MHA_A DLL NAME",1,WANT,.ERR)
 W !,"YS MHA_A DLL NAME set to ",WANT,$S(+$G(ERR):"  ERR="_ERR,1:""),!,"MHADLL done",!
 Q
