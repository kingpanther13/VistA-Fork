fixdlgauth ; Fix reminder dialog authorization for TIU templates
 S U="^"
 I '$G(DUZ) S DUZ=.5,DUZ(0)="@"
 S DUZ(2)=500 ; Default division
 ;
 W !,"=== Fixing dialog authorization ==="
 ;
 ; Look up dialog IENs dynamically
 N DLGS,DLGCT,DI
 S DLGS(1)="VA-AES ACUTE INPATIENT NSG SHIFT ASSESSMENT"
 S DLGS(2)="VA-AES NSG IV INSERT AND MAINTAIN"
 S DLGS(3)="VAAES SKIN INSPECTION/ASSESSMENT"
 S DLGCT=3
 ;
 ; Authorize each dialog
 W !!,"Adding dialogs to TIU TEMPLATE REMINDER DIALOGS (SYS)..."
 N ERR
 F DI=1:1:DLGCT D
 . N DIEN,DNAME
 . S DIEN=$O(^PXRMD(801.41,"B",DLGS(DI),0))
 . I 'DIEN W !,"  Dialog not found: ",DLGS(DI) Q
 . S DNAME=$P($G(^PXRMD(801.41,DIEN,0)),U,1)
 . W !,"  Dialog ",DI,": ",DNAME," (IEN=",DIEN,")"
 . W " disable='",$P($G(^PXRMD(801.41,DIEN,0)),U,3),"'"
 . D EN^XPAR("SYS","TIU TEMPLATE REMINDER DIALOGS",DIEN,DNAME,.ERR)
 . W " auth-err='",ERR,"'"
 ;
 ; Verify parameter list
 W !!,"=== Verify parameter list ==="
 N TIULST,TIUERR,IDX
 D GETLST^XPAR(.TIULST,"SYS","TIU TEMPLATE REMINDER DIALOGS","Q",.TIUERR)
 S IDX=0
 N CT S CT=0
 F  S IDX=$O(TIULST(IDX)) Q:'IDX  S CT=CT+1 I CT<20 W !,"  ",IDX,": ",TIULST(IDX)
 W !,"Total authorized dialogs: ",CT
 ;
 ; Verify REMDLGOK
 W !!,"=== Verify REMDLGOK ==="
 N TIUY
 F DI=1:1:DLGCT D
 . N DIEN S DIEN=$O(^PXRMD(801.41,"B",DLGS(DI),0)) Q:'DIEN
 . D REMDLGOK^TIUSRVT2(.TIUY,DIEN)
 . W !,"REMDLGOK(",DIEN,"): ",TIUY
 ;
 W !!,"Done. Try selecting the note title again in CPRS.",!
 Q
