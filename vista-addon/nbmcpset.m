nbmcpset ; Set up the NB MCP bridge in VistA (test system). Idempotent.
 ; 1) Broker context option NB MCP BRIDGE with an RPC allowlist
 ; 2) Secondary menu for TDNURSE,ONE
 ; 3) COM object entry (file 101.15) for the CPRS bridge DLL
 ; 4) ORWCOM PATIENT SELECTED for TDNURSE -> fire the bridge on patient selection
 S U="^" I '$G(DUZ) S DUZ=.5,DUZ(0)="@"
 N OPT,FDA,IENR,ERR,R,I,RPC,RIEN,UIEN,COM,GUID
 S GUID="{BA123B24-A346-4244-9BE7-9BDB329E4F59}"
 S OPT=$O(^DIC(19,"B","NB MCP BRIDGE",0))
 I 'OPT D
 . K FDA,IENR,ERR
 . S FDA(19,"+1,",.01)="NB MCP BRIDGE",FDA(19,"+1,",1)="NursingBooster MCP bridge (broker context)",FDA(19,"+1,",4)="B"
 . D UPDATE^DIE("","FDA","IENR","ERR") I $D(ERR) W "ERR creating option",! D AWRITE^PXRMUTIL("ERR") Q
 . S OPT=IENR(1) W "Created option NB MCP BRIDGE IEN ",OPT,!
 E  W "Option NB MCP BRIDGE exists IEN ",OPT,!
 Q:'OPT
 F I=1:1 S RPC=$P($T(RPCS+I),";;",2) Q:RPC=""  D
 . S RIEN=$O(^XWB(8994,"B",RPC,0)) I 'RIEN W "  RPC not found: ",RPC,! Q
 . I $D(^DIC(19,OPT,"RPC","B",RIEN)) Q
 . K FDA,IENR,ERR S FDA(19.05,"+1,"_OPT_",",.01)=RIEN D UPDATE^DIE("","FDA","IENR","ERR")
 . W "  ",$S($D(ERR):"ERR adding ",1:"Added RPC "),RPC,!
 S UIEN=$O(^VA(200,"B","TDNURSE,ONE",0))
 I UIEN,'$D(^VA(200,UIEN,203,"B",OPT)) K FDA,IENR,ERR S FDA(200.03,"+1,"_UIEN_",",.01)=OPT D UPDATE^DIE("","FDA","IENR","ERR") W "Secondary menu added to TDNURSE",!
 S COM=$O(^ORD(101.15,"B","NB MCP BRIDGE",0))
 I 'COM D
 . K FDA,IENR,ERR S FDA(101.15,"+1,",.01)="NB MCP BRIDGE",FDA(101.15,"+1,",.02)=GUID
 . D UPDATE^DIE("","FDA","IENR","ERR") I $D(ERR) W "ERR creating COM object",! D AWRITE^PXRMUTIL("ERR") Q
 . S COM=IENR(1) W "Created COM object NB MCP BRIDGE IEN ",COM,!
 E  W "COM object NB MCP BRIDGE exists IEN ",COM,!
 Q:'COM
 K ERR D EN^XPAR(UIEN_";VA(200,","ORWCOM PATIENT SELECTED",1,"`"_COM,.ERR)
 W "ORWCOM PATIENT SELECTED for TDNURSE: ",$S(+$G(ERR):"ERR "_ERR,1:"set to "_COM),!
 D PTOBJ^ORWCOM(.R) W "PTOBJ check (as DUZ ",DUZ,"): ",$G(R),!
 Q
RPCS ;; RPC allowlist for the bridge context
 ;;XUS GET TOKEN
 ;;PXRM REMINDER DIALOG (TIU)
 ;;ORQQPXRM REMINDER DIALOG
 ;;ORQQPXRM DIALOG PROMPTS
 ;;ORQQPXRM DIALOG ACTIVE
 ;;
