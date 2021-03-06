!----------------------------------------------------------------
! (c) Copyright, 2015 by the Regents of the University of California.
! Distributionclass: Initial distribution of charged beam bunch class in 
!                    Beam module of APPLICATION layer.
! Version: 1.0-beta
! Author: Ji Qiang
! Description: This class defines initial distributions for the charged 
!              particle beam bunch information in the accelerator.
! Comments:
!----------------------------------------------------------------
      module Distributionclass
        use Pgrid2dclass
        use CompDomclass
        use Timerclass
        use NumConstclass
        use PhysConstclass
        use BeamBunchclass
      contains
        ! sample the particles with intial distribution.
        subroutine sample_Dist(this,distparam,nparam,flagdist,geom,grid,Flagbc,ib,Nb)
        implicit none
        include 'mpif.h'
        integer, intent(in) :: nparam,Flagbc
        double precision, dimension(nparam) :: distparam
        type (BeamBunch), intent(inout) :: this
        type (CompDom), intent(in) :: geom
        type (Pgrid2d), intent(in) :: grid
        integer, intent(in) :: flagdist,ib,Nb
        integer :: myid, myidx, myidy,seedsize,i,isize
        !integer seedarray(1)
        integer, allocatable, dimension(:) :: seedarray
        real rancheck

        call getpost_Pgrid2d(grid,myid,myidy,myidx)
!        seedarray(1)=(100001+myid)*(myid+7)
!        call random_seed(put=seedarray(1:1))
!        write(6,*)'seedarray=',seedarray

        call random_seed(SIZE=seedsize)
        allocate(seedarray(seedsize))
        do i = 1, seedsize
          !seedarray(i) = (1000+5*myid)*(myid+7)+i-1 !seed 1
          !seedarray(i) = (2000+5*myid)*(myid+7)+i-1  !seed 2
          seedarray(i) = (3000+5*myid)*(myid+7)+i-1  !seed 3
        enddo
        call random_seed(PUT=seedarray)
        !randomnize the random number generator
        do i = 1, 1000
          call random_number(rancheck)
        enddo
!        write(6,*)'myid,rancheck=',seedarray,myid,rancheck

        !from the SI (m) unit to dimensionless unit
        distparam(1) = distparam(1)/Scxlt
        distparam(6) = distparam(6)/Scxlt
        distparam(8) = distparam(8)/Scxlt
        distparam(13) = distparam(13)/Scxlt
        distparam(15) = distparam(15)/Scxlt
        distparam(20) = distparam(20)/Scxlt
        if(flagdist.eq.1) then
          !6d uniform distribution
          call Uniform_Dist(this,nparam,distparam,grid)
        else if(flagdist.eq.2) then
          !6d Gaussian distribution
          call Gauss3_Dist(this,nparam,distparam,grid,0)
        else if(flagdist.eq.3) then
          !6d Waterbag distribution
          call Waterbag_Dist(this,nparam,distparam,grid,0)
        else if(flagdist.eq.4) then
          !3d Waterbag distribution in spatial and 3d Gaussian distribution in
          !momentum space
          call Semigauss_Dist(this,nparam,distparam,grid)
        else if(flagdist.eq.5) then
          !transverse KV distribution and longitudinal uniform distribution
          call KV3d_Dist(this,nparam,distparam,grid)
        else if(flagdist.eq.16) then
          !read in an initial distribution with format from IMPACT-T
          call read_Dist(this,nparam,distparam)
        else if(flagdist.eq.17) then
          !uniform cylinder distribution with 0 termperature
          call Cylcold_Dist(this,nparam,distparam,grid)
        else
          print*,"Initial distribution not available!!"
          stop
        endif

        deallocate(seedarray)

        end subroutine sample_Dist
       
        !6d uniform distribution
        subroutine Uniform_Dist(this,nparam,distparam,grid)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer, intent(in) :: nparam
        double precision, dimension(nparam) :: distparam
        type (Pgrid2d), intent(in) :: grid
        double precision :: sigx,sigpx,muxpx,xscale,sigy,&
        sigpy,muypy,yscale,sigz,sigpz,muzpz,zscale,pxscale,pyscale,pzscale
        double precision :: xmu1,xmu2,xmu3,xmu4,xmu5,xmu6
        double precision, dimension(6,1) :: a
        double precision, dimension(2) :: x1, x2
        double precision :: sig1,sig2,sig3,sig4,sig5,sig6,sq12,sq34,sq56
        double precision :: r1, r2
        integer :: totnp,npy,npx,myid,myidy,myidx,comm2d, &
                   commcol,commrow,ierr
        integer :: avgpts,numpts0,i,ii,i0,j,jj
        double precision :: t0,gamma,x11

        call starttime_Timer(t0)

        sigx = distparam(1)
        sigpx = distparam(2)
        muxpx = distparam(3)
        xscale = distparam(4)
        pxscale = distparam(5)
        xmu1 = distparam(6)
        xmu2 = distparam(7)
        sigy = distparam(8)
        sigpy = distparam(9)
        muypy = distparam(10)
        yscale = distparam(11)
        pyscale = distparam(12)
        xmu3 = distparam(13)
        xmu4 = distparam(14)
        sigz = distparam(15)
        sigpz = distparam(16)
        muzpz = distparam(17)
        zscale = distparam(18)
        pzscale = distparam(19)
        xmu5 = distparam(20)
        xmu6 = distparam(21)

        call getsize_Pgrid2d(grid,totnp,npy,npx)
        call getpost_Pgrid2d(grid,myid,myidy,myidx)
        call getcomm_Pgrid2d(grid,comm2d,commcol,commrow)
        call random_number(x11)
        !print*,"x11: ",x11

        avgpts = this%Npt/(npx*npy)

        sig1 = sigx*xscale
        sig2 = sigpx*pxscale
        sig3 = sigy*yscale
        sig4 = sigpy*pyscale
        sig5 = sigz*zscale
        sig6 = sigpz*pzscale

        sq12=sqrt(1.-muxpx*muxpx)
        sq34=sqrt(1.-muypy*muypy)
        sq56=sqrt(1.-muzpz*muzpz)

        numpts0 = avgpts

        ! initial allocate 'avgpts' particles on each processor.
        allocate(this%Pts1(6,avgpts))
        this%Pts1 = 0.0
