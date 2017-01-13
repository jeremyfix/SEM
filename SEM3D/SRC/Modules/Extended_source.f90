module sextended_sources

    use constants
    implicit none

    type :: Extended_source

       ! GENERAL PARAMETERS
       integer                              :: Ns                      ! Nb of points in the 1st direction
       integer                              :: Nd                      ! Nb of points in the 2nd direction
       integer                              :: Npt                     ! Total number of points source

       ! ANGLE PARAMETERS
       real                                 :: dip, strike, rake       ! Fault slip orientation

       ! TIME PARAMETERS
       real                                 :: Dt                      ! Time-step from data
       real                                 :: Tfin                    ! Final time for slip history

       ! EXTERNAL DATA FILES
       character(len = 30)                  :: kine_file               ! file name of the Kinetic File
       character(len = 30)                  :: slip_file               ! file name of the Slip Time File

    end type Extended_Source

contains

end module sextended_sources

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
