!! This file is part of SEM
!!
!! Copyright CEA, ECP, IPGP
!!

#ifndef PROCNAME
#error "Must define PROCNAME before inclusion"
#endif

#undef ngllvar
#ifndef NGLLVAL
#define ngllvar ngll
#else
#define ngllvar ngll0
#endif

subroutine PROCNAME(ngllvar,bnum,nblocks,nglltot,ForcesPML,Idom,Diagonal_Stress,Residual_Stress,InvGrad,Jacob,GLLw,hprime)
    use champs_solid
    use nonlinear
    implicit none

    integer, intent(in) :: bnum, nblocks, nglltot
    integer, intent(in) :: ngllvar
#ifdef NGLLVAL
    integer, parameter :: ngll=NGLLVAL
#endif
    real(fpp), intent(inout), dimension(0:nglltot,0:2,0:2) :: ForcesPML
    real(fpp), intent(in), dimension(0:VCHUNK-1,0:2,0:ngll-1,0:ngll-1,0:ngll-1,0:nblocks-1) :: Diagonal_Stress
    real(fpp), intent(in), dimension(0:VCHUNK-1,0:2,0:ngll-1,0:ngll-1,0:ngll-1,0:nblocks-1) :: Residual_Stress
    real(fpp), intent(in), dimension(0:VCHUNK-1,0:2,0:2,0:ngll-1,0:ngll-1,0:ngll-1,0:nblocks-1) :: InvGrad
    real(fpp), intent(in), dimension(0:VCHUNK-1,0:ngll-1,0:ngll-1,0:ngll-1,0:nblocks-1) :: Jacob
    real(fpp), intent(in), dimension(0:ngll-1) :: GLLw
    real(fpp), intent(in), dimension(0:ngll-1,0:ngll-1) :: hprime
    integer, intent(in), dimension(0:VCHUNK-1,0:ngll-1,0:ngll-1,0:ngll-1,0:nblocks-1) :: Idom
    !
    integer :: i, j, k, l, ind, e, ee
    real(fpp) :: sum_vx, sum_vy, sum_vz, acoeff
    real(fpp), dimension(0:VCHUNK-1,0:2,0:ngll-1,0:ngll-1,0:ngll-1)  :: Forces1, Forces2, Forces3


    Forces1 = 0d0
    do k = 0,ngll-1
        do j = 0,ngll-1
            do i=0,ngll-1
#if VCHUNK>1
                !$omp simd linear(e,ee) private(sum_vx,sum_vy,sum_vz,acoeff)
#endif
                BEGIN_SUBELEM_LOOP(e,ee,bnum)
                sum_vx = 0d0
                sum_vy = 0d0
                sum_vz = 0d0
                do l = 0,ngll-1
                    acoeff = - hprime(i,l)*GLLw(l)*GLLw(j)*GLLw(k)*Jacob(ee,l,j,k,bnum)
                    sum_vx = sum_vx + acoeff*InvGrad(ee,0,0,l,j,k,bnum)*Diagonal_Stress(ee,0,l,j,k,bnum)
                    sum_vx = sum_vx + acoeff*InvGrad(ee,1,0,l,j,k,bnum)*Residual_Stress(ee,0,l,j,k,bnum)
                    sum_vx = sum_vx + acoeff*InvGrad(ee,2,0,l,j,k,bnum)*Residual_Stress(ee,1,l,j,k,bnum)

                    sum_vy = sum_vy + acoeff*InvGrad(ee,0,0,l,j,k,bnum)*Residual_Stress(ee,0,l,j,k,bnum)
                    sum_vy = sum_vy + acoeff*InvGrad(ee,1,0,l,j,k,bnum)*Diagonal_Stress(ee,1,l,j,k,bnum)
                    sum_vy = sum_vy + acoeff*InvGrad(ee,2,0,l,j,k,bnum)*Residual_Stress(ee,2,l,j,k,bnum)

                    sum_vz = sum_vz + acoeff*InvGrad(ee,0,0,l,j,k,bnum)*Residual_Stress(ee,1,l,j,k,bnum)
                    sum_vz = sum_vz + acoeff*InvGrad(ee,1,0,l,j,k,bnum)*Residual_Stress(ee,2,l,j,k,bnum)
                    sum_vz = sum_vz + acoeff*InvGrad(ee,2,0,l,j,k,bnum)*Diagonal_Stress(ee,2,l,j,k,bnum)
                end do
                Forces1(ee,0,i,j,k) = sum_vx
                Forces1(ee,1,i,j,k) = sum_vy
                Forces1(ee,2,i,j,k) = sum_vz
                END_SUBELEM_LOOP()
            end do
        end do
    end do

    Forces2 = 0d0
    do k = 0,ngll-1
        do l = 0,ngll-1
            do j = 0,ngll-1
                do i=0,ngll-1
#if VCHUNK>1
                    !$omp simd linear(e,ee) private(sum_vx,sum_vy,sum_vz,acoeff)
