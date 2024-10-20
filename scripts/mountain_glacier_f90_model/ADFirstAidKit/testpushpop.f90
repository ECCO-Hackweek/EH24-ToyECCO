!                TESTING TAPENADE PUSH/POP MECHANISM
!     ===========================================================
!
! Tests randomly chosen sequences of PUSH/POP, on randomly chosen
! scalars and arrays of random types. Tests PUSH/POP sequences that
! happen during checkpointing. Tests the "repeated access" mechanism
! that is necessary for snapshot-LOOK and for Fixed-point adjoints.
!
! Does not test pointer PUSH/POP. Anyway, here we are only concerned
! with sizes, so testing on int*8 and int*4 should test just as well.
!
! This test is random: generates PUSH/POP of random sequences of variables.
! The sequence of variables corresponding to a "*" or a "(" in the
! CODE structure string depends only on the SEED and on the position of the
! symbol in the CODE string.
! The test will be identical for identical CODE string and SEED.
!
! Syntax: $> testpushpop <T for trace> "<CodeStructure>" <seed>
!  -- 1st arg forces trace when given T
!  -- 2nd arg is the CODE structure string
!    -- * is a plain code portion, causing PUSH and POP of a sequence of variables
!    -- (CODE) is a checkpointed CODE, implying a snapshot
!    -- L(CODE) is a checkpointed CODE with a bwd and a fwd snapshots
!      * fwd snapshot sequence depends on the position of the "("
!      * bwd snapshot sequence depends on the position of the "L"
!    -- n[CODE] tells that the bwd sweep of CODE will be accessed repeatedly n times,
!      thus reading n times each pushed value.
!  -- 3rd arg is the SEED for random
!
! Compiling: $> gfortran testpushpop.f90 adStack.c -o testpushpop
!
! Running (see testpushpop.sh): $> testpushpop.sh | grep Error

MODULE TESTPUSHPOPUTILS

  LOGICAL :: TRACEON = .false.
  LOGICAL :: TRACEDRY = .false.
  LOGICAL :: INTERMEDIATEFILE = .false.

  INTEGER*4 :: ARRAYI4(5000), RECVARRAYI4(5000)
  INTEGER*8 :: ARRAYI8(5000), RECVARRAYI8(5000)
  REAL*4    :: ARRAYR4(5000), RECVARRAYR4(5000)
  REAL*8    :: ARRAYR8(5000), RECVARRAYR8(5000)
  COMPLEX*8    :: ARRAYC8(5000), RECVARRAYC8(5000)
  COMPLEX*16    :: ARRAYC16(5000), RECVARRAYC16(5000)
  CHARACTER(len=5000) :: ARRAYCHAR, RECVARRAYCHAR
  INTEGER*4 :: FLOWDIRECTION, RECVFLOWDIRECTION
  LOGICAL :: BOOLEAN, RECVBOOLEAN

  CHARACTER(len=500) :: givenCode
  INTEGER :: codeLength

  INTEGER*4 :: givenSeed, seed1, seed2, seedForFile

  ! proportions in % of int4,+int8,+real4,+real8,+complex8,+complex16,+characters,+bits
  ! the last one, being the total of all, must be 100:
  INTEGER :: trajtypes(8)=(/30,35,50,80,83,85,90,100/)
  INTEGER ::  snptypes(8)=(/30,35,55,90,93,95,100,100/)
  INTEGER :: snpatypes(8)=(/30,35,55,90,93,95,100,100/)
  INTEGER :: snpbtypes(8)=(/30,35,55,90,93,95,100,100/)

