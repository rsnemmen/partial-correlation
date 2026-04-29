

C--------------------------------------------------------
C  COMPUTE PARTIAL CORRELATION COEFFICIENT AND
C       SIGNIFICANCE FOR CENSORED DATA
C
C               AUGUST 1995
C 
C  THE CODE IS BASED ON THE METHODOLOGY PRESENTED IN 
C     'A test for partial correlation with censored 
C                astronomical data'
C                      BY
C            M.G.Akritas and J.Siebert 
C  Monthly Notices of the Royal Astronomical Society
C               278, 919-924, 1996
C-------------------------------------------------------
c
c CHANGELOG: 
c 	RODRIGO S. NEMMEN, http://goo.gl/8S1Oo
c	JUNE 2011
c	- accepts any filename for input data file
c	- free format input data, allows more freedom with input columns
c	- outputs the confidence level in standard deviations and the
c     probability (Pnull) with which the null hypothesis can be rejected 
c     (null hypothesis: no correlation between x and y taking into
c	  account the effect of z)

      program partial_tau

      common /data/ dat(500,3),idat(500,3)
      common ntot
      common /kx/ k1,k2,k3
      character infile*256     
      character dataline*256   
      real x1,x2,x3
      double precision zscore,pnull,pnormtail
      integer ic1,ic2,ic3,ios

C-------------------------------------------------------------
C  INPUT DATA FILE CALLED 'DATA'.
C  CURRENTLY THE DATA FORMAT IS FIXED TO 3(f10.4,1x,i2,1x).
C  1ST, 3RD AND 5TH COLUMN ARE INDEPENDENT, DEPENDENT AND TEST
C  VARIABLE, RESPECTIVELY. 2ND, 4TH AND 6TH COLUMN DENOTE
C  CENSORING WITH 1 = DETECTION, 0= UPPER LIMIT
C  EXAMPLE:
C  '   26.9800  1    44.4340  0    -1.0714  1 '
C------------------------------------------------------------- 

c Nemmen  -->
      write(*,*) 'Name of input file [x cx? y cy? z cz?]:'
c      write(*,*) ' x, y and z are the the independent, dependent'
c      write(*,*) '     and test variable, respectively.'
c      write(*,*) '     cx, cy and cz denote censoring with'
c      write(*,*) '     1=detection, 0=upper limit.'
      infile=' '
      read(*,'(A)',iostat=ios) infile
      if(ios.ne.0 .or. infile.eq.' ') then
        write(6,*) 'ERROR: no input filename was provided.'
        stop 1
      endif
c N <--
      open(10,file=infile,status='old',iostat=ios)
      if(ios.ne.0) then
        write(6,*) 'ERROR: could not open input file:'
        write(6,*) infile
        stop 1
      endif

C-------------------------------------------------
C READ IN DATA:
C     DAT(I,K)  = MEASUREMENT I OF VARIABLE K
C     IDAT(I,K) = CENSORING INDICATOR FOR DATA POINT (I,K)
C                 DETECTION   --> IDAT(I,K)=1
C                 UPPER LIMIT --> IDAT(I,K)=0
C--------------------------------------------------
 
      i=1
