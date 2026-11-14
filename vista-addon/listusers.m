listusers ; List VistA users with access codes
 N I,N,A,V
 W "=== VistA User Accounts ===",!
 S I=0
 F  S I=$O(^VA(200,I)) Q:I=""  D
 . S N=$P($G(^VA(200,I,0)),"^",1)
 . S A=$P($G(^VA(200,I,.1)),"^",2)
 . I A'="" W I," ",N," | ACCESS CODE: ",A,!
 W "=== End of User List ===",!
 Q