CONTAINS
  ! My pseudo-random generator. Can probably be improved!
  SUBROUTINE nextrandom(seed)
    INTEGER*4 :: seed
    seed = MOD(seed*(1+seed), 32768)
  END SUBROUTINE nextrandom

  ! Random integer between 0 and imax-1 using random seed1 :
  INTEGER*4 FUNCTION drawinteger(imax)
    INTEGER :: imax
    CALL nextrandom(seed1)
    drawinteger = MOD(seed1,imax)
  END FUNCTION drawinteger

  ! returns the value of random seed1 :
  INTEGER*4 FUNCTION getseed1()
    getseed1 = seed1
  END FUNCTION getseed1

  REAL*8 FUNCTION mkr8(seed,mult)
    INTEGER :: seed
    REAL*8 :: mult, tmp
    tmp = seed*mult
    if (tmp<0) tmp=-tmp
    mkr8 = SQRT(tmp)
  END FUNCTION mkr8

  REAL*4 FUNCTION mkr4(seed,mult)
    INTEGER :: seed
    REAL*4 :: mult, tmp
    tmp = seed*mult
    if (tmp<0) tmp=-tmp
    mkr4 = SQRT(tmp)
  END FUNCTION mkr4

  ! All "fill" functions: for each basic type,
  ! (in int4, int8, real4, real8, complex8, complex16, characters, bits)
  ! fills (a "length" first elements of) this type's corresponding
  ! global storage variable with some pseudo-random values
  ! computed with internal random var "seed2", initialized with "seed".
  ! The "random" quality of these values is not very critical.

  SUBROUTINE fillboolean(seed)
    INTEGER :: seed,tmp
    seed2 = 2+4*seed
    seedForFile = MOD(seed2,10000)
    CALL nextrandom(seed2)
    if (seed2>=0) then
       tmp=seed2
    else
       tmp=-seed2
    endif
    BOOLEAN = (MOD(tmp,256).ge.128) !! Build a vaguely random boolean (i.e. LOGICAL)
  END SUBROUTINE fillboolean

  SUBROUTINE fillcontrolNb(length, seed)
    INTEGER :: length, seed, tmp
    seed2 = 2+4*seed
    seedForFile = MOD(seed2,10000)
    CALL nextrandom(seed2)
    if (seed2>=0) then
       tmp=seed2
    else
       tmp=-seed2
    endif
    FLOWDIRECTION = MOD(tmp,2**length) !! Build a vaguely random INTEGER*4 coded with "length" bits
  END SUBROUTINE fillcontrolNb

  SUBROUTINE fillchararray(length, seed)
    INTEGER :: length, seed, i, tmp
    seed2 = 2+4*seed
    seedForFile = MOD(seed2,10000)
    do i=1,length
       CALL nextrandom(seed2)
       if (seed2>=0) then
          tmp=seed2
       else
          tmp=-seed2
       endif
       ARRAYCHAR(i:i) = CHAR(33+MOD(tmp,94)) !! Build a vaguely random CHARACTER between ascii 33 and 126
    end do
  END SUBROUTINE fillchararray

  SUBROUTINE fillc8array(length, seed)
    INTEGER :: length, seed, i
    REAL*8 :: rpart, ipart
    seed2 = 2+4*seed
    seedForFile = MOD(seed2,10000)
    do i=1,length
       CALL nextrandom(seed2)
       rpart = mkr4(seed2,1.2_4) !! Build a vaguely random REAL*4
       CALL nextrandom(seed2)
       ipart = mkr4(seed2,1.2_4) !! Build a vaguely random REAL*4
       ARRAYC8(i) = CMPLX(rpart,ipart,8)
    end do
  END SUBROUTINE fillc8array

  SUBROUTINE fillc16array(length, seed)
    INTEGER :: length, seed, i
    REAL*8 :: rpart, ipart
    seed2 = 2+4*seed
    seedForFile = MOD(seed2,10000)
    do i=1,length
       CALL nextrandom(seed2)
       rpart = mkr8(seed2,1.2_8) !! Build a vaguely random REAL*8
       CALL nextrandom(seed2)
       ipart = mkr8(seed2,1.2_8) !! Build a vaguely random REAL*8
       ARRAYC16(i) = CMPLX(rpart,ipart,16)
    end do
  END SUBROUTINE fillc16array

  SUBROUTINE filli4array(length, seed)
    INTEGER :: length, seed, i
    seed2 = 2+4*seed
    seedForFile = MOD(seed2,10000)
    do i=1,length
       CALL nextrandom(seed2)
       ARRAYI4(i) = seed2 !! Build a vaguely random INTEGER*4
    end do
  END SUBROUTINE filli4array

  SUBROUTINE filli8array(length, seed)
    INTEGER :: length, seed, tmo
    seed2 = 2+4*seed
    seedForFile = MOD(seed2,10000)
    do i=1,length
       CALL nextrandom(seed2)
       if (seed2>=0) then
          tmp=seed2
       else
          tmp=-seed2
       endif
       ARRAYI8(i) = seed2*tmp !! Build a vaguely random INTEGER*8
    end do
  END SUBROUTINE filli8array

  SUBROUTINE fillr4array(length, seed)
    INTEGER :: length, seed, i
    seed2 = 2+4*seed
    seedForFile = MOD(seed2,10000)
    do i=1,length
       CALL nextrandom(seed2)
       ARRAYR4(i) = mkr4(seed2,1.2_4) !! Build a vaguely random REAL*4
    end do
  END SUBROUTINE fillr4array

  SUBROUTINE fillr8array(length, seed)
    INTEGER :: length, seed, i
    seed2 = 2+4*seed
    seedForFile = MOD(seed2,10000)
    do i=1,length
       CALL nextrandom(seed2)
       ARRAYR8(i) = mkr8(seed2,1.1_8) !! Build a vaguely random REAL*8
    end do
  END SUBROUTINE fillr8array

END MODULE TESTPUSHPOPUTILS