1     read(10,'(A)',iostat=ios) dataline
      if(ios.lt.0) goto 99
      if(ios.gt.0) then
        write(6,*) 'ERROR: invalid data row ',i
        write(6,*) 'Expected: X censX Y censY Z censZ'
        stop 1
      endif
      if(nfields(dataline).ne.6) then
        write(6,*) 'ERROR: invalid data row ',i
        write(6,*) 'Expected: X censX Y censY Z censZ'
        stop 1
      endif
      read(dataline,*,iostat=ios) x1,ic1,x2,ic2,x3,ic3
      if(ios.ne.0) then
        write(6,*) 'ERROR: invalid data row ',i
        write(6,*) 'Expected: X censX Y censY Z censZ'
        stop 1
      endif
      if(i.gt.500) then
        write(6,*) 'ERROR: input has more than 500 rows.'
        stop 1
      endif
      if((ic1.ne.0 .and. ic1.ne.1) .or.
     #   (ic2.ne.0 .and. ic2.ne.1) .or.
     #   (ic3.ne.0 .and. ic3.ne.1)) then
        write(6,*) 'ERROR: censor flags must be 0 or 1.'
        write(6,*) 'Invalid flag on row ',i
        stop 1
      endif
      dat(i,1)=-x1          ! CHANGE TO RIGHT CENSORING
      idat(i,1)=ic1
      dat(i,2)=-x2          ! CHANGE TO RIGHT CENSORING
      idat(i,2)=ic2
      dat(i,3)=-x3          ! CHANGE TO RIGHT CENSORING
      idat(i,3)=ic3
      i=i+1
      goto 1
99    ntot=i-1
      close(10)
      if(ntot.le.0) then
        write(6,*) 'ERROR: input file is empty.'
        stop 1
      endif
      if(ntot.le.3) then
        write(6,*) 'ERROR: at least 4 rows are required.'
        stop 1
      endif

      k1=1       ! INDEPENDENT VARIABLE = 1.COL OF DAT
      k2=2       ! DEPENDENT VARIABLE   = 2.COL OF DAT
      k3=3       ! THIRD VARIABLE       = 3.COL OF DAT

      call tau123(res)     ! COMPUTE PARTIAL KENDALLS TAU

      write(6,*) 'Tau(1,2):',tau(k1,k2)
      write(6,*) 'Tau(1,3):',tau(k1,k3)
      write(6,*) 'Tau(2,3):',tau(k2,k3)
      write(6,*) '--> Partial Kendalls tau:', res
      write(6,*) '  '
      write(6,*) 'Calculating variance...this takes some time....'
      write(6,*) '  '

      call sigma(sig)      ! COMPUTE VARIANCE

      write(6,*) 'Square root of variance (sigma):',sig
      write(6,*) '  '

      if(abs(res/sig).gt.1.96) then
        write(6,*) 'Zero partial correlation rejected at level 0.05'
      else
       write(6,*) 'Null hypothesis cannot be rejected!'
       write(6,*) '(--> No correlation present, if influence of
     #third variable is excluded)'
      endif
      
c Nemmen -->
      write(*,*)
      write(*,*) 'More specifically:'
      zscore=dabs(dble(res)/dble(sig))
      pnull=pnormtail(zscore)
      write(*,*) 'Null hypothesis rejected at ', zscore, 'sigma'
      write(*,*) 'Probability of null hypothesis =', pnull
c N <--
      
      stop
      end

C------------------------------------------------------
C-------- SUBROUTINES AND FUNCTIONS -------------------
C------------------------------------------------------

      integer function nfields(line)
      character*(*) line
      logical intok

      nfields=0
      intok=.false.
      do 5 i=1,len(line)
        if(line(i:i).ne.' ' .and. line(i:i).ne.char(9)) then
          if(.not.intok) then
            nfields=nfields+1
            intok=.true.
          endif
        else
          intok=.false.
        endif
 5    continue
      return
      end

      double precision function pnormtail(z)
      double precision z,t,x

      x=z/sqrt(2.d0)
      t=1.d0/(1.d0+0.5d0*x)
      pnormtail=t*exp(-x*x-1.26551223d0+t*(1.00002368d0+
     #  t*(0.37409196d0+t*(0.09678418d0+t*(-0.18628806d0+
     #  t*(0.27886807d0+t*(-1.13520398d0+t*(1.48851587d0+
     #  t*(-0.82215223d0+t*0.17087277d0)))))))))
      return
      end

C------------ TAU123 ---------------------------------
C-------- PARTIAL KENDALLS TAU -----------------------

      subroutine tau123(res)
      common /kx/ k1,k2,k3

      res= (tau(k1,k2)-tau(k1,k3)*tau(k2,k3))/
     # sqrt((1.-tau(k1,k3)**2)*(1.-tau(k2,k3)**2))
      end

C------------ SIGMA -----------------------------------
C-------- VARIANCE OF STATISTIC -----------------------

      subroutine sigma(sigres)
      common ntot
      common /kx/ k1,k2,k3

      sig2=an( )/(ntot*(1.-tau(k1,k3)**2)*(1.-tau(k2,k3)**2))
      sigres=sqrt(sig2)
      end

C------------ AN ---------------------------------------
C------- COMPUTES VALUE FOR A_N -------------------------

      function an( )
      double precision aasum(500)
      common ntot
      common /data/ dat(500,3),idat(500,3)
      common /kx/ k1,k2,k3
      c1=16./(float(ntot)-1.)
      c2=6./((float(ntot)-1.)*(float(ntot)-2.)*(float(ntot)-3.))
      asum=0.0
      ave = 0.0
      do 5 i=1,ntot
        aasum(i)=0.0
 5    continue
      do 10 i1=1,ntot     ! OUTER SUMMATION (I1)
      write(6,*) i1
        do 11 j1=1,ntot-2         ! INNER SUMMATION WITH
          if(j1.eq.i1) goto 11    ! J1<I2<J2 AND ALL .NE. I1
          do 12 j2=j1+2,ntot      !
            if(j2.eq.i1) goto 12  !
            do 13 i2=j1+1,j2-1    !
            if(i2.eq.i1) goto 13  !
            cj1=cval(dat(i1,k1),dat(j1,k1),
     #         idat(i1,k1),idat(j1,k1))
            cj2=cval(dat(i1,k2),dat(j1,k2),
     #         idat(i1,k2),idat(j1,k2))
            cj3=cval(dat(i1,k3),dat(j1,k3),
     #         idat(i1,k3),idat(j1,k3))
            cj4=cval(dat(i2,k2),dat(j2,k2),
     #         idat(i2,k2),idat(j2,k2))
            cj5=cval(dat(i2,k3),dat(j2,k3),
     #         idat(i2,k3),idat(j2,k3))
            cj6=cval(dat(j2,k2),dat(i2,k2),
     #         idat(j2,k2),idat(i2,k2))
            cj7=cval(dat(j2,k3),dat(i2,k3),
     #         idat(j2,k3),idat(i2,k3))
            gtsum=cj1*(2.0*cj2 - cj3*(cj4*cj5+cj6*cj7) )

            cj1=cval(dat(i1,k1),dat(j2,k1),
     #         idat(i1,k1),idat(j2,k1))
            cj2=cval(dat(i1,k2),dat(j2,k2),
     #         idat(i1,k2),idat(j2,k2))
            cj3=cval(dat(i1,k3),dat(j2,k3),
     #         idat(i1,k3),idat(j2,k3))
            cj4=cval(dat(i2,k2),dat(j1,k2),
     #         idat(i2,k2),idat(j1,k2))
            cj5=cval(dat(i2,k3),dat(j1,k3),
     #         idat(i2,k3),idat(j1,k3))
            cj6=cval(dat(j1,k2),dat(i2,k2),
     #         idat(j1,k2),idat(i2,k2))
            cj7=cval(dat(j1,k3),dat(i2,k3),
     #         idat(j1,k3),idat(i2,k3))
            gtsum=gtsum+cj1*(2.0*cj2 - cj3*(cj4*cj5+cj6*cj7) )

            cj1=cval(dat(i1,k1),dat(i2,k1),
     #         idat(i1,k1),idat(i2,k1))
            cj2=cval(dat(i1,k2),dat(i2,k2),
     #         idat(i1,k2),idat(i2,k2))
            cj3=cval(dat(i1,k3),dat(i2,k3),
     #         idat(i1,k3),idat(i2,k3))
            cj4=cval(dat(j2,k2),dat(j1,k2),
     #         idat(j2,k2),idat(j1,k2))
            cj5=cval(dat(j2,k3),dat(j1,k3),
     #         idat(j2,k3),idat(j1,k3))
            cj6=cval(dat(j1,k2),dat(j2,k2),
     #         idat(j1,k2),idat(j2,k2))
            cj7=cval(dat(j1,k3),dat(j2,k3),
     #         idat(j1,k3),idat(j2,k3))
            gtsum=gtsum+cj1*(2.0*cj2 - cj3*(cj4*cj5+cj6*cj7) )

            cj1=cval(dat(j1,k1),dat(i1,k1),
     #         idat(j1,k1),idat(i1,k1))
            cj2=cval(dat(j1,k2),dat(i1,k2),
     #         idat(j1,k2),idat(i1,k2))
            cj3=cval(dat(j1,k3),dat(i1,k3),
     #         idat(j1,k3),idat(i1,k3))
            cj4=cval(dat(i2,k2),dat(j2,k2),
     #         idat(i2,k2),idat(j2,k2))
            cj5=cval(dat(i2,k3),dat(j2,k3),
     #         idat(i2,k3),idat(j2,k3))
            cj6=cval(dat(j2,k2),dat(i2,k2),
     #         idat(j2,k2),idat(i2,k2))
            cj7=cval(dat(j2,k3),dat(i2,k3),
     #         idat(j2,k3),idat(i2,k3))
            gtsum=gtsum+cj1*(2.0*cj2 - cj3*(cj4*cj5+cj6*cj7) )

            cj1=cval(dat(j1,k1),dat(i2,k1),
     #         idat(j1,k1),idat(i2,k1))
            cj2=cval(dat(j1,k2),dat(i2,k2),
     #         idat(j1,k2),idat(i2,k2))
            cj3=cval(dat(j1,k3),dat(i2,k3),
     #         idat(j1,k3),idat(i2,k3))
            cj4=cval(dat(i1,k2),dat(j2,k2),
     #         idat(i1,k2),idat(j2,k2))
            cj5=cval(dat(i1,k3),dat(j2,k3),
     #         idat(i1,k3),idat(j2,k3))
            cj6=cval(dat(j2,k2),dat(i1,k2),
     #         idat(j2,k2),idat(i1,k2))
            cj7=cval(dat(j2,k3),dat(i1,k3),
     #         idat(j2,k3),idat(i1,k3))
            gtsum=gtsum+cj1*(2.0*cj2 - cj3*(cj4*cj5+cj6*cj7) )

            cj1=cval(dat(j1,k1),dat(j2,k1),
     #         idat(j1,k1),idat(j2,k1))
            cj2=cval(dat(j1,k2),dat(j2,k2),
     #         idat(j1,k2),idat(j2,k2))
            cj3=cval(dat(j1,k3),dat(j2,k3),
     #         idat(j1,k3),idat(j2,k3))
            cj4=cval(dat(i1,k2),dat(i2,k2),
     #         idat(i1,k2),idat(i2,k2))
            cj5=cval(dat(i1,k3),dat(i2,k3),
     #         idat(i1,k3),idat(i2,k3))
            cj6=cval(dat(i2,k2),dat(i1,k2),
     #         idat(i2,k2),idat(i1,k2))
            cj7=cval(dat(i2,k3),dat(i1,k3),
     #         idat(i2,k3),idat(i1,k3))
            gtsum=gtsum+cj1*(2.0*cj2 - cj3*(cj4*cj5+cj6*cj7) )

            cj1=cval(dat(i2,k1),dat(i1,k1),
     #         idat(i2,k1),idat(i1,k1))
            cj2=cval(dat(i2,k2),dat(i1,k2),
     #         idat(i2,k2),idat(i1,k2))
            cj3=cval(dat(i2,k3),dat(i1,k3),
     #         idat(i2,k3),idat(i1,k3))
            cj4=cval(dat(j1,k2),dat(j2,k2),
     #         idat(j1,k2),idat(j2,k2))
            cj5=cval(dat(j1,k3),dat(j2,k3),
     #         idat(j1,k3),idat(j2,k3))
            cj6=cval(dat(j2,k2),dat(j1,k2),
     #         idat(j2,k2),idat(j1,k2))
            cj7=cval(dat(j2,k3),dat(j1,k3),
     #         idat(j2,k3),idat(j1,k3))
            gtsum=gtsum+cj1*(2.0*cj2 - cj3*(cj4*cj5+cj6*cj7) )

            cj1=cval(dat(i2,k1),dat(j1,k1),
     #         idat(i2,k1),idat(j1,k1))
            cj2=cval(dat(i2,k2),dat(j1,k2),
     #         idat(i2,k2),idat(j1,k2))
            cj3=cval(dat(i2,k3),dat(j1,k3),
     #         idat(i2,k3),idat(j1,k3))
            cj4=cval(dat(i1,k2),dat(j2,k2),
     #         idat(i1,k2),idat(j2,k2))
            cj5=cval(dat(i1,k3),dat(j2,k3),
     #         idat(i1,k3),idat(j2,k3))
            cj6=cval(dat(j2,k2),dat(i1,k2),
     #         idat(j2,k2),idat(i1,k2))
            cj7=cval(dat(j2,k3),dat(i1,k3),
     #         idat(j2,k3),idat(i1,k3))
            gtsum=gtsum+cj1*(2.0*cj2 - cj3*(cj4*cj5+cj6*cj7) )

            cj1=cval(dat(i2,k1),dat(j2,k1),
     #         idat(i2,k1),idat(j2,k1))
            cj2=cval(dat(i2,k2),dat(j2,k2),
     #         idat(i2,k2),idat(j2,k2))
            cj3=cval(dat(i2,k3),dat(j2,k3),
     #         idat(i2,k3),idat(j2,k3))
            cj4=cval(dat(i1,k2),dat(j1,k2),
     #         idat(i1,k2),idat(j1,k2))
            cj5=cval(dat(i1,k3),dat(j1,k3),
     #         idat(i1,k3),idat(j1,k3))
            cj6=cval(dat(j1,k2),dat(i1,k2),
     #         idat(j1,k2),idat(i1,k2))
            cj7=cval(dat(j1,k3),dat(i1,k3),
     #         idat(j1,k3),idat(i1,k3))
            gtsum=gtsum+cj1*(2.0*cj2 - cj3*(cj4*cj5+cj6*cj7) )

            cj1=cval(dat(j2,k1),dat(i1,k1),
     #         idat(j2,k1),idat(i1,k1))
            cj2=cval(dat(j2,k2),dat(i1,k2),
     #         idat(j2,k2),idat(i1,k2))
            cj3=cval(dat(j2,k3),dat(i1,k3),
     #         idat(j2,k3),idat(i1,k3))
            cj4=cval(dat(j1,k2),dat(i2,k2),
     #         idat(j1,k2),idat(i2,k2))
            cj5=cval(dat(j1,k3),dat(i2,k3),
     #         idat(j1,k3),idat(i2,k3))
            cj6=cval(dat(i2,k2),dat(j1,k2),
     #         idat(i2,k2),idat(j1,k2))
            cj7=cval(dat(i2,k3),dat(j1,k3),
     #         idat(i2,k3),idat(j1,k3))
            gtsum=gtsum+cj1*(2.0*cj2 - cj3*(cj4*cj5+cj6*cj7) )

            cj1=cval(dat(j2,k1),dat(j1,k1),
     #         idat(j2,k1),idat(j1,k1))
            cj2=cval(dat(j2,k2),dat(j1,k2),
     #         idat(j2,k2),idat(j1,k2))
            cj3=cval(dat(j2,k3),dat(j1,k3),
     #         idat(j2,k3),idat(j1,k3))
            cj4=cval(dat(i2,k2),dat(i1,k2),
     #         idat(i2,k2),idat(i1,k2))
            cj5=cval(dat(i2,k3),dat(i1,k3),
     #         idat(i2,k3),idat(i1,k3))
            cj6=cval(dat(i1,k2),dat(i2,k2),
     #         idat(i1,k2),idat(i2,k2))
            cj7=cval(dat(i1,k3),dat(i2,k3),
     #         idat(i1,k3),idat(i2,k3))
            gtsum=gtsum+cj1*(2.0*cj2 - cj3*(cj4*cj5+cj6*cj7) )

            cj1=cval(dat(j2,k1),dat(i2,k1),
     #         idat(j2,k1),idat(i2,k1))
            cj2=cval(dat(j2,k2),dat(i2,k2),
     #         idat(j2,k2),idat(i2,k2))
            cj3=cval(dat(j2,k3),dat(i2,k3),
     #         idat(j2,k3),idat(i2,k3))
            cj4=cval(dat(i1,k2),dat(j1,k2),
     #         idat(i1,k2),idat(j1,k2))
            cj5=cval(dat(i1,k3),dat(j1,k3),
     #         idat(i1,k3),idat(j1,k3))
            cj6=cval(dat(j1,k2),dat(i1,k2),
     #         idat(j1,k2),idat(i1,k2))
            cj7=cval(dat(j1,k3),dat(i1,k3),
     #         idat(j1,k3),idat(i1,k3))
            gtsum=gtsum+cj1*(2.0*cj2 - cj3*(cj4*cj5+cj6*cj7) )

       aasum(i1)=aasum(i1)+1./24.*gtsum !ADD SUMMATION OVER PERMUTATIONS
13          continue              !
12        continue                !
11      continue                  !
      ave = ave + c2*aasum(i1)
10    continue
      ave=ave/float(ntot)
      do 20 i=1,ntot
      asum=asum+(c2*aasum(i)-ave)**2
 20   continue
      an=asum*c1
      return
      end

C------------- TAU -------------------------------------------
C------- COMPUTES KENDALLS TAU -------------------------------

      function tau(k,l)
      common ntot
      ac=2./(float(ntot)*(float(ntot)-1))
      sum=0.0
      do 11 j=1,ntot
        do 12 i=1,ntot
          if (i.ge.j) goto 11
          sum=sum+h(k,l,i,j)
12      continue
11    continue
      tau=sum*ac
      return
      end

C-------------- H --------------------------------------------
C------- COMPUTE VALUE FOR H (SEE FORMULA) --------------------

      function cval(a,b,ia,ib)
      real a,b
      integer ia,ib

      cval=0.0
      if(a.lt.b) cval=ia
      if(a.gt.b) cval=-ib
      return
      end

      function h(k,l,i,j)
      common /data/ dat(500,3),idat(500,3)
      cj1=cval(dat(i,k),dat(j,k),
     #         idat(i,k),idat(j,k))
      cj2=cval(dat(i,l),dat(j,l),
     #         idat(i,l),idat(j,l))
      h=cj1*cj2
      return
      end
