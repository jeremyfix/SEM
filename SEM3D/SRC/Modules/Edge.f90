!! This file is part of SEM
!!
!! Copyright CEA, ECP, IPGP
!!
!>
!! \file Edge.f90
!! \brief
!!
!<

module sedges

    type :: edge

       logical :: PML, Abs, FPML

       integer :: ngll,mat_index
       integer, dimension (:), allocatable :: Iglobnum_Edge

       ! Lien entre ngll et numérotation des champs globaux
       integer, dimension (:), allocatable :: Renum

       ! solid-fluid
       logical  :: solid, fluid_dirich


       !! Couplage Externe
!       real, dimension (:,:), allocatable :: ForcesExt
!       real, dimension (:), allocatable :: tsurfsem

    end type edge

contains

    ! ###########################################################
    subroutine init_edge(ed)
        type(Edge), intent(inout) :: ed

        ed%PML = .false.
        ed%Abs = .false.
        ed%FPML = .false.
        ed%ngll = 0
        ed%solid = .true.
    end subroutine init_edge

end module sedges

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
