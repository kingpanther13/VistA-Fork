cpfsver ; Set the CP Flowsheets client version VistA requires to the public 1.0.63.2 build. Idempotent.
 ; MD*1.0*87's post-install stores VERSION_CPFLOWSHEETS=1.0.87.1 in the MD PARAMETERS parameter at the
 ; DOMAIN entity; that client build is not publicly available, so accept 1.0.63.2 (FOIA MD_1_63 zip).
 S U="^"
 I '$G(DUZ) S DUZ=.5,DUZ(0)="@"
 N WANT,ENT,CUR,ERR,X,DONE,EI
 S WANT="1.0.63.2"
 ; Update every entity that carries VERSION_CPFLOWSHEETS (MD*1.0*87 stores it at the DOMAIN level)
 S EI=0 F  S EI=$O(^XTV(8989.5,EI)) Q:'EI  S X=$G(^XTV(8989.5,EI,0)) I $P(X,U,3)="VERSION_CPFLOWSHEETS",$P($G(^XTV(8989.51,+$P(X,U,2),0)),U,1)="MD PARAMETERS" D
 . S ENT=$P(X,U,1),CUR=$G(^XTV(8989.5,EI,1))
 . W !,"VERSION_CPFLOWSHEETS at ",ENT," = ",CUR
 . I CUR=WANT W " (already ",WANT,")" S DONE(ENT)="" Q
 . K ERR D EN^XPAR(ENT,"MD PARAMETERS","VERSION_CPFLOWSHEETS",WANT,.ERR)
 . W " -> set to ",WANT,$S($G(ERR):"  ERR="_ERR,1:"") S DONE(ENT)=""
 I '$D(DONE) D
 . ; No entry at all: set at SYS level
 . K ERR D EN^XPAR("SYS","MD PARAMETERS","VERSION_CPFLOWSHEETS",WANT,.ERR)
 . W !,"No existing entry; set VERSION_CPFLOWSHEETS=",WANT," at SYS",$S($G(ERR):"  ERR="_ERR,1:"")
 W !,"CPFSVER done",!
 Q