!        print*,"avgpts: ",avgpts
    
        do ii = 1, avgpts
          call random_number(r1)
          r1 = (2*r1 - 1.0)*sqrt(3.0)
          call random_number(r2)
          r2 = (2*r2 - 1.0)*sqrt(3.0)
          this%Pts1(1,ii) = xmu1 + sig1*r1/sq12
          this%Pts1(2,ii) = xmu2 + sig2*(-muxpx*r2/sq12+r2)
          call random_number(r1)
          r1 = (2*r1 - 1.0)*sqrt(3.0)
          call random_number(r2)
          r2 = (2*r2 - 1.0)*sqrt(3.0)
          this%Pts1(3,ii) = xmu3 + sig3*r1/sq34
          this%Pts1(4,ii) = xmu4 + sig4*(-muypy*r2/sq34+r2)
          call random_number(r1)
          r1 = (2*r1 - 1.0)*sqrt(3.0)
          call random_number(r2)
          r2 = (2*r2 - 1.0)*sqrt(3.0)
          this%Pts1(5,ii) = xmu5 + sig5*r1/sq56
          this%Pts1(6,ii) = xmu6 + sig6*(-muzpz*r2/sq56+r2)
        enddo

        this%Nptlocal = numpts0

!        call MPI_BARRIER(comm2d,ierr)
        t_kvdist = t_kvdist + elapsedtime_Timer(t0)

        end subroutine Uniform_Dist

        !6d Gaussian distribution
        subroutine Gauss3_Dist(this,nparam,distparam,grid,flagalloc)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer, intent(in) :: nparam,flagalloc
        double precision, dimension(nparam) :: distparam
        type (Pgrid2d), intent(in) :: grid
        double precision  :: sigx,sigpx,muxpx,xscale,sigy,&
        sigpy,muypy, yscale,sigz,sigpz,muzpz,zscale,pxscale,pyscale,pzscale
        double precision :: xmu1,xmu2,xmu3,xmu4,xmu5,xmu6
        double precision :: sig1,sig2,sig3,sig4,sig5,sig6
        double precision :: sq12,sq34,sq56
        double precision, allocatable, dimension(:,:) :: x1,x2,x3 
        integer :: totnp,npy,npx
        integer :: avgpts,numpts
        integer :: myid,myidx,myidy,i,j,k,intvsamp
!        integer seedarray(1)
        double precision :: t0,x11

        call starttime_Timer(t0)

        sigx = distparam(1)
        sigpx = distparam(2)
        muxpx = distparam(3)
        xscale = distparam(4)
        pxscale = distparam(5)
        xmu1 = distparam(6)
        xmu2 = distparam(7)
        sigy = distparam(8)
        sigpy = distparam(9)
        muypy = distparam(10)
        yscale = distparam(11)
        pyscale = distparam(12)
        xmu3 = distparam(13)
        xmu4 = distparam(14)
        sigz = distparam(15)
        sigpz = distparam(16)
        muzpz = distparam(17)
        zscale = distparam(18)
        pzscale = distparam(19)
        xmu5 = distparam(20)
        xmu6 = distparam(21)

        call getsize_Pgrid2d(grid,totnp,npy,npx)

        call getpost_Pgrid2d(grid,myid,myidy,myidx)
