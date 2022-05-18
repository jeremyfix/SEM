!>
!!\file champs_solid_dg.f90
!!\brief Contient la définition du type champs pour un domaine solide
!!
!<

module champs_solid_dg

    use constants
    use mdombase
    implicit none

    type :: champssolid_dg
        !! Solide CG
        real(fpp), dimension(:,:), allocatable :: Forces
        real(fpp), dimension(:,:), allocatable :: Depla
        real(fpp), dimension(:,:), allocatable :: Veloc
        !! Solide DG
        !!real(fpp), dimension(:,:,:,:,:), allocatable :: Forces
        !!real(fpp), dimension(:,:,:,:,:), allocatable :: Depla
        !!real(fpp), dimension(:,:,:,:,:), allocatable :: Veloc
        

    end type champssolid_dg

    !! ATTENTION: voir index.h en ce qui concerne les champs dont les noms commencent par m_
    type, extends(dombase) :: domain_solid_dg
        ! D'abord, les données membres qui ne sont pas modifiées
        logical :: aniso
        real(fpp), dimension (:,:,:,:,:), allocatable :: m_Lambda, m_Mu, m_Density

        ! Champs
        type(champssolid_dg), dimension(0:1) :: champs
    end type domain_solid_dg

    contains

end module champs_solid_dg

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
!! vim: set sw=4 ts=8 et tw=80 smartindent : !!