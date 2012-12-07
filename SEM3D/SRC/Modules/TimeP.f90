module stimeparam


    type :: time

       logical :: acceleration_scheme, velocity_scheme
       integer :: ntimeMax, NtimeMin, nSnap, ntrace, ncheck
       real :: alpha, beta, gamma, duration, Time_snapshots, dtmin, rtime

    end type time

end module stimeparam
!! Local Variables:
!! mode: f90
!! show-trailing-whitespace: t
!! End:
!! vim: set sw=4 ts=8 et tw=80 smartindent : !!
