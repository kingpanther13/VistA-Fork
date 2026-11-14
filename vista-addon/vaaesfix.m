vaaesfix ; Ensure the VAAES reminder dialogs are installed. Idempotent; safe to run every boot.
 ; For each PRD: if its dialog already exists -> skip. Else if the Exchange File entry is loaded
 ; -> re-run the component install. Else load+install the PRD from /prd-files/.
 S U="^"
 I '$G(DUZ) S DUZ=.5,DUZ(0)="@"
 N P,DIR,FILE,ENTRY,DLG,RIEN,DIEN,OK
 S DIR="/prd-files/"
 S P(1,"FILE")="UPDATE_2_0_212 VAAES SHIFT ASSESSMENT BUNDLE.PRD"
 S P(1,"ENTRY")="UPDATE_2_0_212 VAAES SHIFT ASSESSMENT BUNDLE"
 S P(1,"DLG")="VA-AES ACUTE INPATIENT NSG SHIFT ASSESSMENT"
 S P(2,"FILE")="UPDATE_2_0_460 VA-VAAES SKIN INSPECTION-ASSESSMENT UPDATE.PRD"
 S P(2,"ENTRY")="UPDATE_2_0_460 VA-VAAES SKIN INSPECTION/ASSESSMENT UPDATE"
 S P(2,"DLG")="VAAES SKIN INSPECTION/ASSESSMENT"
 S OK=1
 N I F I=1:1:2 D
 . S FILE=P(I,"FILE"),ENTRY=P(I,"ENTRY"),DLG=P(I,"DLG")
 . S DIEN=$O(^PXRMD(801.41,"B",DLG,0))
 . I DIEN W !,"OK: dialog exists: ",DLG," (IEN ",DIEN,")" Q
 . D CLEAN(ENTRY)
 . S RIEN=$O(^PXD(811.8,"B",ENTRY,0))
 . I RIEN D
 .. W !,"Exchange entry loaded (IEN ",RIEN,") but dialog missing - installing components: ",ENTRY
 .. D INSTALL^prdimport(RIEN)
 . E  D
 .. W !,"Loading and installing ",FILE
 .. D EN^prdimport(DIR,FILE)
 . S DIEN=$O(^PXRMD(801.41,"B",DLG,0))
 . I DIEN W !,"OK: dialog now exists: ",DLG," (IEN ",DIEN,")"
 . E  S OK=0 W !,"STILL MISSING: ",DLG
 W !,$S(OK:"VAAES DIALOGS OK",1:"VAAES DIALOGS INCOMPLETE"),!
 Q
 ;
CLEAN(ENTRY) ; Remove half-loaded Exchange entries (an interrupted load leaves a B-index with no data,
 ; and INSTALL then dies with GVUNDEF) so the PRD is loaded fresh.
 N RIEN,DIK,DA S RIEN=""
 F  S RIEN=$O(^PXD(811.8,"B",ENTRY,RIEN)) Q:RIEN=""  D
 . I $D(^PXD(811.8,RIEN,0)),$D(^PXD(811.8,RIEN,100)) Q
 . W !,"Removing incomplete Exchange entry ",RIEN,": ",ENTRY
 . I $D(^PXD(811.8,RIEN,0)) S DIK="^PXD(811.8,",DA=RIEN D ^DIK
 . K ^PXD(811.8,"B",ENTRY,RIEN)
 Q
