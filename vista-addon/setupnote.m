setupnote ; Create TIU note titles linked to VAAES reminder dialogs
 S U="^"
 I '$G(DUZ) S DUZ=.5,DUZ(0)="@"
 S TIUFPRIV=1
 ;
 W !,"=== VAAES Note Title Setup ===",!
 ;
 ; Use PROGRESS NOTES (IEN 3) as parent - NURSING TITLES (102) has
 ; CANENTR=0 which filters out the entire subtree in CPRS
 N PCLASS S PCLASS=3
 I '$D(^TIU(8925.1,PCLASS,0)) W !,"ERROR: PROGRESS NOTES (IEN 3) not found",! Q
 W !,"Parent: ",$P(^TIU(8925.1,PCLASS,0),U,1)," (IEN=",PCLASS,")"
 ;
 ; Create note titles for the main dialogs
 N TITLES,I,TNAME,DLGNAME,DLGIEN,NOTEIEN,LASTIEN
 S TITLES(1,"TITLE")="VAAES ACUTE INPT NSG SHIFT ASSESSMENT"
 S TITLES(1,"DIALOG")="VA-AES ACUTE INPATIENT NSG SHIFT ASSESSMENT"
 S TITLES(2,"TITLE")="VAAES NSG IV INSERT AND MAINTAIN"
 S TITLES(2,"DIALOG")="VA-AES NSG IV INSERT AND MAINTAIN"
 S TITLES(3,"TITLE")="VAAES SKIN INSPECTION ASSESSMENT"
 S TITLES(3,"DIALOG")="VAAES SKIN INSPECTION/ASSESSMENT"
 ;
 N NUMTITLES S NUMTITLES=3
 ;
 ; Get the last IEN from file header
 S LASTIEN=+$P(^TIU(8925.1,0),U,3)
 ;
 F I=1:1:NUMTITLES D
 . S TNAME=TITLES(I,"TITLE")
 . S DLGNAME=TITLES(I,"DIALOG")
 . ; Find the dialog
 . S DLGIEN=0
 . I $D(^PXRMD(801.41,"B",DLGNAME)) S DLGIEN=$O(^PXRMD(801.41,"B",DLGNAME,0))
 . I DLGIEN=0 W !,"  Dialog not found: ",DLGNAME Q
 . W !,"  Dialog: ",DLGNAME," (IEN=",DLGIEN,")"
 . ;
 . ; Check if title already exists
 . S NOTEIEN=0
 . I $D(^TIU(8925.1,"B",TNAME)) S NOTEIEN=$O(^TIU(8925.1,"B",TNAME,0))
 . I NOTEIEN>0 W !,"  Title exists (IEN=",NOTEIEN,")" D  Q
 .. ; Ensure AD xref, ACL xref, and item multiple under PROGRESS NOTES
 .. S ^TIU(8925.1,"AD",NOTEIEN,PCLASS)=""
 .. S ^TIU(8925.1,"ACL",PCLASS,TNAME,NOTEIEN)=""
 .. ; Check if already in PROGRESS NOTES items
 .. N FOUND,C S FOUND=0,C=0
 .. F  S C=$O(^TIU(8925.1,PCLASS,10,C)) Q:'C  D
 ... I +$G(^TIU(8925.1,PCLASS,10,C,0))=NOTEIEN S FOUND=1
 .. I 'FOUND D
 ... N ITEMIEN S ITEMIEN=$O(^TIU(8925.1,PCLASS,10,"A"),-1)+1
 ... S ^TIU(8925.1,PCLASS,10,ITEMIEN,0)=NOTEIEN
 ... S ^TIU(8925.1,PCLASS,10,"B",NOTEIEN,ITEMIEN)=""
 ... S $P(^TIU(8925.1,PCLASS,10,0),U,3)=ITEMIEN
 ... S $P(^TIU(8925.1,PCLASS,10,0),U,4)=$P(^TIU(8925.1,PCLASS,10,0),U,4)+1
 ... W !,"  Added to PROGRESS NOTES items"
 .. W !,"  Verified AD xref and item placement"
 . ;
 . ; Create new entry directly (mimic working title structure)
 . S LASTIEN=LASTIEN+1
 . ; Zero node: NAME^^PRINTNAME^TYPE^^STATUS^ACTIVE
 . ; DOC type, piece 5 empty, status=55, piece7=11 (active)
 . S ^TIU(8925.1,LASTIEN,0)=TNAME_"^^"_TNAME_"^DOC^^55^11"
 . ; Set B index
 . S ^TIU(8925.1,"B",TNAME,LASTIEN)=""
 . ; Update file header
 . S $P(^TIU(8925.1,0),U,3)=LASTIEN
 . S $P(^TIU(8925.1,0),U,4)=$P(^TIU(8925.1,0),U,4)+1
 . ; Add to PROGRESS NOTES item multiple
 . N ITEMIEN S ITEMIEN=$O(^TIU(8925.1,PCLASS,10,"A"),-1)+1
 . S ^TIU(8925.1,PCLASS,10,ITEMIEN,0)=LASTIEN
 . S ^TIU(8925.1,PCLASS,10,"B",LASTIEN,ITEMIEN)=""
 . S $P(^TIU(8925.1,PCLASS,10,0),U,3)=ITEMIEN
 . S $P(^TIU(8925.1,PCLASS,10,0),U,4)=$P(^TIU(8925.1,PCLASS,10,0),U,4)+1
 . ;
 . ; Set AD cross-reference (child->parent) for ISA^TIULX traversal
 . S ^TIU(8925.1,"AD",LASTIEN,PCLASS)=""
 . ; Set ACL cross-reference for LONGLIST search (TIU LONG LIST OF TITLES)
 . S ^TIU(8925.1,"ACL",PCLASS,TNAME,LASTIEN)=""
 . ;
 . S NOTEIEN=LASTIEN
 . W !,"  Created title: ",TNAME," (IEN=",NOTEIEN,")"
 . W !,"  Set AD xref AD(",NOTEIEN,",",PCLASS,")"
 ;
 W !!,"=== Done ==="
 W !,"In CPRS: Notes > New Note > search for VAAES",!
 Q