!        seedarray(1)=(1001+myid)*(myid+7)
!        write(6,*)'seedarray=',seedarray
!        call random_seed(PUT=seedarray(1:1))
        call random_number(x11)
        print*,myid,x11

        avgpts = this%Npt/(npx*npy)

        if(mod(avgpts,10).ne.0) then
          print*,"The number of particles has to be an integer multiple of 10Nprocs"
          stop
        endif
        
        sig1 = sigx*xscale
        sig2 = sigpx*pxscale
        sig3 = sigy*yscale
        sig4 = sigpy*pyscale
        sig5 = sigz*zscale
        sig6 = sigpz*pzscale

        sq12=sqrt(1.-muxpx*muxpx)
        sq34=sqrt(1.-muypy*muypy)
        sq56=sqrt(1.-muzpz*muzpz)

        ! initial allocate 'avgpts' particles on each processor.
        if(flagalloc.eq.1) then
          this%Pts1 = 0.0
        else
          allocate(this%Pts1(6,avgpts))
          this%Pts1 = 0.0
        endif

!        allocate(x1(2,avgpts))
!        allocate(x2(2,avgpts))
!        allocate(x3(2,avgpts))
!        call normVec(x1,avgpts)
!        call normVec(x2,avgpts)
!        call normVec(x3,avgpts)
        
        intvsamp = 10
        allocate(x1(2,intvsamp))
        allocate(x2(2,intvsamp))
        allocate(x3(2,intvsamp))

        do j = 1, avgpts/intvsamp
          call normVec(x1,intvsamp)
          call normVec(x2,intvsamp)
          call normVec(x3,intvsamp)
          do k = 1, intvsamp
            !x-px:
!            call normdv(x1)
!           Correct Gaussian distribution.
            i = (j-1)*intvsamp + k
            this%Pts1(1,i) = xmu1 + sig1*x1(1,k)/sq12
            this%Pts1(2,i) = xmu2 + sig2*(-muxpx*x1(1,k)/sq12+x1(2,k))
            !y-py
!            call normdv(x1)
!           Correct Gaussian distribution.
            this%Pts1(3,i) = xmu3 + sig3*x2(1,k)/sq34
            this%Pts1(4,i) = xmu4 + sig4*(-muypy*x2(1,k)/sq34+x2(2,k))
            !z-pz
!            call normdv(x1)
!           Correct Gaussian distribution.
            this%Pts1(5,i) = xmu5 + sig5*x3(1,k)/sq56
            this%Pts1(6,i) = xmu6 + sig6*(-muzpz*x3(1,k)/sq56+x3(2,k))
          enddo
        enddo
          
        deallocate(x1)
        deallocate(x2)
        deallocate(x3)

        this%Nptlocal = avgpts
       
        t_kvdist = t_kvdist + elapsedtime_Timer(t0)

        end subroutine Gauss3_Dist

        subroutine normdv(y)
        implicit none
        include 'mpif.h'
        double precision, dimension(2), intent(out) :: y
        double precision :: twopi,x1,x2,epsilon

        epsilon = 1.0e-18

        twopi = 4.0*asin(1.0)
        call random_number(x2)
10      call random_number(x1)
!        x1 = 0.5
!10      x2 = 0.6
        if(x1.eq.0.0) goto 10
!        if(x1.eq.0.0) x1 = epsilon
        y(1) = sqrt(-2.0*log(x1))*cos(twopi*x2)
        y(2) = sqrt(-2.0*log(x1))*sin(twopi*x2)

        end subroutine normdv

        subroutine normVec(y,num)
        implicit none
        include 'mpif.h'
        integer, intent(in) :: num
        double precision, dimension(2,num), intent(out) :: y
        double precision :: twopi,epsilon
        double precision, dimension(num) :: x1,x2
        integer :: i

        epsilon = 1.0e-18

        twopi = 4.0*asin(1.0)
        call random_number(x2)
        call random_number(x1)
        do i = 1, num
          if(x1(i).eq.0.0) x1(i) = epsilon
          y(1,i) = sqrt(-2.0*log(x1(i)))*cos(twopi*x2(i))
          y(2,i) = sqrt(-2.0*log(x1(i)))*sin(twopi*x2(i))
        enddo

        end subroutine normVec

        !6d Waterbag distribution
        ! sample the particles with intial distribution 
        ! using rejection method. 
        subroutine Waterbag_Dist(this,nparam,distparam,grid,flagalloc)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer, intent(in) :: nparam,flagalloc
        double precision, dimension(nparam) :: distparam
        type (Pgrid2d), intent(in) :: grid
        double precision  :: sigx,sigpx,muxpx,xscale,sigy,&
        sigpy,muypy, yscale,sigz,sigpz,muzpz,zscale,pxscale,pyscale,pzscale
        double precision :: xmu1,xmu2,xmu3,xmu4,xmu5,xmu6
        double precision, dimension(2) :: gs
        double precision :: sig1,sig2,sig3,sig4,sig5,sig6
        double precision :: rootx,rooty,rootz,r1,r2,x1,x2
        double precision :: r3,r4,r5,r6,x3,x4,x5,x6
        integer :: totnp,npy,npx
        integer :: avgpts,numpts,isamz,isamy
        integer :: myid,myidx,myidy,iran,intvsamp
