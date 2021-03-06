! submodule (intrn_mod:hi_smod) hibb_smod
module hibb_smod
  
  use :: prcn_mod

  implicit none


  type :: hibb_t
    ! RPY
    real(wp) :: A,B,C,D,E,F
    ! Oseen-Burgers
    real(wp) :: G
    ! regularized OB
    real(wp) :: O,P,R,S,T
    real(wp) :: rmagmin
  end type hibb_t

contains

  ! module procedure init_hibb
  subroutine init_hibb(this)

    use :: inp_dlt, only: HITens,hstar

    class(hibb_t),intent(inout) :: this
    real(wp),parameter :: PI=3.1415926535897958648_wp
    real(wp),parameter :: sqrtPI=sqrt(PI)

    select case (HITens)
      case ('RPY','Blake','Osph')
        ! For Rotne-Prager-Yamakawa Tensor:
        this%A=0.75*hstar*sqrtPI
        this%B=hstar**3*PI*sqrtPI/2
        this%C=(3.0_wp/2)*hstar**3*PI*sqrtPI
        this%D=2*sqrtPI*hstar
        this%E=9/(32*sqrtPI*hstar)
        this%F=3/(32*sqrtPI*hstar)
      case ('OB')
        ! For Oseen-Burgers Tensor:
        this%G=0.75*hstar*sqrtPI
      case  ('RegOB')
        ! For Reguralized Oseen-Burgers Tensor (introduced in HCO book):
        this%G=0.75*hstar*sqrtPI
        this%O=4*PI*hstar**2/3
        this%P=14*PI*hstar**2/3
        this%R=8*PI**2*hstar**4
        this%S=2*PI*hstar**2
        this%T=this%R/3
    end select
    this%rmagmin=1.e-7_wp ! The Minimum value accepted as the |rij|

  ! end procedure init_hibb
  end subroutine init_hibb

  ! module procedure calc_hibb
  subroutine calc_hibb(this,i,j,rij,DiffTens)

    use :: inp_dlt, only: HITens,hstar
    use :: cmn_tp_mod, only: dis

    class(hibb_t),intent(inout) :: this
    integer,intent(in) :: i,j
    type(dis),intent(in) :: rij
    real(wp),intent(out) :: DiffTens(:,:)
    integer :: osi,osj
    real(wp) :: rijmag3,rijmag5
    real(wp) :: Alpha,Beta,Gamm,Zeta,Zeta12,Zeta13,Zeta23
    real(wp) :: Theta,Xi,Xi12,Xi13,Xi23,Rho,Psi,Chi,Chi12,Chi13,Chi23
    real(wp) :: Omicron,Upsilon,Omega,Omega12,Omega13,Omega23


    if (rij%mag<=this%rmagmin) then
      write(*,*) 'Warning: The |rij| is lower than the accepted value in calc_hi'
      write(*,'(1x,a,f7.2,1x,a,f7.2)') '|rij|:',rij%mag,'|rij|min:',this%rmagmin
      write(*,*) i,j
      stop
    end if

    ! Note that the forces are repulsive and for Fi=+ if rij=ri-rj. But, with
    ! the algorithm used above we have used rij=rj-ri, hence we set Fi=-.

    osi=3*(i-1)
    osj=3*(j-1)
    rijmag3=rij%mag2*rij%mag
    rijmag5=rij%mag2*rijmag3

    select case (HITens)
      case ('RPY','Blake','Osph')
        if (rij%mag >= this%D) then
          Alpha=this%A/rij%mag+this%B/rijmag3
          Beta=this%A/rijmag3
          Gamm=this%C/rijmag5
          Zeta=Beta-Gamm
          Zeta12=Zeta*rij%x*rij%y;Zeta13=Zeta*rij%x*rij%z;Zeta23=Zeta*rij%y*rij%z
          DiffTens(osi+1,osj+1)=Alpha+Zeta*rij%x*rij%x
          DiffTens(osi+1,osj+2)=Zeta12;DiffTens(osi+2,osj+1)=Zeta12
          DiffTens(osi+1,osj+3)=Zeta13;DiffTens(osi+3,osj+1)=Zeta13
          DiffTens(osi+2,osj+2)=Alpha+Zeta*rij%y*rij%y
          DiffTens(osi+2,osj+3)=Zeta23;DiffTens(osi+3,osj+2)=Zeta23
          DiffTens(osi+3,osj+3)=Alpha+Zeta*rij%z*rij%z
        else
          Theta=1-this%E*rij%mag;Xi=this%F/rij%mag
          DiffTens(osi+1,osj+1)=1-this%E*rij%mag+this%F*rij%x*rij%x/rij%mag
          Xi12=this%F*rij%x*rij%y/rij%mag
          Xi13=this%F*rij%x*rij%z/rij%mag
          Xi23=this%F*rij%y*rij%z/rij%mag
          DiffTens(osi+1,osj+2)=Xi12;DiffTens(osi+2,osj+1)=Xi12
          DiffTens(osi+1,osj+3)=Xi13;DiffTens(osi+3,osj+1)=Xi13
          DiffTens(osi+2,osj+2)=1-this%E*rij%mag+this%F*rij%y*rij%y/rij%mag
          DiffTens(osi+2,osj+3)=Xi23;DiffTens(osi+3,osj+2)=Xi23
          DiffTens(osi+3,osj+3)=1-this%E*rij%mag+this%F*rij%z*rij%z/rij%mag
        end if
      case ('Zimm')
        Rho=sqrt(2._wp)*hstar*sqrt(1/abs(real(i-j,kind=wp)))
        DiffTens(osi+1,osj+1)=Rho
        DiffTens(osi+1,osj+2)=0._wp;DiffTens(osi+2,osj+1)=0._wp
        DiffTens(osi+1,osj+3)=0._wp;DiffTens(osi+3,osj+1)=0._wp
        DiffTens(osi+2,osj+2)=Rho
        DiffTens(osi+2,osj+3)=0._wp;DiffTens(osi+3,osj+2)=0._wp
        DiffTens(osi+3,osj+3)=Rho
      case ('OB')
        Psi=this%G/rij%mag;Chi=this%G/rijmag3
        Chi12=Chi*rij%x*rij%y;Chi13=Chi*rij%x*rij%z;Chi23=Chi*rij%y*rij%z
        DiffTens(osi+1,osj+1)=Psi+Chi*rij%x*rij%x
        DiffTens(osi+1,osj+2)=Chi12;DiffTens(osi+2,osj+1)=Chi12
        DiffTens(osi+1,osj+3)=Chi13;DiffTens(osi+3,osj+1)=Chi13
        DiffTens(osi+2,osj+2)=Psi+Chi*rij%y*rij%y
        DiffTens(osi+2,osj+3)=Chi23;DiffTens(osi+3,osj+2)=Chi23
        DiffTens(osi+3,osj+3)=Psi+Chi*rij%z*rij%z
      case ('RegOB')
        Omicron=this%G/(rij%mag*(rij%mag**2+this%O)**3)
        Upsilon=Omicron*(rij%mag**6+this%P*rij%mag**4+this%R*rij%mag**2)
        Omega=Omicron*(rij%mag**6+this%S*rij%mag**4-this%T*rij%mag**2)/(rij%mag**2)
        Omega12=Omega*rij%x*rij%y;Omega13=Omega*rij%x*rij%z;Omega23=Omega*rij%y*rij%z
        DiffTens(osi+1,osj+1)=Upsilon+Omega*rij%x*rij%x
        DiffTens(osi+1,osj+2)=Omega12;DiffTens(osi+2,osj+1)=Omega12
        DiffTens(osi+1,osj+3)=Omega13;DiffTens(osi+3,osj+1)=Omega13
        DiffTens(osi+2,osj+2)=Upsilon+Omega*rij%y*rij%y
        DiffTens(osi+2,osj+3)=Omega23;DiffTens(osi+3,osj+2)=Omega23
        DiffTens(osi+3,osj+3)=Upsilon+Omega*rij%z*rij%z
    end select

  ! end procedure calc_hibb
  end subroutine calc_hibb


! end submodule hibb_smod
end module hibb_smod
