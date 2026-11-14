mdclio ; Assign MD CLIO (CP Flowsheets broker context) as a secondary menu option to demo users. Idempotent.
 S U="^"
 I '$G(DUZ) S DUZ=.5,DUZ(0)="@"
 N OPT S OPT=$O(^DIC(19,"B","MD CLIO",0))
 W !,"MD CLIO option IEN: ",OPT
 I 'OPT W !,"MD CLIO option not found in file 19" Q
 N USERS,I,UIEN,NAME,FDA,ERR,IENR
 S USERS(1)="TDNURSE,ONE",USERS(2)="PROGRAMMER,ONE",USERS(3)="PROVIDER,VERO",USERS(4)="VEHU,TEN"
 F I=1:1:4 D
 . S NAME=USERS(I),UIEN=$O(^VA(200,"B",NAME,0))
 . I 'UIEN W !,"  User not found: ",NAME Q
 . I $D(^VA(200,UIEN,203,"B",OPT)) W !,"  ",NAME," already has MD CLIO" Q
 . K FDA,ERR,IENR
 . S FDA(200.03,"+1,"_UIEN_",",.01)=OPT
 . D UPDATE^DIE("","FDA","IENR","ERR")
 . I $D(ERR) W !,"  ERROR adding to ",NAME,":" D AWRITE^PXRMUTIL("ERR") Q
 . W !,"  Added MD CLIO to ",NAME," (user IEN ",UIEN,")"
 W !
 Q