!        integer seedarray(2)
        double precision :: t0,x11
        double precision, allocatable, dimension(:) :: ranum6

        call starttime_Timer(t0)

        sigx = distparam(1)
        sigpx = distparam(2)
        muxpx = distparam(3)
        xscale = distparam(4)
        pxscale = distparam(5)
        xmu1 = distparam(6)
        xmu2 = distparam(7)
        sigy = distparam(8)
        sigpy = distparam(9)
        muypy = distparam(10)
        yscale = distparam(11)
        pyscale = distparam(12)
        xmu3 = distparam(13)
        xmu4 = distparam(14)
        sigz = distparam(15)
        sigpz = distparam(16)
        muzpz = distparam(17)
        zscale = distparam(18)
        pzscale = distparam(19)
        xmu5 = distparam(20)
        xmu6 = distparam(21)

        call getsize_Pgrid2d(grid,totnp,npy,npx)

        call getpost_Pgrid2d(grid,myid,myidy,myidx)
!        seedarray(1)=(1001+myid)*(myid+7)
!        seedarray(2)=(101+2*myid)*(myid+4)
!        write(6,*)'seedarray=',seedarray
!        call random_seed(PUT=seedarray)
        call random_number(x11)
        !print*,"x11: ",myid,x11

        avgpts = this%Npt/(npx*npy)
        !if(mod(avgpts,10).ne.0) then
        !  print*,"The number of particles has to be an integer multiple of 10Nprocs" 
        !  stop
        !endif
 
        sig1 = sigx*xscale
        sig2 = sigpx*pxscale
        sig3 = sigy*yscale
        sig4 = sigpy*pyscale
        sig5 = sigz*zscale
        sig6 = sigpz*pzscale

        rootx=sqrt(1.-muxpx*muxpx)
        rooty=sqrt(1.-muypy*muypy)
        rootz=sqrt(1.-muzpz*muzpz)

        ! initial allocate 'avgpts' particles on each processor.
        if(flagalloc.eq.1) then
          this%Pts1 = 0.0
        else
          allocate(this%Pts1(6,avgpts))
          this%Pts1 = 0.0
        endif
        numpts = 0
        isamz = 0
        isamy = 0
        intvsamp = avgpts
        !intvsamp = 10
        allocate(ranum6(6*intvsamp))

        do 
          ! rejection sample.
10        continue 
          isamz = isamz + 1
          if(mod(isamz-1,intvsamp).eq.0) then
            call random_number(ranum6)
          endif
          iran = 6*mod(isamz-1,intvsamp)
          r1 = 2.0*ranum6(iran+1)-1.0
          r2 = 2.0*ranum6(iran+2)-1.0
          r3 = 2.0*ranum6(iran+3)-1.0
          r4 = 2.0*ranum6(iran+4)-1.0
          r5 = 2.0*ranum6(iran+5)-1.0
          r6 = 2.0*ranum6(iran+6)-1.0
          if(r1**2+r2**2+r3**2+r4**2+r5**2+r6**2.gt.1.0) goto 10
          isamy = isamy + 1
          numpts = numpts + 1
          if(numpts.gt.avgpts) exit
!x-px:
          x1 = r1*sqrt(8.0)
          x2 = r2*sqrt(8.0)
          !Correct transformation.
          this%Pts1(1,numpts) = xmu1 + sig1*x1/rootx
          this%Pts1(2,numpts) = xmu2 + sig2*(-muxpx*x1/rootx+x2)
          !Rob's transformation
          !this%Pts1(1,numpts) = (xmu1 + sig1*x1)*xscale
          !this%Pts1(2,numpts) = (xmu2 + sig2*(muxpx*x1+rootx*x2))/xscale
!y-py:
          x3 = r3*sqrt(8.0)
          x4 = r4*sqrt(8.0)
          !correct transformation
          this%Pts1(3,numpts) = xmu3 + sig3*x3/rooty
          this%Pts1(4,numpts) = xmu4 + sig4*(-muypy*x3/rooty+x4)
          !Rob's transformation
          !this%Pts1(3,numpts) = (xmu3 + sig3*x3)*yscale
          !this%Pts1(4,numpts) = (xmu4 + sig4*(muypy*x3+rooty*x4))/yscale