PROGRAM testpushpop
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER :: indexopen, indexclose
  CHARACTER(len=1) :: traceOnString
  CHARACTER(len=10) :: seedstring
  IF (iargc().ne.3) THEN
     print *,"Usage: testpushpop <0, or T for trace, C for generate C file", &
 &           ", S for summarize teststructure> ""<CodeStructure>"" <seed>"
  ELSE
     CALL get_command_argument(1,traceOnString)
     CALL get_command_argument(2,givenCode,codeLength)
     CALL get_command_argument(3,seedstring)
     READ (seedstring,'(I10)') givenSeed
     TRACEON = (traceOnString.eq.'T').or.(traceOnString.eq.'t').or.(traceOnString.eq.'1')
     TRACEDRY = (traceOnString.eq.'S').or.(traceOnString.eq.'s').or.(traceOnString.eq.'2')
     INTERMEDIATEFILE = (traceOnString.eq.'C').or.(traceOnString.eq.'c')
     WRITE(6,991) givenSeed,givenCode(1:codeLength)
     IF (INTERMEDIATEFILE) THEN
        open(1, file='pushPopSequence.c', status='replace')
        write(1, '("#include ""pushPopPreamble.h""")')
        write(1, '("")')
        write(1, '("int main(int argc, char *argv[]) {")')
     ENDIF
     CALL runsweep(givenCode(1:codeLength), 0, 1)
     !call adstack_showstacksize(99)
     !CALL EMITSHOWSTACK("middle"//CHAR(0)) !!Trace
     CALL runsweep(givenCode(1:codeLength), 0, -1)
     !CALL adstack_showpeaksize()
     IF (INTERMEDIATEFILE) THEN
        write(1, '("  if (hasError) printf(""Error found!\n""); else printf(""ok!\n"");")')
        write(1, '("  return hasError;")')
        write(1, '("}")')
        close(1)
     ENDIF
  END IF
 991  FORMAT('seed=',i4,' code=',a)
END PROGRAM testpushpop

SUBROUTINE getparenthindices(code,indexopen,indexclose)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  CHARACTER(len=*) :: code
  INTEGER indexopen, indexclose
  INTEGER index, length, depth

  length = LEN(code)
  index = 1
! Advance to the open parenth or square bracket:
  do while(index.le.length.and.code(index:index).ne.'('.and.code(index:index).ne.'[')
     index = index+1
  enddo
  indexopen = index
  index = index+1
  depth = 1
! Find the corresponding closing parenth or square bracket or the end of string:
  do while(index.le.length.and.(depth.ne.1.or.(code(index:index).ne.')'.and.code(index:index).ne.']')))
     if (code(index:index).eq.'('.or.code(index:index).eq.'[') then
        depth = depth+1
     else if (code(index:index).eq.')'.or.code(index:index).eq.']') then
        depth = depth-1
     end if
     index = index+1
  enddo
  if (index.eq.length+1.and.depth.ne.0) then
     print *,'Missing closing in CodeStructure'
  end if
  indexclose = index
END SUBROUTINE getparenthindices

RECURSIVE SUBROUTINE runsweep(code, globaloffset, direction)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  CHARACTER(len=*) code
  INTEGER globaloffset, totaloffset, direction
  INTEGER index, length, repeat
  INTEGER indexopen, indexclose
  INTEGER ii
  !print *,'            runsweep on ',code,' offset:',globaloffset
  repeat = -1
  index = 1
  length = LEN(code)
! Skip white spaces:
  do while(index.le.length.and.(code(index:index).eq.' '.or.code(index:index).eq.'     '))
     index = index+1
  enddo
  totaloffset = globaloffset+index

! The next token is either '(' or 'endOfString' or [1..9] or '*' or 'L'
  if (index.gt.length) then
!   do nothing and return.

! CHECKPOINT WITH LOOK SNAPSHOT MECHANISM:
  else if (code(index:index).eq.'L') then
     CALL getparenthindices(code(index+1:),indexopen,indexclose)
     if (direction.eq.1) then
        CALL emitpushpopsequence(totaloffset, 10, snpatypes, 60, 1,'TAKE SNP A at',2)
        CALL emitpushpopsequence(totaloffset+indexopen, 10, snpbtypes, 70, 1,'TAKE SNP B at',2)
     end if
     CALL runsweep(code(index+indexclose+1:), totaloffset+indexclose, direction)
     if (direction.eq.-1) then
        CALL emitpushpopsequence(totaloffset+indexopen, 10, snpbtypes, 70, -1,' POP SNP B at',-2)
        CALL emitstartrepeat()
        CALL emitpushpopsequence(totaloffset, 10, snpatypes, 60, -1,'LOOK SNP A at',-3)
        CALL emitresetrepeat()
        CALL emitendrepeat()
        CALL runsweep(code(index+indexopen+1:index+indexclose-1), totaloffset+indexopen, 1)
        CALL runsweep(code(index+indexopen+1:index+indexclose-1), totaloffset+indexopen, -1)
        CALL emitpushpopsequence(totaloffset, 10, snpatypes, 60, -1,' POP SNP A at',-2)
     end if

! CHECKPOINT WITH PLAIN PUSH-POP SNAPSHOT:
  else if (code(index:index).eq.'(') then
     CALL getparenthindices(code(index:),indexopen,indexclose)
     if (direction.eq.1) then
        CALL emitpushpopsequence(totaloffset, 20, snptypes, 70, 1,'TAKE SNP at',2)
     end if
     CALL runsweep(code(index-1+indexclose+1:), totaloffset-1+indexclose, direction)
     if (direction.eq.-1) then
        CALL emitpushpopsequence(totaloffset, 20, snptypes, 70, -1,' POP SNP at',-2)
        CALL runsweep(code(index-1+indexopen+1:index-1+indexclose-1), totaloffset-1+indexopen, 1)
        CALL runsweep(code(index-1+indexopen+1:index-1+indexclose-1), totaloffset-1+indexopen, -1)
     end if

! PLAIN CODE:
  else if (code(index:index).eq.'*') then
     if (direction.eq.1) then
        CALL emitpushpopsequence(totaloffset, 80, trajtypes, 25, 1,'PUSHes part',1)
     end if
     CALL runsweep(code(index+1:), totaloffset, direction)
     if (direction.eq.-1) then
        CALL emitpushpopsequence(totaloffset, 80, trajtypes, 25, -1,'  POPs part',-1)
     end if

! CODE WITH ONE PUSH AND REPEATED POPS (e.g. FIXED-POINT ADJOINT):
  else if (code(index:index).gt.'0'.and.code(index:index).le.'9') then
     READ (code(index:index),'(I1)') repeat
     CALL getparenthindices(code(index+1:),indexopen,indexclose)
     if (direction.eq.1) then
        CALL runsweep(code(index-1+indexopen+2:index+indexclose-1), totaloffset+indexopen, 1)
     endif
     CALL runsweep(code(index+indexclose+1:), totaloffset+indexclose, direction)
     if (direction.eq.-1) then
        CALL emitstartrepeat()
        DO ii=1,repeat
           CALL runsweep(code(index-1+indexopen+2:index+indexclose-1), totaloffset+indexopen, -1)
           if (ii.ne.repeat) then
              CALL emitresetrepeat()
           else
              CALL emitendrepeat()
           endif
        ENDDO
     end if

  else
     print *,'Unexpected CodeStructure substring:',code(index:)
  end if
END SUBROUTINE runsweep

! index is the index in the code string of the "*" that stands
!  for this pushpop sequence. Index is used as the random seed.
! ppmax is the max number of push'es or pop's in sequence
! proportiontypes is the array of proportions in % of
! (int4,+int8,+real4,+real8,+complex8,+complex16,+characters,+bits)
! the last one, being the total of all, must be 100.
! action is 1 for PUSH and -1 for POP
SUBROUTINE emitpushpopsequence(index, ppmax, proportiontypes, proportionarrays, action, msg, op)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER :: index, ppmax, proportiontypes(8), proportionarrays, action, op
  CHARACTER(*) :: msg
  INTEGER :: number, sort, isarray, arraylen, i
  INTEGER :: sorts(200), sizes(200), seeds(200)
  INTEGER :: iterfrom, iterto, iterstride
  ! initialize random seed1 using only index & givenSeed
  seed1 = 2+4*index*(givenSeed+index)
  number = drawinteger(ppmax)
 if (TRACEDRY) then
    if (action.eq.1) then
       print *,'PUSH',number,'objects, with random seeds',index,seed1
    else
       print *,' POP',number,'objects, with random seeds',index,seed1
    endif
 else
  DO i=1,number
     sort = drawinteger(100)
     if (sort<proportiontypes(1)) then
        sorts(i) = 1
     else if (sort<proportiontypes(2)) then
        sorts(i) = 2
     else if (sort<proportiontypes(3)) then
        sorts(i) = 3
     else if (sort<proportiontypes(4)) then
        sorts(i) = 4
     else if (sort<proportiontypes(5)) then
        sorts(i) = 5
     else if (sort<proportiontypes(6)) then
        sorts(i) = 6
     else if (sort<proportiontypes(7)) then
        sorts(i) = 7
     else
        sorts(i) = 8
     endif
     isarray = drawinteger(100)
     if (isarray<proportionarrays) then
        if (sorts(i).eq.8) then
           !Case of push/pop control, limited to 6 bits:
           arraylen = drawinteger(6) !!Suggested 6
        else if (sorts(i).eq.7) then
           !Case of push/pop character arrays, limited to 80 bytes:
           arraylen = drawinteger(80) !!Suggested 80
        else
           arraylen = drawinteger(33) !!Suggested 33
           if (arraylen.ge.30) then
              arraylen = (arraylen-30)*1000 + drawinteger(999)
           else if (arraylen.ge.20) then
              arraylen = (arraylen-20)*100 + drawinteger(99)
           else if (arraylen.ge.10) then
              arraylen = (arraylen-10)*10 + drawinteger(9)
           end if
        endif
     else
        arraylen = -1 !Means scalar
     endif
     sizes(i) = arraylen
     seeds(i) = getseed1()+index
  END DO
  !CALL SHOWPUSHPOPSEQUENCE(op, index, number, sorts, sizes) !!Trace
  if (action.eq.1) then
     iterfrom=1
     iterto=number
     iterstride=1
  else
     iterfrom=number
     iterto=1
     iterstride=-1
  endif
  DO i=iterfrom,iterto,iterstride
     SELECT CASE (sorts(i))
     CASE (1) !int4
        if (sizes(i).eq.-1) then
           call filli4array(1, seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushi4scalar()
           else                               ! POP
              CALL emitpopi4scalar()
           endif
        else
           call filli4array(sizes(i), seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushi4array(sizes(i))
           else                               ! POP
              CALL emitpopi4array(sizes(i))
           endif
        endif
     CASE (2) !int8
        if (sizes(i).eq.-1) then
           call filli8array(1, seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushi8scalar()
           else                               ! POP
              CALL emitpopi8scalar()
           endif
        else
           call filli8array(sizes(i), seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushi8array(sizes(i))
           else                               ! POP
              CALL emitpopi8array(sizes(i))
           endif
        endif
     CASE (3) !real4
        if (sizes(i).eq.-1) then
           call fillr4array(1, seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushr4scalar()
           else                               ! POP
              CALL emitpopr4scalar()
           endif
        else
           call fillr4array(sizes(i), seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushr4array(sizes(i))
           else                               ! POP
              CALL emitpopr4array(sizes(i))
           endif
        endif
     CASE (4) !real8
        if (sizes(i).eq.-1) then
           call fillr8array(1, seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushr8scalar()
           else                               ! POP
              CALL emitpopr8scalar()
           endif
        else
           call fillr8array(sizes(i), seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushr8array(sizes(i))
           else                               ! POP
              CALL emitpopr8array(sizes(i))
           endif
        endif
     CASE (5) !complex8
        if (sizes(i).eq.-1) then
           call fillc8array(1, seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushc8scalar()
           else                               ! POP
              CALL emitpopc8scalar()
           endif
        else
           call fillc8array(sizes(i), seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushc8array(sizes(i))
           else                               ! POP
              CALL emitpopc8array(sizes(i))
           endif
        endif
     CASE (6) !complex16
        if (sizes(i).eq.-1) then
           call fillc16array(1, seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushc16scalar()
           else                               ! POP
              CALL emitpopc16scalar()
           endif
        else
           call fillc16array(sizes(i), seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushc16array(sizes(i))
           else                               ! POP
              CALL emitpopc16array(sizes(i))
           endif
        endif
     CASE (7) !characters
        if (sizes(i).eq.-1) then
           call fillchararray(1, seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushcharacter()
           else                               ! POP
              CALL emitpopcharacter()
           endif
        else
           call fillchararray(sizes(i), seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushcharacterarray(sizes(i))
           else                               ! POP
              CALL emitpopcharacterarray(sizes(i))
           endif
        endif
     CASE (8) !bits or control-flow directions
        if (sizes(i).le.0) then !bits
           call fillboolean(seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushboolean()
           else                               ! POP
              CALL emitpopboolean()
           endif
        else  !control-flow directions
           call fillcontrolNb(sizes(i), seeds(i))
           if (action.eq.1) then              ! PUSH
              call emitpushcontrolNb(sizes(i))
           else                               ! POP
              CALL emitpopcontrolNb(sizes(i))
           endif
        endif
     END SELECT
  END DO
  !CALL EMITSHOWSTACKSIZE() ; !!Trace
 endif
END SUBROUTINE emitpushpopsequence

SUBROUTINE emitpushboolean()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'PUSHBOOLEAN(',BOOLEAN,') AT ',LOCSTRB(),LOCSTRO()
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillBoolean(",I4,"); pushBoolean(Boolean);")') &
 &        seedForFile
  ELSE
     CALL PUSHBOOLEAN(BOOLEAN)
  ENDIF
END SUBROUTINE emitpushboolean

SUBROUTINE emitpopboolean()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillBoolean(",I4,"); popBoolean(&recvBoolean); testBoolean();")') &
 &        seedForFile
  ELSE
     CALL POPBOOLEAN(RECVBOOLEAN)
     IF (TRACEON) print *,'POPBOOLEAN(',RECVBOOLEAN,') AT ',LOCSTRB(),LOCSTRO()  
     if (RECVBOOLEAN.neqv.BOOLEAN) then
        print *,'Error boolean pushed ',BOOLEAN,' popped ',RECVBOOLEAN,   &
 &              ' seed:',givenSeed,' code:',givenCode(1:codeLength)
        stop
     end if
  ENDIF
END SUBROUTINE emitpopboolean

SUBROUTINE emitpushcontrolNb(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER size
  SELECT CASE (size)
  CASE (1)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 1,",I4,"); pushControl1b(Control);")') &
 &        seedForFile
     ELSE
        CALL PUSHCONTROL1B(FLOWDIRECTION)
     ENDIF
  CASE (2)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 2,",I4,"); pushControl2b(Control);")') &
 &        seedForFile
     ELSE
        CALL PUSHCONTROL2B(FLOWDIRECTION)
     ENDIF
  CASE (3)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 3,",I4,"); pushControl3b(Control);")') &
 &        seedForFile
     ELSE
        CALL PUSHCONTROL3B(FLOWDIRECTION)
     ENDIF
  CASE (4)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 4,",I4,"); pushControl4b(Control);")') &
 &        seedForFile
     ELSE
        CALL PUSHCONTROL4B(FLOWDIRECTION)
     ENDIF
  CASE (5)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 5,",I4,"); pushControl5b(Control);")') &
 &        seedForFile
     ELSE
        CALL PUSHCONTROL5B(FLOWDIRECTION)
     ENDIF
  CASE (6)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 6,",I4,"); pushControl6b(Control);")') &
 &        seedForFile
     ELSE
        CALL PUSHCONTROL6B(FLOWDIRECTION)
     ENDIF
  CASE (7)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 7,",I4,"); pushControl7b(Control);")') &
 &        seedForFile
     ELSE
        CALL PUSHCONTROL7B(FLOWDIRECTION)
     ENDIF
  CASE (8)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 8,",I4,"); pushControl8b(Control);")') &
 &        seedForFile
     ELSE
        CALL PUSHCONTROL8B(FLOWDIRECTION)
     ENDIF
  END SELECT
END SUBROUTINE emitpushcontrolNb

SUBROUTINE emitpopcontrolNb(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER :: size
  SELECT CASE (size)
  CASE (1)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 1,",I4,"); popControl1b(&recvControl); testCtrl(1);")') &
 &        seedForFile
     ELSE
        CALL POPCONTROL1B(RECVFLOWDIRECTION)
     ENDIF
  CASE (2)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 2,",I4,"); popControl2b(&recvControl); testCtrl(2);")') &
 &        seedForFile
     ELSE
        CALL POPCONTROL2B(RECVFLOWDIRECTION)
     ENDIF
  CASE (3)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 3,",I4,"); popControl3b(&recvControl); testCtrl(3);")') &
 &        seedForFile
     ELSE
        CALL POPCONTROL3B(RECVFLOWDIRECTION)
     ENDIF
  CASE (4)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 4,",I4,"); popControl4b(&recvControl); testCtrl(4);")') &
 &        seedForFile
     ELSE
        CALL POPCONTROL4B(RECVFLOWDIRECTION)
     ENDIF
  CASE (5)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 5,",I4,"); popControl5b(&recvControl); testCtrl(5);")') &
 &        seedForFile
     ELSE
        CALL POPCONTROL5B(RECVFLOWDIRECTION)
     ENDIF
  CASE (6)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 6,",I4,"); popControl6b(&recvControl); testCtrl(6);")') &
 &        seedForFile
     ELSE
        CALL POPCONTROL6B(RECVFLOWDIRECTION)
     ENDIF
  CASE (7)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 7,",I4,"); popControl7b(&recvControl); testCtrl(7);")') &
 &        seedForFile
     ELSE
        CALL POPCONTROL7B(RECVFLOWDIRECTION)
     ENDIF
  CASE (8)
     IF (INTERMEDIATEFILE) THEN
        write(1,'("  fillCtrl( 8,",I4,"); popControl8b(&recvControl); testCtrl(8);")') &
 &        seedForFile
     ELSE
        CALL POPCONTROL8B(RECVFLOWDIRECTION)
     ENDIF
  END SELECT
  IF (.not.INTERMEDIATEFILE) THEN
     if (RECVFLOWDIRECTION.ne.FLOWDIRECTION) then
        print *,'Error flow direction pushed ',FLOWDIRECTION,' popped ',RECVFLOWDIRECTION,   &
 &              ' seed:',givenSeed,' code:',givenCode(1:codeLength)
        CALL SHOWERRORCONTEXT()
        stop
     end if
  ENDIF
END SUBROUTINE emitpopcontrolNb

SUBROUTINE emitpushcharacter()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillCh(  01,",I4,"); pushCharacter(ArrayChar[0]);")') &
 &        seedForFile
  ELSE
     CALL PUSHCHARACTER(ARRAYCHAR(1:1))
  ENDIF
END SUBROUTINE emitpushcharacter

SUBROUTINE emitpopcharacter()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillCh(  01,",I4,"); popCharacter(&recvArrayChar[0]); testCh(1);")') &
 &        seedForFile
  ELSE
     CALL POPCHARACTER(RECVARRAYCHAR(1:1))
     if (RECVARRAYCHAR(1:1).ne.ARRAYCHAR(1:1)) then
        print *,'Error character pushed ',ARRAYCHAR(1:1),' popped ',RECVARRAYCHAR(1:1),   &
 &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
        CALL SHOWERRORCONTEXT()
        stop
     end if
  ENDIF
END SUBROUTINE emitpopcharacter

SUBROUTINE emitpushcharacterarray(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER size
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillCh(",I4,",",I4,"); pushCharacterArray(ArrayChar,",I4,");")') &
 &        size,seedForFile,size
  ELSE
     CALL PUSHCHARACTERARRAY(ARRAYCHAR, size)
  ENDIF
END SUBROUTINE emitpushcharacterarray

SUBROUTINE emitpopcharacterarray(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER :: size
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillCh(",I4,",",I4,"); popCharacterArray(recvArrayChar,",I4,"); testCh(",I4,");")') &
 &        size,seedForFile,size,size
  ELSE
     CALL POPCHARACTERARRAY(RECVARRAYCHAR, size)
     if (RECVARRAYCHAR(1:size).ne.ARRAYCHAR(1:size)) then
        print *,'Error character array pushed ',ARRAYCHAR(1:size),' popped ',RECVARRAYCHAR(1:size),   &
 &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
        CALL SHOWERRORCONTEXT()
        stop
     end if
  ENDIF
END SUBROUTINE emitpopcharacterarray

SUBROUTINE emitpushc8scalar()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'PUSHCOMPLEX8(',ARRAYC8(1),') AT ',LOCSTRB(),LOCSTRO()
  IF (INTERMEDIATEFILE) THEN
! Commented out because C has no complex8 (sizeof(complex) == sizeof(double complex) == 16)
!     write(1,'("  fillc8(  01,",I4,"); pushComplex8(ArrayC8[0]);")') &
! &        seedForFile
  ELSE
     CALL PUSHCOMPLEX8(ARRAYC8(1))
  ENDIF
END SUBROUTINE emitpushc8scalar

SUBROUTINE emitpopc8scalar()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (INTERMEDIATEFILE) THEN
! Commented out because C has no complex8 (sizeof(complex) == sizeof(double complex) == 16)
!     write(1,'("  fillc8(  01,",I4,"); popComplex8(&recvArrayC8[0]); testc8(1);")') &
! &        seedForFile
  ELSE
     CALL POPCOMPLEX8(RECVARRAYC8(1))
     IF (TRACEON) print *,'POPCOMPLEX8(',RECVARRAYC8(1),') AT ',LOCSTRB(),LOCSTRO()
     if (RECVARRAYC8(1).ne.ARRAYC8(1)) then
        print *,'Error complex8 scalar pushed ',ARRAYC8(1),' popped ',RECVARRAYC8(1),   &
             &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
        CALL SHOWERRORCONTEXT()
        stop
     end if
  ENDIF
END SUBROUTINE emitpopc8scalar

SUBROUTINE emitpushc8array(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER size
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'PUSHCOMPLEX8ARRAY(',size,":",ARRAYC8(1),'...) AT ',LOCSTRB(),LOCSTRO()
  IF (INTERMEDIATEFILE) THEN
! Commented out because C has no complex8 (sizeof(complex) == sizeof(double complex) == 16)
!     write(1,'("  fillc8(",I4,",",I4,"); pushComplex8Array(ArrayC8,",I4,");")') &
! &        size,seedForFile,size
  ELSE
     CALL PUSHCOMPLEX8ARRAY(ARRAYC8, size)
  ENDIF
END SUBROUTINE emitpushc8array

SUBROUTINE emitpopc8array(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER :: size, i
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (INTERMEDIATEFILE) THEN
! Commented out because C has no complex8 (sizeof(complex) == sizeof(double complex) == 16)
!     write(1,'("  fillc8(",I4,",",I4,"); popComplex8Array(recvArrayC8,",I4,"); testc8(",I4,");")') &
! &        size,seedForFile,size,size
  ELSE
     CALL POPCOMPLEX8ARRAY(RECVARRAYC8, size)
     IF (TRACEON) print *,'POPCOMPLEX8ARRAY(',size,":",RECVARRAYC8(1),'...) AT ',LOCSTRB(),LOCSTRO()
     DO i=size,1,-1
        if (RECVARRAYC8(i).ne.ARRAYC8(i)) then
           print *,'Error complex8 array elem ',i,' pushed ',ARRAYC8(i),' popped ',RECVARRAYC8(i),   &
 &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
           CALL SHOWERRORCONTEXT()
           stop
        end if
     END DO
  ENDIF
END SUBROUTINE emitpopc8array

SUBROUTINE emitpushc16scalar()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'PUSHCOMPLEX16(',ARRAYC16(1),') AT ',LOCSTRB(),LOCSTRO()
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillc16(  01,",I4,"); pushComplex16(ArrayC16[0]);")') &
 &        seedForFile
  ELSE
     CALL PUSHCOMPLEX16(ARRAYC16(1))
  ENDIF
END SUBROUTINE emitpushc16scalar

SUBROUTINE emitpopc16scalar()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillc16(  01,",I4,"); popComplex16(&recvArrayC16[0]); testc16(1);")') &
 &        seedForFile
  ELSE
     CALL POPCOMPLEX16(RECVARRAYC16(1))
     IF (TRACEON) print *,'POPCOMPLEX16(',RECVARRAYC16(1),') AT ',LOCSTRB(),LOCSTRO()
     if (RECVARRAYC16(1).ne.ARRAYC16(1)) then
        print *,'Error complex16 scalar pushed ',ARRAYC16(1),' popped ',RECVARRAYC16(1),   &
 &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
        CALL SHOWERRORCONTEXT()
        stop
     end if
  ENDIF
END SUBROUTINE emitpopc16scalar

SUBROUTINE emitpushc16array(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER size
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'PUSHCOMPLEX16ARRAY(',size,":",ARRAYC16(1),'...) AT ',LOCSTRB(),LOCSTRO()
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillc16(",I4,",",I4,"); pushComplex16Array(ArrayC16,",I4,");")') &
 &        size,seedForFile,size
  ELSE
     CALL PUSHCOMPLEX16ARRAY(ARRAYC16, size)
  ENDIF
END SUBROUTINE emitpushc16array

SUBROUTINE emitpopc16array(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER :: size, i
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillc16(",I4,",",I4,"); popComplex16Array(recvArrayC16,",I4,"); testc16(",I4,");")') &
 &        size,seedForFile,size,size
  ELSE
     CALL POPCOMPLEX16ARRAY(RECVARRAYC16, size)
     IF (TRACEON) print *,'POPCOMPLEX16ARRAY(',size,":",RECVARRAYC16(1),'...) AT ',LOCSTRB(),LOCSTRO()
     DO i=size,1,-1
        if (RECVARRAYC16(i).ne.ARRAYC16(i)) then
           print *,'Error complex16 array elem ',i,' pushed ',ARRAYC16(i),' popped ',RECVARRAYC16(i),   &
 &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
           CALL SHOWERRORCONTEXT()
           stop
        end if
     END DO
  ENDIF
END SUBROUTINE emitpopc16array

SUBROUTINE emitpushr4scalar()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'PUSHREAL4(',ARRAYR4(1),') AT ',LOCSTRB(),LOCSTRO()
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillr4(  01,",I4,"); pushReal4(ArrayR4[0]);")') &
 &        seedForFile
  ELSE
     CALL PUSHREAL4(ARRAYR4(1))
  ENDIF
END SUBROUTINE emitpushr4scalar

SUBROUTINE emitpopr4scalar()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillr4(  01,",I4,"); popReal4(&recvArrayR4[0]); testr4(1);")') &
 &        seedForFile
  ELSE
     CALL POPREAL4(RECVARRAYR4(1))
     IF (TRACEON) print *,'POPREAL4(',RECVARRAYR4(1),') AT ',LOCSTRB(),LOCSTRO()
     if (RECVARRAYR4(1).ne.ARRAYR4(1)) then
        print *,'Error real4 scalar pushed ',ARRAYR4(1),' popped ',RECVARRAYR4(1),   &
 &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
        CALL SHOWERRORCONTEXT()
        stop
     end if
  ENDIF
END SUBROUTINE emitpopr4scalar

SUBROUTINE emitpushr4array(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER size
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'PUSHREAL4ARRAY(',size,":",ARRAYR4(1),'...) AT ',LOCSTRB(),LOCSTRO()
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillr4(",I4,",",I4,"); pushReal4Array(ArrayR4,",I4,");")') &
 &        size,seedForFile,size
  ELSE
     CALL PUSHREAL4ARRAY(ARRAYR4, size)
  ENDIF
END SUBROUTINE emitpushr4array

SUBROUTINE emitpopr4array(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER :: size, i
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillr4(",I4,",",I4,"); popReal4Array(recvArrayR4,",I4,"); testr4(",I4,");")') &
 &        size,seedForFile,size,size
  ELSE
     CALL POPREAL4ARRAY(RECVARRAYR4, size)
     IF (TRACEON) print *,'POPREAL4ARRAY(',size,":",RECVARRAYR4(1),'...) AT ',LOCSTRB(),LOCSTRO()
     DO i=size,1,-1
        if (RECVARRAYR4(i).ne.ARRAYR4(i)) then
           print *,'Error real4 array elem ',i,' pushed ',ARRAYR4(i),' popped ',RECVARRAYR4(i),   &
 &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
           CALL SHOWERRORCONTEXT()
           stop
        end if
     END DO
  ENDIF
END SUBROUTINE emitpopr4array

SUBROUTINE emitpushr8scalar()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'PUSHREAL8(',ARRAYR8(1),') AT ',LOCSTRB(),LOCSTRO()
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillr8(  01,",I4,"); pushReal8(ArrayR8[0]);")') &
 &        seedForFile
  ELSE
     CALL PUSHREAL8(ARRAYR8(1))
  ENDIF
END SUBROUTINE emitpushr8scalar

SUBROUTINE emitpopr8scalar()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillr8(  01,",I4,"); popReal8(&recvArrayR8[0]); testr8(1);")') &
 &        seedForFile
  ELSE
     CALL POPREAL8(RECVARRAYR8(1))
     IF (TRACEON) print *,'POPREAL8(',RECVARRAYR8(1),') AT ',LOCSTRB(),LOCSTRO()
     if (RECVARRAYR8(1).ne.ARRAYR8(1)) then
        print *,'Error real8 scalar pushed ',ARRAYR8(1),' popped ',RECVARRAYR8(1),   &
 &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
        CALL SHOWERRORCONTEXT()
        stop
     end if
  ENDIF
END SUBROUTINE emitpopr8scalar

SUBROUTINE emitpushr8array(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER size
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'PUSHREAL8ARRAY(',size,":",ARRAYR8(1),'...) AT ',LOCSTRB(),LOCSTRO()
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillr8(",I4,",",I4,"); pushReal8Array(ArrayR8,",I4,");")') &
 &        size,seedForFile,size
  ELSE
     CALL PUSHREAL8ARRAY(ARRAYR8, size)
  ENDIF
END SUBROUTINE emitpushr8array

SUBROUTINE emitpopr8array(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER :: size, i
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  fillr8(",I4,",",I4,"); popReal8Array(recvArrayR8,",I4,"); testr8(",I4,");")') &
 &        size,seedForFile,size,size
  ELSE
     CALL POPREAL8ARRAY(RECVARRAYR8, size)
     IF (TRACEON) print *,'POPREAL8ARRAY(',size,":",RECVARRAYR8(1),'...) AT ',LOCSTRB(),LOCSTRO()
     DO i=size,1,-1
        if (RECVARRAYR8(i).ne.ARRAYR8(i)) then
           print *,'Error real8 array elem ',i,' pushed ',ARRAYR8(i),' popped ',RECVARRAYR8(i),   &
 &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
           CALL SHOWERRORCONTEXT()
           stop
        end if
     END DO
  ENDIF
END SUBROUTINE emitpopr8array

SUBROUTINE emitpushi4scalar()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'PUSHINTEGER4(',ARRAYI4(1),') AT ',LOCSTRB(),LOCSTRO()
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  filli4(  01,",I4,"); pushInteger4(ArrayI4[0]);")') &
 &        seedForFile
  ELSE
     CALL PUSHINTEGER4(ARRAYI4(1))
  ENDIF
END SUBROUTINE emitpushi4scalar

SUBROUTINE emitpopi4scalar()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  filli4(  01,",I4,"); popInteger4(&recvArrayI4[0]); testi4(1);")') &
 &        seedForFile
  ELSE
     CALL POPINTEGER4(RECVARRAYI4(1))
     IF (TRACEON) print *,'POPINTEGER4(',RECVARRAYI4(1),') AT ',LOCSTRB(),LOCSTRO()
     if (RECVARRAYI4(1).ne.ARRAYI4(1)) then
        print *,'Error integer4 scalar pushed ',ARRAYI4(1),' popped ',RECVARRAYI4(1),   &
 &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
        CALL SHOWERRORCONTEXT()
        stop
     end if
  ENDIF
END SUBROUTINE emitpopi4scalar

SUBROUTINE emitpushi4array(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER size
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'PUSHINTEGER4ARRAY(',size,":",ARRAYI4(1),'...) AT ',LOCSTRB(),LOCSTRO()
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  filli4(",I4,",",I4,"); pushInteger4Array(ArrayI4,",I4,");")') &
 &        size,seedForFile,size
  ELSE
     CALL PUSHINTEGER4ARRAY(ARRAYI4, size)
  ENDIF
END SUBROUTINE emitpushi4array

SUBROUTINE emitpopi4array(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER :: size,i
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  filli4(",I4,",",I4,"); popInteger4Array(recvArrayI4,",I4,"); testi4(",I4,");")') &
 &        size,seedForFile,size,size
  ELSE
     CALL POPINTEGER4ARRAY(RECVARRAYI4, size)
     IF (TRACEON) print *,'POPINTEGER4ARRAY(',size,":",RECVARRAYI4(1),'...) AT ',LOCSTRB(),LOCSTRO()
     DO i=size,1,-1
        if (RECVARRAYI4(i).ne.ARRAYI4(i)) then
           print *,'Error integer4 array elem ',i,' pushed ',ARRAYI4(i),' popped ',RECVARRAYI4(i),   &
 &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
           CALL SHOWERRORCONTEXT()
           stop
        end if
     END DO
  ENDIF
END SUBROUTINE emitpopi4array

SUBROUTINE emitpushi8scalar()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'PUSHINTEGER8(',ARRAYI8(1),') AT ',LOCSTRB(),LOCSTRO()
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  filli8(  01,",I4,"); pushInteger8(ArrayI8[0]);")') &
 &        seedForFile
  ELSE
     CALL PUSHINTEGER8(ARRAYI8(1))
  ENDIF
END SUBROUTINE emitpushi8scalar

SUBROUTINE emitpopi8scalar()
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  filli8(  01,",I4,"); popInteger8(&recvArrayI8[0]); testi8(1);")') &
 &        seedForFile
  ELSE
     CALL POPINTEGER8(RECVARRAYI8(1))
     IF (TRACEON) print *,'POPINTEGER8(',RECVARRAYI8(1),') AT ',LOCSTRB(),LOCSTRO()
     if (RECVARRAYI8(1).ne.ARRAYI8(1)) then
        print *,'Error integer8 scalar pushed ',ARRAYI8(1),' popped ',RECVARRAYI8(1),   &
 &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
        CALL SHOWERRORCONTEXT()
        stop
     end if
  ENDIF
END SUBROUTINE emitpopi8scalar

SUBROUTINE emitpushi8array(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER size
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'PUSHINTEGER8ARRAY(',size,":",ARRAYI8(1),'...) AT ',LOCSTRB(),LOCSTRO()
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  filli8(",I4,",",I4,"); pushInteger8Array(ArrayI8,",I4,");")') &
 &        size,seedForFile,size
  ELSE
     CALL PUSHINTEGER8ARRAY(ARRAYI8, size)
  ENDIF
END SUBROUTINE emitpushi8array

SUBROUTINE emitpopi8array(size)
  USE TESTPUSHPOPUTILS
  IMPLICIT NONE
  INTEGER :: size,i
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (INTERMEDIATEFILE) THEN
     write(1,'("  filli8(",I4,",",I4,"); popInteger8Array(recvArrayI8,",I4,"); testi8(",I4,");")') &
 &        size,seedForFile,size,size
  ELSE
     CALL POPINTEGER8ARRAY(RECVARRAYI8, size)
     IF (TRACEON) print *,'POPINTEGER8ARRAY(',size,":",RECVARRAYI8(1),'...) AT ',LOCSTRB(),LOCSTRO()
     DO i=size,1,-1
        if (RECVARRAYI8(i).ne.ARRAYI8(i)) then
           print *,'Error integer8 array elem ',i,' pushed ',ARRAYI8(i),' popped ',RECVARRAYI8(i),   &
 &           ' seed:',givenSeed,' code:',givenCode(1:codeLength)
           CALL SHOWERRORCONTEXT()
           stop
        end if
     END DO
  ENDIF
END SUBROUTINE emitpopi8array

SUBROUTINE emitstartrepeat()
  USE TESTPUSHPOPUTILS
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'adStack_startRepeat() AT ',LOCSTRB(),LOCSTRO()
  if (TRACEDRY) then
     print *,'START REPEAT'
  else if (INTERMEDIATEFILE) THEN
     write(1,'("  adStack_startRepeat();")')
  else
     CALL ADSTACK_STARTREPEAT()
  endif
END SUBROUTINE emitstartrepeat

SUBROUTINE emitresetrepeat()
  USE TESTPUSHPOPUTILS
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'adStack_resetRepeat() AT ',LOCSTRB(),LOCSTRO()
  if (TRACEDRY) then
     print *,'RESET REPEAT'
  else if (INTERMEDIATEFILE) THEN
     write(1, '("  adStack_resetRepeat();")')
  else
     CALL ADSTACK_RESETREPEAT()
  endif
  IF (TRACEON) print *,'-----------------------> ',LOCSTRB(),LOCSTRO()
END SUBROUTINE emitresetrepeat

SUBROUTINE emitendrepeat()
  USE TESTPUSHPOPUTILS
  INTEGER*4 LOCSTRB,LOCSTRO
  IF (TRACEON) print *,'adStack_endRepeat() AT ',LOCSTRB(),LOCSTRO()
  if (TRACEDRY) then
     print *,'  END REPEAT'
  else if (INTERMEDIATEFILE) THEN
     write(1, '("  adStack_endRepeat();")')
  else
     CALL ADSTACK_ENDREPEAT()
  endif
END SUBROUTINE emitendrepeat

!! Only for Trace:
SUBROUTINE emitshowstacksize()
  USE TESTPUSHPOPUTILS
  CALL ADSTACK_SHOWSTACKSIZE(77)
END SUBROUTINE emitshowstacksize

SUBROUTINE emitshowstack(locationName)
  USE TESTPUSHPOPUTILS
  CHARACTER(*) locationName
  CALL ADSTACK_SHOWSTACK(locationName)
END SUBROUTINE emitshowstack
