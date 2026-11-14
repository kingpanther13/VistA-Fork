prdimport ; Automated PRD file import for VistA Reminder Exchange
 ; Loads PRD files from the filesystem and installs all components
 ; without interactive prompts.
 ;
 ; Usage from mumps direct mode:
 ;   D EN^prdimport(path,file)    - Load and install one PRD file
 ;   D ALL^prdimport(dir)         - Load and install all PRD files in dir
 ;   D LOAD^prdimport(path,file)  - Load only (no install)
 ;   D LIST^prdimport             - List exchange file entries
 ;
 ; Designed for non-interactive use in Docker containers running
 ; worldvista/vehu:latest on YottaDB/GT.M.
 ;
 Q
 ;
 ; ---- Main entry: load and install a single PRD file ----
EN(PATH,FILE) ;
 N SUCCESS,RIEN,LOADIEN
 S U="^"
 I $G(PATH)="" W "Error: PATH is required",! Q
 I $G(FILE)="" W "Error: FILE is required",! Q
 ;
 ; Ensure PATH ends with /
 I $E(PATH,$L(PATH))'="/" S PATH=PATH_"/"
 ;
 W !,"============================================"
 W !,"  PRD Import Utility"
 W !,"============================================"
 W !,"File: ",PATH,FILE,!
 ;
 ; Step 1: Ensure DUZ is set (needed for install history)
 D CHKDUZ
 ;
 ; Step 2: Load the PRD file into the Exchange File (811.8)
 W !,"Step 1: Loading PRD file into Exchange File..."
 D LOAD(PATH,FILE)
 I '$G(SUCCESS) W !,"ERROR: Failed to load PRD file.",! Q
 ;
 ; Step 3: Find the exchange file entry we just loaded
 ; LOADIEN is set by LTMP during the load process
 S RIEN=$G(LOADIEN)
 I RIEN="" S RIEN=$$FINDLAST()
 I RIEN="" W !,"ERROR: Could not find loaded exchange entry.",! Q
 W !,"  Loaded as Exchange File entry IEN: ",RIEN
 W !,"  Name: ",$P($G(^PXD(811.8,RIEN,0)),U,1)
 ;
 ; Step 4: Install all components silently
 W !,"Step 2: Installing all components (silent mode)..."
 D INSTALL(RIEN)
 ;
 W !,"============================================"
 W !,"  Import complete."
 W !,"============================================",!
 Q
 ;
 ; ---- Load and install all PRD files in a directory ----
ALL(DIR) ;
 N FILE,FILES,CNT,OK
 S U="^"
 I $G(DIR)="" S DIR="/prd-files/"
 ; Ensure DIR ends with /
 I $E(DIR,$L(DIR))'="/" S DIR=DIR_"/"
 ;
 W !,"============================================"
 W !,"  Batch PRD Import"
 W !,"  Directory: ",DIR
 W !,"============================================",!
 ;
 ; Ensure DUZ is set
 D CHKDUZ
 ;
 ; Find all .PRD and .prd files in the directory
 S CNT=0
 N SPEC
 S SPEC("*.PRD")=""
 S SPEC("*.prd")=""
 S OK=$$LIST^%ZISH(DIR,"SPEC","FILES")
 I 'OK W !,"ERROR: Cannot read directory or no PRD files found: ",DIR,! Q
 ;
 ; Process each file
 S FILE=""
 F  S FILE=$O(FILES(FILE)) Q:FILE=""  D
 . S CNT=CNT+1
 . W !,"--- File ",CNT,": ",FILE," ---"
 . D EN(DIR,FILE)
 . W !
 ;
 I CNT=0 W !,"No PRD files found in ",DIR,!
 E  W !,"Processed ",CNT," PRD file(s).",!
 Q
 ;
 ; ---- Load a PRD file into the Exchange File (no install) ----