!t-pt:
          x5 = r5*sqrt(8.0)
          x6 = r6*sqrt(8.0)
          !correct transformation
          this%Pts1(5,numpts) = xmu5 + sig5*x5/rootz
          this%Pts1(6,numpts) = xmu6 + sig6*(-muzpz*x5/rootz+x6)
          !Rob's transformation
          !this%Pts1(5,numpts) = (xmu5 + sig5*x5)*zscale
          !this%Pts1(6,numpts) = (xmu6 + sig6*(muzpz*x5+rootz*x6))/zscale
        enddo

        deallocate(ranum6)
          
        this%Nptlocal = avgpts
!        print*,"avgpts: ",avgpts
       
!        print*,avgpts,isamz,isamy

        t_kvdist = t_kvdist + elapsedtime_Timer(t0)

        end subroutine Waterbag_Dist

        !transverse KV distribution and longitudinal uniform distribution
        subroutine KV3d_Dist(this,nparam,distparam,grid)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer, intent(in) :: nparam
        double precision, dimension(nparam) :: distparam
        type (Pgrid2d), intent(in) :: grid
        double precision  :: sigx,sigpx,muxpx,xscale,sigy,&
        sigpy,muypy, yscale,sigz,sigpz,muzpz,zscale,pxscale,pyscale,pzscale
        double precision :: xmu1,xmu2,xmu3,xmu4,xmu5,xmu6
        double precision, dimension(2) :: gs
        double precision :: sig1,sig2,sig3,sig4,sig5,sig6
        double precision :: rootx,rooty,rootz,r1,r2,x1,x2
        double precision :: r3,r4,r5,r6,x3,x4,x5,x6
        integer :: totnp,npy,npx
        integer :: avgpts,numpts
        integer :: myid,myidx,myidy
!        integer seedarray(1)
        double precision :: t0,x11,twopi

        call starttime_Timer(t0)

        sigx = distparam(1)
        sigpx = distparam(2)
        muxpx = distparam(3)
        xscale = distparam(4)
        pxscale = distparam(5)
        xmu1 = distparam(6)
        xmu2 = distparam(7)
        sigy = distparam(8)
        sigpy = distparam(9)
        muypy = distparam(10)
        yscale = distparam(11)
        pyscale = distparam(12)
        xmu3 = distparam(13)
        xmu4 = distparam(14)
        sigz = distparam(15)
        sigpz = distparam(16)
        muzpz = distparam(17)
        zscale = distparam(18)
        pzscale = distparam(19)
        xmu5 = distparam(20)
        xmu6 = distparam(21)

        call getsize_Pgrid2d(grid,totnp,npy,npx)

        call getpost_Pgrid2d(grid,myid,myidy,myidx)
!        seedarray(1)=(1001+myid)*(myid+7)
!        write(6,*)'seedarray=',seedarray
!        call random_seed(PUT=seedarray(1:1))
        call random_number(x11)
        print*,myid,x11

        avgpts = this%Npt/(npx*npy)

        sig1 = sigx*xscale
        sig2 = sigpx*pxscale
        sig3 = sigy*yscale
        sig4 = sigpy*pyscale
        sig5 = sigz*zscale
        sig6 = sigpz*pzscale

        rootx=sqrt(1.-muxpx*muxpx)
        rooty=sqrt(1.-muypy*muypy)
        rootz=sqrt(1.-muzpz*muzpz)

        ! initial allocate 'avgpts' particles on each processor.
        allocate(this%Pts1(6,avgpts))
        this%Pts1 = 0.0
        twopi = 4*asin(1.0)

        do numpts = 1, avgpts
          call random_number(r1)
          call random_number(r2)
          call random_number(r3)
          r4 = sqrt(r1)
          r5 = sqrt(1.0-r1)
          r2 = r2*twopi
          r3 = r3*twopi
          x1 = 2*r4*cos(r2)
          x2 = 2*r4*sin(r2)
          x3 = 2*r5*cos(r3)
          x4 = 2*r5*sin(r3)
!x-px:
          !Correct transformation.
          this%Pts1(1,numpts) = xmu1 + sig1*x1/rootx
          this%Pts1(2,numpts) = xmu2 + sig2*(-muxpx*x1/rootx+x2)
          !Rob's transformation.
          !this%Pts1(1,numpts) = (xmu1 + sig1*x1)*xscale
          !this%Pts1(2,numpts) = (xmu2 + sig2*(muxpx*x1+rootx*x2))/xscale
!y-py:
          !correct transformation
          this%Pts1(3,numpts) = xmu3 + sig3*x3/rooty
          this%Pts1(4,numpts) = xmu4 + sig4*(-muypy*x3/rooty+x4)
          !Rob's transformation
          !this%Pts1(3,numpts) = (xmu3 + sig3*x3)*yscale
          !this%Pts1(4,numpts) = (xmu4 + sig4*(muypy*x3+rooty*x4))/yscale
