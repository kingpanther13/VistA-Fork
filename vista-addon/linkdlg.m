linkdlg ; Link VAAES note titles to reminder dialogs via TIU templates
 S U="^"
 I '$G(DUZ) S DUZ=.5,DUZ(0)="@"
 ;
 W !,"=== Linking VAAES titles to reminder dialogs ==="
 ;
 ; Get the next IEN for file 8927
 N LASTIEN S LASTIEN=+$P($G(^TIU(8927,0)),U,3)
 W !,"Last template IEN: ",LASTIEN
 ;
 ; Define what we need to link (title name -> dialog name)
 N LINKS
 S LINKS(1,"TNAME")="VAAES ACUTE INPT NSG SHIFT ASSESSMENT"
 S LINKS(1,"DLGNAME")="VA-AES ACUTE INPATIENT NSG SHIFT ASSESSMENT"
 S LINKS(2,"TNAME")="VAAES NSG IV INSERT AND MAINTAIN"
 S LINKS(2,"DLGNAME")="VA-AES NSG IV INSERT AND MAINTAIN"
 S LINKS(3,"TNAME")="VAAES SKIN INSPECTION ASSESSMENT"
 S LINKS(3,"DLGNAME")="VAAES SKIN INSPECTION/ASSESSMENT"
 ;
 N NUMLINKS S NUMLINKS=3
 ;
 N I F I=1:1:NUMLINKS D
 . N TIEN,DLGIEN,NOTEIEN,TNAME,DLGNAME
 . S TNAME=LINKS(I,"TNAME")
 . S DLGNAME=LINKS(I,"DLGNAME")
 . ;
 . ; Look up title IEN dynamically from B index
 . S NOTEIEN=$O(^TIU(8925.1,"B",TNAME,0))
 . I 'NOTEIEN W !,"  Title not found: ",TNAME," - run setupnote first" Q
 . W !,"  Title: ",TNAME," (IEN=",NOTEIEN,")"
 . ;
 . ; Find the reminder dialog IEN in 801.41
 . S DLGIEN=0
 . I $D(^PXRMD(801.41,"B",DLGNAME)) S DLGIEN=$O(^PXRMD(801.41,"B",DLGNAME,0))
 . I DLGIEN=0 W !,"  Dialog not found: ",DLGNAME Q
 . W !,"  Dialog: ",DLGNAME," (IEN=",DLGIEN,")"
 . ;
 . ; Check if template already exists for this title
 . N LINKVAL S LINKVAL=NOTEIEN_";TIU(8925.1,"
 . I $D(^TIU(8927,"AL",LINKVAL)) D  Q
 .. N EXISTING S EXISTING=$O(^TIU(8927,"AL",LINKVAL,0))
 .. W !,"  Template already exists: IEN ",EXISTING
 .. ; Just update the reminder dialog pointer
 .. S $P(^TIU(8927,EXISTING,0),U,15)=DLGIEN
 .. W !,"  Updated reminder dialog to ",DLGIEN
 . ;
 . ; Create new template entry
 . S LASTIEN=LASTIEN+1
 . S TIEN=LASTIEN
 . ;
 . ; Node 0: NAME^^TYPE^STATUS^EXCL^^^DIALOG^DISP^FIRST^ONEITEM^HIDEDLG^HIDETREE^INDENT^REMDLG^LOCK^COM^COMPARAM^LINK
 . S ^TIU(8927,TIEN,0)=TNAME_"^^T^A^0^^^0^0^0^0^0^0^0^"_DLGIEN_"^0^^^"_LINKVAL
 . ;
 . ; Set B index
 . S ^TIU(8927,"B",TNAME,TIEN)=""
 . ;
 . ; Set AL index (links template to note title)
 . S ^TIU(8927,"AL",LINKVAL,TIEN)=""
 . ;
 . ; Update file header
 . S $P(^TIU(8927,0),U,3)=TIEN
 . S $P(^TIU(8927,0),U,4)=$P(^TIU(8927,0),U,4)+1
 . ;
 . W !,"  Created template IEN ",TIEN
 . W !,"  Linked to title ",NOTEIEN," via AL(",LINKVAL,")"
 . W !,"  Reminder dialog: ",DLGIEN
 ;
 ; Verify GETLINK for all titles
 W !!,"=== Verification ==="
 N ORY,TIEN1,TIEN2,TIEN3
 S TIEN1=$O(^TIU(8925.1,"B","VAAES ACUTE INPT NSG SHIFT ASSESSMENT",0))
 S TIEN2=$O(^TIU(8925.1,"B","VAAES NSG IV INSERT AND MAINTAIN",0))
 S TIEN3=$O(^TIU(8925.1,"B","VAAES SKIN INSPECTION ASSESSMENT",0))
 I TIEN1 D GETLINK^TIUSRVT1(.ORY,TIEN1) W !,"GETLINK(",TIEN1,"): ",ORY
 I TIEN2 D GETLINK^TIUSRVT1(.ORY,TIEN2) W !,"GETLINK(",TIEN2,"): ",ORY
 I TIEN3 D GETLINK^TIUSRVT1(.ORY,TIEN3) W !,"GETLINK(",TIEN3,"): ",ORY
 ;
 W !!,"Done. Select the title in CPRS - reminder dialog should now load.",!
 Q