LOAD(PATH,FILE) ;
 ; Uses the same logic as LHF^PXRMEXHF but works non-interactively.
 ; Reads the host file into ^TMP, validates XML format, then stores
 ; it in the REMINDER EXCHANGE FILE (#811.8).
 N GBL,NODE
 S NODE="EXHF"
 K ^TMP($J,NODE)
 ;
 ; Read the file into ^TMP using %ZISH File-To-Global
 S GBL="^TMP($J,"""_NODE_""",1,1)"
 S GBL=$NA(@GBL)
 S SUCCESS=$$FTG^%ZISH(PATH,FILE,GBL,3)
 I 'SUCCESS D  Q
 . W !,"  ERROR: Cannot read file ",PATH,FILE
 . W !,"  Check that the path exists and the file is readable."
 . K ^TMP($J,NODE)
 ;
 ; Validate XML format
 I ($G(^TMP($J,NODE,1,1))'["xml") D  Q
 . W !,"  ERROR: File does not start with XML header."
 . W !,"  First line: ",$G(^TMP($J,NODE,1,1))
 . S SUCCESS=0
 . K ^TMP($J,NODE)
 I ($G(^TMP($J,NODE,2,1))'="<REMINDER_EXCHANGE_FILE_ENTRY>") D  Q
 . W !,"  ERROR: File is not a valid Reminder Exchange entry."
 . W !,"  Second line: ",$G(^TMP($J,NODE,2,1))
 . S SUCCESS=0
 . K ^TMP($J,NODE)
 ;
 W !,"  File format validated OK."
 ;
 ; Parse and store into ^PXD(811.8) using LTMP^PXRMEXHF logic
 D LTMP(.SUCCESS,NODE)
 K ^TMP($J,NODE)
 ;
 I SUCCESS W !,"  PRD file loaded successfully."
 E  W !,"  WARNING: Problems loading PRD file."
 Q
 ;
 ; ---- LTMP: Parse ^TMP and store into Exchange File ----
 ; This is a non-interactive version of LTMP^PXRMEXHF.
LTMP(SUCCESS,NODE) ;
 ; Note: sets LOADIEN in caller's frame with the IEN of the last
 ; successfully loaded entry (not NEW'd here on purpose).
 N CURRL,CSUM,DATEP,DONE,EXTYPE,FDA,IENROOT,IND,LINE
 N MSG,NENTRY,NLINES,RETMP,RNAME,SITE,SOURCE,SSOURCE,US,USER,VRSN
 S RETMP="^TMP($J,""EXLHF"")"
 S (CURRL,DONE,NENTRY,NLINES,SSOURCE)=0
 F  Q:DONE  D
 . S CURRL=CURRL+1
 . I '$D(^TMP($J,NODE,CURRL,1)) S DONE=1 Q
 . S LINE=^TMP($J,NODE,CURRL,1)
 . S NLINES=NLINES+1
 . S ^TMP($J,"EXLHF",NLINES,0)=LINE
 . I LINE["<PACKAGE_VERSION>" S VRSN=$$GETTAGV^PXRMEXU3(LINE,"<PACKAGE_VERSION>")
 . I LINE["<EXCHANGE_TYPE>" S EXTYPE=$$GETTAGV^PXRMEXU3(LINE,"<EXCHANGE_TYPE>",1)
 . I LINE="<SOURCE>" S SSOURCE=1
 . I SSOURCE D
 .. I LINE["<NAME>" S RNAME=$$GETTAGV^PXRMEXU3(LINE,"<NAME>",1)
 .. I LINE["<USER>" S USER=$$GETTAGV^PXRMEXU3(LINE,"<USER>",1)
 .. I LINE["<SITE>" S SITE=$$GETTAGV^PXRMEXU3(LINE,"<SITE>",1)
 .. I LINE["<DATE_PACKED>" S DATEP=$$GETTAGV^PXRMEXU3(LINE,"<DATE_PACKED>")
 . I LINE="</SOURCE>" D
 .. S SSOURCE=0
 .. S SOURCE=USER_" at "_SITE
 . ; End of one exchange entry - store it
 . I LINE="</REMINDER_EXCHANGE_FILE_ENTRY>" D
 .. S NLINES=0
 .. S NENTRY=NENTRY+1
 .. ; Validate format
 .. I ($G(^TMP($J,"EXLHF",1,0))'["xml")!($G(^TMP($J,"EXLHF",2,0))'="<REMINDER_EXCHANGE_FILE_ENTRY>") D  Q
 ... W !,"  ERROR: Malformed PRD entry #",NENTRY
 ... S SUCCESS=0
 .. ; Check for duplicates - skip silently if already loaded
 .. I $$REXISTS^PXRMEXIU(RNAME,DATEP) D
 ... W !,"  NOTE: ",RNAME," (packed ",DATEP,") already in Exchange File - skipping load."
 ... S SUCCESS(NENTRY)=1
 .. E  D
 ... ; Create the Exchange File entry
 ... K FDA,IENROOT
 ... S FDA(811.8,"+1,",.01)=RNAME
 ... S FDA(811.8,"+1,",.02)=SOURCE
 ... S FDA(811.8,"+1,",.03)=DATEP
 ... D UPDATE^PXRMEXPU(.US,.FDA,.IENROOT)
 ... S SUCCESS(NENTRY)=US
 ... I US D
 .... ; Store description and data
 .... N DESCT,DESL,KEYWORDT
 .... D DESC^PXRMEXU3(RETMP,.DESCT)
 .... D KEYWORD^PXRMEXU3(RETMP,.KEYWORDT)
 .... S DESL("RNAME")=RNAME,DESL("SOURCE")=SOURCE,DESL("DATEP")=DATEP
 .... S DESL("VRSN")=$G(VRSN)
 .... D DESC^PXRMEXU1(IENROOT(1),.DESL,"DESCT","KEYWORDT")
 .... ; Copy the packed data into 811.8
 .... M ^PXD(811.8,IENROOT(1),100)=^TMP($J,"EXLHF")
 .... ; Save the IEN for the caller
 .... S LOADIEN=IENROOT(1)
 .... W !,"  Stored entry: ",RNAME," (IEN=",IENROOT(1),")"
 ... E  D
 .... W !,"  ERROR: Failed to create entry for ",RNAME
 .. K ^TMP($J,"EXLHF")
 ;
 ; Determine overall success
 K ^TMP($J,NODE),^TMP($J,"EXLHF")
 I NENTRY=0 S SUCCESS=0 Q
 S SUCCESS=1
 S IND=""
 F  S IND=$O(SUCCESS(IND)) Q:+IND=0  D
 . I 'SUCCESS(IND) S SUCCESS=0
 Q
 ;
 ; ---- Install all components from an Exchange File entry ----
INSTALL(RIEN) ;
 ; This wraps INSTALL^PXRMEXSI which is the official VistA silent
 ; installer for exchange entries. It handles:
 ;   - Building the component list (CLIST^PXRMEXCO)
 ;   - Building the selectable list (CDISP^PXRMEXLC)
 ;   - Installing routines, file entries, dialogs
 ;   - Saving installation history
 ;
 N PXRMRIEN,PXRMINST,PXRMIGDS,PXRMINCF,PXRMEXCH
 S U="^"
 D CHKDUZ
 S PXRMRIEN=RIEN
 ; PXRMEXCH=1 tells input transforms this is a Reminder Exchange import
 ; which bypasses sponsor/class validation in VSPONSOR^PXINPTR
 S PXRMEXCH=1
 ; PXRMINST=1 tells the system this is a patch/KIDS-like install
 ; which enables installation of national components
 S PXRMINST=1
 ; PXRMIGDS allows overwriting standard entries
 S PXRMIGDS=1
 ; PXRMINCF allows installation of national computed findings
 S PXRMINCF=1
 ;
 ; Use the official silent installer
 ; Action "I" = Install (new items get installed, existing get overwritten)
 ; NOCF=0 (do install computed findings)
 ; NOR=0 (do install routines)
 W !,"  Calling INSTALL^PXRMEXSI..."
 D INSTALL^PXRMEXSI(PXRMRIEN,"I",0,0)
 W !,"  Install completed for entry IEN ",RIEN,"."
 ;
 ; Verify installation by checking the install history
 N HISTCNT
 S HISTCNT=+$P($G(^PXD(811.8,RIEN,130,0)),U,4)
 I HISTCNT>0 D
 . W !,"  Installation history records: ",HISTCNT
 E  D
 . W !,"  WARNING: No installation history found - install may have had issues."
 Q
 ;
 ; ---- Find the most recently added Exchange File entry ----
FINDLAST() ;
 ; Walk ^PXD(811.8) to find the highest numeric IEN
 N LASTIEN,IEN
 S U="^",LASTIEN=""
 ; Use the 0-node piece 3 which stores the last IEN assigned
 S LASTIEN=+$P($G(^PXD(811.8,0)),U,3)
 I LASTIEN>0,$D(^PXD(811.8,LASTIEN,0)) Q LASTIEN
 ; Fallback: walk backwards looking for a numeric IEN with data
 S IEN=""
 F  S IEN=$O(^PXD(811.8,IEN),-1) Q:IEN=""  D  Q:LASTIEN'=""
 . Q:+IEN'=IEN
 . I $D(^PXD(811.8,IEN,0)) S LASTIEN=IEN
 I LASTIEN="" Q ""
 Q LASTIEN
 ;
 ; ---- List all Exchange File entries ----
LIST ;
 N IEN,NAME,SOURCE,DATEP,CNT
 S U="^"
 W !,"=== Reminder Exchange File Entries (811.8) ==="
 S (IEN,CNT)=0
 F  S IEN=$O(^PXD(811.8,IEN)) Q:'IEN  D
 . Q:'$D(^PXD(811.8,IEN,0))
 . S CNT=CNT+1
 . S NAME=$P(^PXD(811.8,IEN,0),U,1)
 . S SOURCE=$P(^PXD(811.8,IEN,0),U,2)
 . S DATEP=$P(^PXD(811.8,IEN,0),U,3)
 . W !,IEN,?8,NAME
 . W !,?8,"  Source: ",SOURCE,"  Packed: ",$$FMTE^XLFDT(DATEP,"5Z")
 I CNT=0 W !,"  (no entries found)"
 W !,"=== Total: ",CNT," entries ===",!
 Q
 ;
 ; ---- Ensure DUZ is set ----
CHKDUZ ;
 ; DUZ (the user identifier) is required by the install routines.
 ; If we're running non-interactively, set it to a valid user.
 S U="^"
 I $G(DUZ)>0 Q
 ;
 W !,"  Setting up DUZ for non-interactive operation..."
 ; Find the first user with programmer access
 N IEN,ACCESS
 S IEN=0
 F  S IEN=$O(^VA(200,IEN)) Q:'IEN  D  Q:$G(DUZ)>0
 . S ACCESS=$P($G(^VA(200,IEN,0)),U,4)
 . I ACCESS["@" D
 .. S DUZ=IEN
 .. S DUZ(0)="@"
 .. W !,"  DUZ set to ",DUZ," (",$P(^VA(200,IEN,0),U,1),")"
 ;
 I '$G(DUZ) D
 . ; Fallback: use IEN 1 if it exists
 . I $D(^VA(200,1,0)) S DUZ=1,DUZ(0)="@"
 . E  D
 .. ; Last resort: just set DUZ=1
 .. S DUZ=1,DUZ(0)="@"
 . W !,"  DUZ set to ",DUZ," (fallback)"
 Q
 ;