!t-pt:
          call random_number(r5)
          r5 = 2*r5 - 1.0
          call random_number(r6)
          r6 = 2*r6 - 1.0
          x5 = r5*sqrt(3.0)
          x6 = r6*sqrt(3.0)
          !correct transformation
          this%Pts1(5,numpts) = xmu5 + sig5*x5/rootz
          this%Pts1(6,numpts) = xmu6 + sig6*(-muzpz*x5/rootz+x6)
          !Rob's transformation
          !this%Pts1(5,numpts) = (xmu5 + sig5*x5)*zscale
          !this%Pts1(6,numpts) = (xmu6 + sig6*(muzpz*x5+rootz*x6))/zscale
        enddo
          
        this%Nptlocal = avgpts
       
        t_kvdist = t_kvdist + elapsedtime_Timer(t0)

        end subroutine KV3d_Dist

        !3d Waterbag distribution in spatial and 3d Gaussian distribution in
        !momentum space
        subroutine Semigauss_Dist(this,nparam,distparam,grid)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer, intent(in) :: nparam
        double precision, dimension(nparam) :: distparam
        type (Pgrid2d), intent(in) :: grid
        double precision  :: sigx,sigpx,muxpx,xscale,sigy,&
        sigpy,muypy,yscale,sigz,sigpz,muzpz,zscale,pxscale,pyscale,pzscale
        double precision :: xmu1,xmu2,xmu3,xmu4,xmu5,xmu6
        double precision, dimension(6,2) :: a
        double precision, dimension(3) :: x1, x2
        double precision :: sig1,sig2,sig3,sig4,sig5,sig6,sq12,sq34,sq56
        double precision :: r1, r2, r, r3
        integer :: totnp,npy,npx,myid,myidy,myidx,comm2d, &
                   commcol,commrow,ierr
        integer :: avgpts,numpts0,i,ii,i0,j,jj
        double precision :: t0

        call starttime_Timer(t0)

        sigx = distparam(1)
        sigpx = distparam(2)
        muxpx = distparam(3)
        xscale = distparam(4)
        pxscale = distparam(5)
        xmu1 = distparam(6)
        xmu2 = distparam(7)
        sigy = distparam(8)
        sigpy = distparam(9)
        muypy = distparam(10)
        yscale = distparam(11)
        pyscale = distparam(12)
        xmu3 = distparam(13)
        xmu4 = distparam(14)
        sigz = distparam(15)
        sigpz = distparam(16)
        muzpz = distparam(17)
        zscale = distparam(18)
        pzscale = distparam(19)
        xmu5 = distparam(20)
        xmu6 = distparam(21)

        call getsize_Pgrid2d(grid,totnp,npy,npx)
        call getpost_Pgrid2d(grid,myid,myidy,myidx)
        call getcomm_Pgrid2d(grid,comm2d,commcol,commrow)

        avgpts = this%Npt/(npx*npy)

        sig1 = sigx*xscale
        sig2 = sigpx*pxscale
        sig3 = sigy*yscale
        sig4 = sigpy*pyscale
        sig5 = sigz*zscale
        sig6 = sigpz*pzscale

        sq12=sqrt(1.-muxpx*muxpx)
        sq34=sqrt(1.-muypy*muypy)
        sq56=sqrt(1.-muzpz*muzpz)

        numpts0 = 0

        ! initial allocate 'avgpts' particles on each processor.
        allocate(this%Pts1(6,avgpts))
        this%Pts1 = 0.0
        do ii = 1, avgpts
          ! rejection sample.
10        call random_number(r1)
          call random_number(r2)
          call random_number(r3)
          r1 = 2.0*r1-1.0
          r2 = 2.0*r2-1.0
          r3 = 2.0*r3-1.0
          if(r1**2+r2**2+r3**2.gt.1.0) goto 10
          x2(1) = r1
          x2(2) = r2
          x2(3) = r3
          call normdv2(x1)

          !x-px:
!         Correct Gaussian distribution.
          a(1,1) = xmu1 + sig1*x2(1)/sq12*sqrt(5.0)
          a(2,1) = xmu2 + sig2*(-muxpx*x2(1)/sq12+x1(1))
!         Rob's Gaussian distribution.
          !a(1,1) = xmu1 + sig1*x2(1)*sqrt(5.0)
          !a(2,1) = xmu2 + sig2*(muxpx*x2(1)+sq12*x1(1))
          !y-py
!         Correct Gaussian distribution.
          a(3,1) = xmu3 + sig3*x2(2)/sq34*sqrt(5.0)
          a(4,1) = xmu4 + sig4*(-muypy*x2(2)/sq34+x1(2))
!         Rob's Gaussian distribution.
          !a(3,1) = xmu3 + sig3*x2(2)*sqrt(5.0)
          !a(4,1) = xmu4 + sig4*(muypy*x2(2)+sq34*x1(2))
          !z-pz
