!! This file is part of SEM
!!
!! Copyright CEA, ECP, IPGP
!!
!>
!!\file compute_GLL.f90
!!\brief Contient la routine compute_GLL().
!!\author
!!\version 1.0
!!\date 10/03/2009
!!
!<
subroutine compute_GLL(Tdomain)
    use sdomain
    use splib, only : zelegl, welegl, dmlegl
    implicit none
    type(domain), intent(inout) :: Tdomain

    integer ::  ngll, i, ndomains
    real, dimension(:), allocatable :: gllpol

    ndomains = Tdomain%n_mat
    do i = 0, ndomains-1
        !- x-part
        ngll = Tdomain%sSubdomain(i)%NGLL
        allocate(Tdomain%sSubdomain(i)%GLLcx(0:ngll-1))
        allocate(GLLpol(0:ngll-1))
        allocate(Tdomain%sSubdomain(i)%GLLwx(0:ngll-1))
        allocate(Tdomain%sSubdomain(i)%hprimex(0:ngll-1,0:ngll-1))
        allocate(Tdomain%sSubdomain(i)%hTprimex(0:ngll-1,0:ngll-1))

        ! USING FUNARO SUBROUTINES
        ! ZELEGL computes the coordinates of GLL points
        ! WELEGL computes the respective weights
        ! DMLEGL compute the matrix of the first derivatives in GLL points

        call zelegl (ngll-1,Tdomain%sSubdomain(i)%GLLcx, GLLpol)
        call welegl (ngll-1, Tdomain%sSubdomain(i)%GLLcx, GLLpol, Tdomain%sSubdomain(i)%GLLwx)
        call dmlegl (ngll-1, ngll-1, Tdomain%sSubdomain(i)%GLLcx, GLLpol, Tdomain%sSubdomain(i)%hTprimex)

        Tdomain%sSubdomain(i)%hprimex =  TRANSPOSE ( Tdomain%sSubdomain(i)%hTprimex )

        deallocate (GLLpol)
    enddo
end subroutine compute_GLL

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
