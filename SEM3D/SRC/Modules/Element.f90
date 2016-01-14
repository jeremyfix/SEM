!! This file is part of SEM
!!
!! Copyright CEA, ECP, IPGP
!!
!>
!!\file Element.f90
!!\brief contient les méthodes qui assure la gestion du type Element.
!!\author
!!\version 1.0
!!\date 10/03/2009
!!
!<

module selement
    use deriv3d
    use blas
    implicit none

    type :: element_solid
        real, dimension(:,:,:,:), allocatable :: Cij

        ! Attenuation
        real, dimension (:,:,:), allocatable :: Q, Qs, Qp, onemSbeta, onemPbeta, &
            epsilonvol_, &
            epsilondev_xx_,epsilondev_yy_,epsilondev_xy_,epsilondev_xz_,epsilondev_yz_

        real, dimension(:,:,:,:), allocatable :: &
            factor_common_3, alphaval_3,betaval_3,gammaval_3, R_xx_,R_yy_,R_xy_,R_xz_,R_yz_, &
            factor_common_P, alphaval_P,betaval_P,gammaval_P, R_vol_

    end type element_solid

    type :: element_pml
        real, dimension(:,:,:,:), allocatable :: DumpSx,DumpSy,DumpSz
        real, dimension(:,:,:,:), allocatable :: DumpMass
    end type element_pml

    type :: element_solid_pml
        ! TODO move pml related data here
        real, dimension(:,:,:,:), allocatable :: Diagonal_Stress1, Diagonal_Stress2, Diagonal_Stress3
        real, dimension(:,:,:,:), allocatable :: Residual_Stress1, Residual_Stress2, Residual_Stress3
        ! FPML
        real, dimension(:,:,:,:), allocatable :: Diagonal_Stress, Residual_Stress
    end type element_solid_pml

    type :: element
        integer :: ngllx, nglly, ngllz
        integer :: mat_index
        integer :: lnum ! local number of element within its domain
        integer :: domain ! Type de domaine, voir constants : DOM_SOLID, DOM_FLUID, ...
        type(element_solid), allocatable :: sl
        ! Index of a gll node within the physical domain
        integer, dimension (:,:,:), allocatable :: Idom
        real, dimension (:,:,:), allocatable :: Jacob
        real, dimension(:,:,:,:,:), allocatable :: InvGrad
        real, dimension (:,:,:), allocatable :: Density, MassMat
        real, dimension (:,:,:), allocatable :: Lambda, Mu, Kappa

        type(element_pml), allocatable :: xpml
        type(element_solid_pml), allocatable :: slpml

        ! Whether this element will be part of snapshot outputs
        logical :: OUTPUT

        ! These should not be used during the simulation, only at init time
        integer, dimension (:), allocatable :: Control_nodes
        integer, dimension (0:5) :: Near_Faces
        integer, dimension (0:11) :: Near_Edges
        integer, dimension (0:7) :: Near_Vertices

        ! Index of a gll node within the global nodes array
        integer, dimension (:,:,:), allocatable :: Iglobnum
    end type element

contains

    subroutine init_element(el)
        type(element), intent(inout) :: el

        el%mat_index=-1
        el%domain = -1
        el%ngllx=0
        el%nglly=0
        el%ngllz=0

    end subroutine init_element

end module selement


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