!         Correct Gaussian distribution.
          a(5,1) = xmu5 + sig5*x2(3)/sq56*sqrt(5.0)
          a(6,1) = xmu6 + sig6*(-muzpz*x2(3)/sq56+x1(3))
!         Rob's Gaussian distribution.
          !a(5,1) = xmu5 + sig5*x2(3)*sqrt(5.0)
          !a(6,1) = xmu6 + sig6*(muzpz*x2(3)+sq56*x1(3))

          do j = 1, 6
             this%Pts1(j,ii) = a(j,1)
          enddo

        enddo

        numpts0 = avgpts

        this%Nptlocal = numpts0
!        print*,"numpts0: ",numpts0

!        call MPI_BARRIER(comm2d,ierr)
        t_kvdist = t_kvdist + elapsedtime_Timer(t0)

        end subroutine Semigauss_Dist

        subroutine normdv2(y)
        implicit none
        include 'mpif.h'
        double precision, dimension(3), intent(out) :: y
        double precision :: sumtmp,x
        integer :: i

        sumtmp = 0.0
        do i = 1, 12
          call random_number(x)
          sumtmp = sumtmp + x
        enddo
        y(1) = sumtmp - 6.0

        sumtmp = 0.0
        do i = 1, 12
          call random_number(x)
          sumtmp = sumtmp + x
        enddo
        y(2) = sumtmp - 6.0

        sumtmp = 0.0
        do i = 1, 12
          call random_number(x)
          sumtmp = sumtmp + x
        enddo
        y(3) = sumtmp - 6.0

        end subroutine normdv2

        !read in an initial distribution with format (x(m), px/mc, y(m), py/mc,...)
        subroutine read_Dist(this,nparam,distparam)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer, intent(in) :: nparam
        double precision, dimension(nparam) :: distparam
        integer :: i,j,jlow,jhigh,avgpts,myid,nproc,ierr,nptot,nleft
        double precision, dimension(6) :: tmptcl
        double precision :: sum1,sum2
 
        call MPI_COMM_RANK(MPI_COMM_WORLD,myid,ierr)
        call MPI_COMM_SIZE(MPI_COMM_WORLD,nproc,ierr)
 
        open(unit=12,file='partcl.data',status='old')
 
        sum1 = 0.0
        sum2 = 0.0
 
          read(12,*)nptot
          avgpts = nptot/nproc
          nleft = nptot - avgpts*nproc
          if(myid.lt.nleft) then
            avgpts = avgpts+1
            jlow = myid*avgpts + 1
            jhigh = (myid+1)*avgpts
          else
            jlow = myid*avgpts + 1 + nleft
            jhigh = (myid+1)*avgpts + nleft
          endif
          allocate(this%Pts1(6,avgpts))
          this%Pts1 = 0.0
          !jlow = myid*avgpts + 1
          !jhigh = (myid+1)*avgpts
          print*,"avgpts, jlow, and jhigh: ",avgpts,jlow,jhigh
          do j = 1, nptot
            read(12,*)tmptcl(1:6)
            sum1 = sum1 + tmptcl(1)
            sum2 = sum2 + tmptcl(3)
            if( (j.ge.jlow).and.(j.le.jhigh) ) then
              i = j - jlow + 1
              this%Pts1(1:6,i) = tmptcl(1:6)
            endif
!            if(myid.eq.0) print*,i,sum1,sum2
          enddo
          print*,"sumx1,sumy1: ",sum1/nptot,sum2/nptot
 
          close(12)
 
          this%Nptlocal = avgpts
          !change length to the dimensionless unit
          do i = 1, avgpts
            this%Pts1(1,i) = this%Pts1(1,i)/Scxlt + distparam(6)
            this%Pts1(2,i) = this%Pts1(2,i) + distparam(7)
            this%Pts1(3,i) = this%Pts1(3,i)/Scxlt + distparam(13)
            this%Pts1(4,i) = this%Pts1(4,i) + distparam(14)
            this%Pts1(5,i) = this%Pts1(5,i)/Scxlt + distparam(20)
            this%Pts1(6,i) = this%Pts1(6,i)  + distparam(21)
          enddo
 
        end subroutine read_Dist

        !uniform cylinder distribution with 0 termperature
        subroutine Cylcold_Dist(this,nparam,distparam,grid)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer, intent(in) :: nparam
        double precision, dimension(nparam) :: distparam
        type (Pgrid2d), intent(in) :: grid
        double precision  :: sigx,sigpx,muxpx,xscale,sigy,&
        sigpy,muypy, yscale,sigz,sigpz,muzpz,zscale,pxscale,pyscale,pzscale
        double precision :: xmu1,xmu2,xmu3,xmu4,xmu5,xmu6
        double precision, dimension(2) :: gs
        double precision :: sig1,sig2,sig3,sig4,sig5,sig6
        double precision :: rootx,rooty,rootz,x1,x3,cs,ss
        double precision, allocatable, dimension(:) :: r1,r2,r3,r4 
        integer :: totnp,npy,npx
        integer :: avgpts,numpts
        integer :: myid,myidx,myidy,i,ierr