#endif
                    BEGIN_SUBELEM_LOOP(e,ee,bnum)
                    acoeff = - hprime(j,l)*GLLw(i)*GLLw(l)*GLLw(k)*Jacob(ee,i,l,k,bnum)
                    sum_vx = acoeff*(InvGrad(ee,0,1,i,l,k,bnum)*Diagonal_Stress(ee,0,i,l,k,bnum) + &
                        InvGrad(ee,1,1,i,l,k,bnum)*Residual_Stress(ee,0,i,l,k,bnum) + &
                        InvGrad(ee,2,1,i,l,k,bnum)*Residual_Stress(ee,1,i,l,k,bnum))

                    sum_vy = acoeff*(InvGrad(ee,0,1,i,l,k,bnum)*Residual_Stress(ee,0,i,l,k,bnum) + &
                        InvGrad(ee,1,1,i,l,k,bnum)*Diagonal_Stress(ee,1,i,l,k,bnum) + &
                        InvGrad(ee,2,1,i,l,k,bnum)*Residual_Stress(ee,2,i,l,k,bnum))

                    sum_vz = acoeff*(InvGrad(ee,0,1,i,l,k,bnum)*Residual_Stress(ee,1,i,l,k,bnum) + &
                        InvGrad(ee,1,1,i,l,k,bnum)*Residual_Stress(ee,2,i,l,k,bnum) + &
                        InvGrad(ee,2,1,i,l,k,bnum)*Diagonal_Stress(ee,2,i,l,k,bnum))
                    Forces2(ee,0,i,j,k) = Forces2(ee,0,i,j,k) + sum_vx
                    Forces2(ee,1,i,j,k) = Forces2(ee,1,i,j,k) + sum_vy
                    Forces2(ee,2,i,j,k) = Forces2(ee,2,i,j,k) + sum_vz
                    END_SUBELEM_LOOP()
                end do
            end do
        end do
    end do

    ! TODO reorder loops ?
    Forces3 = 0
    do l = 0,ngll-1
        do k = 0,ngll-1
            do j = 0,ngll-1
                do i=0,ngll-1
#if VCHUNK>1
                    !$omp simd linear(e,ee) private(sum_vx,sum_vy,sum_vz,acoeff)
#endif
                    BEGIN_SUBELEM_LOOP(e,ee,bnum)
                    acoeff = - hprime(k,l)*GLLw(i)*GLLw(j)*GLLw(l)*Jacob(ee,i,j,l,bnum)
                    sum_vx = acoeff*(InvGrad(ee,0,2,i,j,l,bnum)*Diagonal_Stress(ee,0,i,j,l,bnum) + &
                        InvGrad(ee,1,2,i,j,l,bnum)*Residual_Stress(ee,0,i,j,l,bnum) + &
                        InvGrad(ee,2,2,i,j,l,bnum)*Residual_Stress(ee,1,i,j,l,bnum))

                    sum_vy = acoeff*(InvGrad(ee,0,2,i,j,l,bnum)*Residual_Stress(ee,0,i,j,l,bnum) + &
                        InvGrad(ee,1,2,i,j,l,bnum)*Diagonal_Stress(ee,1,i,j,l,bnum) + &
                        InvGrad(ee,2,2,i,j,l,bnum)*Residual_Stress(ee,2,i,j,l,bnum))

                    sum_vz = acoeff*(InvGrad(ee,0,2,i,j,l,bnum)*Residual_Stress(ee,1,i,j,l,bnum) + &
                        InvGrad(ee,1,2,i,j,l,bnum)*Residual_Stress(ee,2,i,j,l,bnum) + &
                        InvGrad(ee,2,2,i,j,l,bnum)*Diagonal_Stress(ee,2,i,j,l,bnum))
                    Forces3(ee,0,i,j,k) = Forces3(ee,0,i,j,k) + sum_vx
                    Forces3(ee,1,i,j,k) = Forces3(ee,1,i,j,k) + sum_vy
                    Forces3(ee,2,i,j,k) = Forces3(ee,2,i,j,k) + sum_vz
                    END_SUBELEM_LOOP()
                end do
            end do
        end do
    end do

    ! Assemblage
    do k = 0,ngll-1
        do j = 0,ngll-1
            do i = 0,ngll-1
                BEGIN_SUBELEM_LOOP(e,ee,bnum)
                ind = Idom(ee,i,j,k,bnum)
                ForcesPML(ind,:,0) = ForcesPML(ind,:,0) + Forces1(ee,:,i,j,k)
                ForcesPML(ind,:,1) = ForcesPML(ind,:,1) + Forces2(ee,:,i,j,k)
                ForcesPML(ind,:,2) = ForcesPML(ind,:,2) + Forces3(ee,:,i,j,k)
                END_SUBELEM_LOOP()
            enddo
        enddo
    enddo
end subroutine PROCNAME
!! Local Variables:
!! mode: f90
!! show-trailing-whitespace: t
!! coding: utf-8
!! f90-do-indent: 4
!! f90-if-indent: 4
!! f90-type-indent: 4
!! f90-program-indent: 4
!! f90-continuation-indent: 4
!! End:
!! vim: set sw=4 ts=8 et tw=80 smartindent :