!        integer seedarray(1)
        double precision :: t0,x11,twopi,tmpmax,tmpmaxgl,shiftz
        real*8 :: vx,vy,r44

        call starttime_Timer(t0)

        sigx = distparam(1)
        sigpx = distparam(2)
        muxpx = distparam(3)
        xscale = distparam(4)
        pxscale = distparam(5)
        xmu1 = distparam(6)
        xmu2 = distparam(7)
        sigy = distparam(8)
        sigpy = distparam(9)
        muypy = distparam(10)
        yscale = distparam(11)
        pyscale = distparam(12)
        xmu3 = distparam(13)
        xmu4 = distparam(14)
        sigz = distparam(15)
        sigpz = distparam(16)
        muzpz = distparam(17)
        zscale = distparam(18)
        pzscale = distparam(19)
        xmu5 = distparam(20)
        xmu6 = distparam(21)

        call getsize_Pgrid2d(grid,totnp,npy,npx)

        call getpost_Pgrid2d(grid,myid,myidy,myidx)
!        seedarray(1)=(1001+myid)*(myid+7)
!        write(6,*)'seedarray=',seedarray
!        call random_seed(PUT=seedarray(1:1))
        do i = 1, 3000
          call random_number(x11)
        enddo
!        print*,myid,x11

        avgpts = this%Npt/(npx*npy)

        sig1 = sigx*xscale
        sig2 = sigpx*pxscale
        sig3 = sigy*yscale
        sig4 = sigpy*pyscale
        sig5 = sigz*zscale
        sig6 = sigpz*pzscale

        rootx=sqrt(1.-muxpx*muxpx)
        rooty=sqrt(1.-muypy*muypy)
        rootz=sqrt(1.-muzpz*muzpz)

        ! initial allocate 'avgpts' particles on each processor.
        allocate(this%Pts1(6,avgpts))
        this%Pts1 = 0.0
        twopi = 4*asin(1.0)
        allocate(r1(avgpts))
        call random_number(r1)
        allocate(r2(avgpts))
        call random_number(r2)
        allocate(r3(avgpts))
        call random_number(r3)
        allocate(r4(avgpts))
        call random_number(r4)

        tmpmax = -1.0e10
        do numpts = 1, avgpts
          x1 = sig1*sqrt(r1(numpts))
          x3 = sig3*sqrt(r1(numpts))
          cs = cos(r2(numpts)*twopi)
          ss = sin(r2(numpts)*twopi)
          this%Pts1(1,numpts) = xmu1 + x1*cs
          call normdv1d(vx)
          this%Pts1(2,numpts) = xmu2 + sig2*vx
          !this%Pts1(2,numpts) = 0.0
          this%Pts1(3,numpts) = xmu3 + x3*ss
          call normdv1d(vy)
          this%Pts1(4,numpts) = xmu4 + sig4*vy
!          this%Pts1(4,numpts) = 0.0
          this%Pts1(5,numpts) = xmu5 + sig5*(2*r3(numpts) - 1.0)
          if(tmpmax.lt.this%Pts1(5,numpts)) then
             tmpmax = this%Pts1(5,numpts)
          endif
          !this%Pts1(6,numpts) = xmu6
          r44 = 2*r4(numpts) - 1.0
          this%Pts1(6,numpts) = xmu6 + sig6*r44*sqrt(3.0)
        enddo
        call MPI_ALLREDUCE(tmpmax,tmpmaxgl,1,MPI_DOUBLE_PRECISION,&
                           MPI_MAX,MPI_COMM_WORLD,ierr)
!        print*,"inital max z location of particles: ",tmpmaxgl
!        if(tmpmaxgl.lt.0.0) then 
!          shiftz = -tmpmaxgl
!          do numpts = 1, avgpts
!            this%Pts1(5,numpts) = this%Pts1(5,numpts) + shiftz
!          enddo
!        endif
          
        this%Nptlocal = avgpts
        deallocate(r1)
        deallocate(r2)
        deallocate(r3)
        deallocate(r4)
       
        t_kvdist = t_kvdist + elapsedtime_Timer(t0)

        end subroutine Cylcold_Dist

        subroutine normdv1d(y)
        implicit none
        include 'mpif.h'
        double precision, intent(out) :: y
        double precision :: sumtmp,x
        integer :: i
 
        sumtmp = 0.0
        do i = 1, 12
          call random_number(x)
          sumtmp = sumtmp + x
        enddo
        y = sumtmp - 6.0
 
        end subroutine normdv1d

      end module Distributionclass
