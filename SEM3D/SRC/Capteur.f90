!>
!!\file Capteur.f90
!!\brief Permet de manipuler les quantit�s associ�es aux capteurs.
!!\author
!!\version 1.0
!!\date 10/03/2009
!!
!<

module mCapteur

    use sdomain
    use semdatafiles
    use mpi
    use mfields
    use sem_hdf5
    use sem_c_config
    use constants, only : NCAPT_CACHE, M_1_3
    use mshape8
    use mshape27
    implicit none

    public :: save_capteur, evalueSortieCapteur, flushAllCapteurs, create_capteurs
    private ::  flushCapteur
    ! start modifs
    integer, parameter :: CAPT_DIM=26
    ! end modifs
    type :: tCapteur
        type(tCapteur),pointer :: suivant ! pour passer au capteur suivant
        integer :: periode          ! frequence de captation des grandeur
        real, dimension (3) :: Coord  ! localisation du capteur
        character(LEN=20) :: nom      ! nom du capteur
        integer :: n_el ! numero de la maille dans laquelle se trouve le capteur
        ! si le capteur est partage entre plusieurs mailles, une seule suffit (type_calcul=1)
        real :: xi, eta, zeta ! abscisses curvilignes pour le capteur en cas d'interpolation (type_calcul=1)
        integer :: numproc               ! numero du proc localisant le capteur
        integer :: icache
        ! DIM: Solide : 1(t)+3(u)+3(v)+3(a)+1(p)+1(eps_vol)+6(eps_dev)+6(sig_dev)+2(P-S energy)
        !      Fluide : 1(t)+???
        real, dimension(CAPT_DIM, NCAPT_CACHE) :: valuecache
    end type tCapteur

    integer           :: dimCapteur        ! nombre total de capteurs

    type(Tcapteur), pointer :: listeCapteur

    integer,parameter :: fileIdCapteur=200  ! id fichier capteur

    logical :: traces_h5_created
contains


    subroutine create_capteurs(Tdomain)
        implicit none
        type(domain), intent (inout) :: Tdomain
        !
        type(Tcapteur),pointer :: capteur
        type(C_PTR) :: station_next;
        type(sem_station), pointer :: station_ptr
        character(Len=MAX_FILE_SIZE) :: nom
        double precision :: xc, yc, zc, xi, eta, zeta
        character(len=MAX_FILE_SIZE) :: fnamef
        integer :: numproc, numproc_max, ierr, n_el, n_eln, i
        double precision, allocatable, dimension(:,:) :: coordl
        !
        station_next = Tdomain%config%stations
        nullify(listeCapteur)

        ! En reprise on ne recree pas le fichier capteur
        if (Tdomain%TimeD%NtimeMin==0) then
            traces_h5_created = .false.
        else
            traces_h5_created = .true.
        endif
        do while (C_ASSOCIATED(station_next))
            call c_f_pointer(station_next, station_ptr)
            xc = station_ptr%coords(1)
            yc = station_ptr%coords(2)
            zc = station_ptr%coords(3)
            numproc = -1
            call trouve_capteur(Tdomain, xc, yc, zc, n_el, n_eln, xi, eta, zeta)
            ! Cas ou le capteur est dans le maillage
            if (n_el/=-1) then
                numproc = Tdomain%rank
            end if
            call MPI_AllReduce(numproc, numproc_max, 1, MPI_INTEGER, &
                MPI_MAX, Tdomain%communicateur, ierr)
            ! Cas ou le capteur est en dehors du maillage mais < abs(1.1)
            if (numproc_max==-1) then
                n_el = n_eln
                if (n_el/=-1) then
                    numproc = Tdomain%rank
                end if
                call MPI_AllReduce(numproc, numproc_max, 1, MPI_INTEGER, &
                    MPI_MAX, Tdomain%communicateur, ierr)
                ! Re-calcul des coordonnees globales de la station apres
                ! modification des coordonnes locales
                if (n_el/=-1) then
                    allocate(coordl(0:2, 0:Tdomain%n_nodes-1))
                    do i = 0, Tdomain%n_nodes-1
                       coordl(0:2, i) = Tdomain%Coord_Nodes(0:2, Tdomain%specel(n_el)%Control_Nodes(i))
                    enddo
                    if (Tdomain%n_nodes==8) then
                        call shape8_local2global(coordl, xi, eta, zeta, xc, yc, zc)
                    else
                        call shape27_local2global(coordl, xi, eta, zeta, xc, yc, zc)
                    end if
                    deallocate(coordl)
                end if
            end if
            ! Cas ou le capteur est completement en dehors du maillage
            if (numproc_max==-1) then
                if (Tdomain%rank==0) then
                    write(*,*) "One of the station doesn't appear to be on any processor"
                    write(*,*) "Please verify that the station location is within the computation domain"
                end if
                stop 1
            end if


            ! attention si le capteur est partage par plusieurs procs. On choisit le proc de num max
            if(Tdomain%rank==numproc_max) then
                allocate(capteur)
                nom = fromcstr(station_ptr%name)
                capteur%nom = nom(1:20)     ! ses caracteristiques par defaut
                capteur%periode = station_ptr%period
                capteur%coord(1) = xc
                capteur%coord(2) = yc
                capteur%coord(3) = zc
                capteur%xi = xi
                capteur%eta = eta
                capteur%zeta = zeta
                capteur%n_el = n_el
                capteur%numproc = numproc_max
                capteur%icache = 0
                capteur%suivant => listeCapteur
                listeCapteur => capteur
                write(*,"(A,A,A,I5,A,I6,A,F8.4,A,F8.4,A,F8.4)") "Capteur:", trim(capteur%nom), &
                    " on proc ", Tdomain%rank, " in elem ", n_el, " at ", xi, ",", eta, ",", zeta

                ! si c'est un nouveau run, suppression de l'eventuel fichier de sortie des capteurs
                if (Tdomain%traces_format == 1) then
                    if ( .not.Tdomain%logicD%run_restart) then
                        call semname_capteur_type(capteur%nom,".txt",fnamef)
                        open(123,file=trim(fnamef),status="replace",form="formatted")
                        close(123)
                    end if
                end if
            end if

            station_next = station_ptr%next
        end do

    end subroutine create_capteurs


    subroutine evalueSortieCapteur(it, time, sortie_capteur)
        implicit none
        integer, intent(in) :: it
        double precision, intent(in) :: time
        logical, intent(out) :: sortie_capteur
        type(tCapteur),pointer :: capteur

        ! boucle sur les capteurs
        capteur=>listeCapteur

        do while (associated(capteur))
            if (mod(it,capteur%periode)==0) then ! on fait la sortie
                sortie_capteur = .TRUE.
            endif

            capteur=>capteur%suivant
        enddo
    end subroutine evalueSortieCapteur

    !---------------------------------------------------------------------
    !---------------------------------------------------------------------

    !>
    !! \fn subroutine save_capteur(Tdomain)
    !! \brief
    !!
    !! \param type (domain) TDomain
    !<
    subroutine save_capteur(Tdomain, ntime)


        implicit none

        integer :: ntime
        type (domain) :: TDomain

        type(tCapteur),pointer :: capteur
        logical :: do_flush

        do_flush = .false.
        ! boucle sur les capteurs
        capteur=>listeCapteur
        do while (associated(capteur))

            if (mod(ntime, capteur%periode)==0) then ! on fait la sortie
                call sortieGrandeurCapteur_interp(Tdomain, capteur)
                if (capteur%icache==NCAPT_CACHE) do_flush = .true.
            end if
            capteur=>capteur%suivant
        enddo

        if (do_flush) call flushAllCapteurs(Tdomain)

    end subroutine save_capteur

    function dset_capteur_name(capteur)
        implicit none
        type(tCapteur),pointer :: capteur
        character(len=40) :: dset_capteur_name
        dset_capteur_name = trim(adjustl(capteur%nom)) !//"_"//trim(adjustl(capteur%grandeur))
    end function dset_capteur_name

    subroutine create_traces_h5_skel(Tdomain)
        use HDF5
        implicit none
        type (domain), intent(inout) :: TDomain
        type(tCapteur),pointer :: capteur
        character (len=MAX_FILE_SIZE) :: fnamef
        character (len=40) :: dname
        integer(HID_T) :: fid, dset_id
        integer :: hdferr

        call init_hdf5()
        call semname_tracefile_h5(Tdomain%rank, fnamef)

        call h5fcreate_f(fnamef, H5F_ACC_TRUNC_F, fid, hdferr)

        capteur=>listeCapteur
        do while (associated(capteur))
            dname = dset_capteur_name(capteur)
            write(*,*) "Create dset:", trim(adjustl(dname))
            call create_dset_2d(fid, trim(adjustl(dname)), H5T_IEEE_F64LE, &
                int(CAPT_DIM,HSIZE_T), int(H5S_UNLIMITED_F,HSIZE_T), dset_id)
            call h5dclose_f(dset_id, hdferr)
            capteur=>capteur%suivant
        enddo

        call h5fclose_f(fid, hdferr)
    end subroutine create_traces_h5_skel

    subroutine append_traces_h5(Tdomain)
        implicit none
        type (domain), intent(inout) :: TDomain
        type(tCapteur),pointer :: capteur
        character (len=40) :: dname
        character (len=MAX_FILE_SIZE) :: fnamef
        integer(HID_T) :: dset_id, fid
        integer :: hdferr

        call semname_tracefile_h5(Tdomain%rank, fnamef)

        call h5fopen_f(fnamef, H5F_ACC_RDWR_F, fid, hdferr)

        capteur=>listeCapteur
        do while (associated(capteur))
            !write(*,*) "Capteur:", capteur%nom
            dname = dset_capteur_name(capteur)
            if (capteur%icache==0) then
                capteur=>capteur%suivant
                cycle
            endif
            call h5dopen_f(fid, trim(dname), dset_id, hdferr)
            call append_dataset_2d(dset_id, capteur%valuecache(:,1:capteur%icache), hdferr)
            call h5dclose_f(dset_id, hdferr)
            capteur%icache=0
            capteur=>capteur%suivant
        enddo

        call h5fclose_f(fid, hdferr)
    end subroutine append_traces_h5

    subroutine flushAllCapteurs(Tdomain)
        implicit none
        type (domain), intent(inout) :: TDomain
        type(tCapteur),pointer :: capteur

        ! Default unspecified value is 'text'
        if (Tdomain%traces_format == 0) Tdomain%traces_format = 1

        if (Tdomain%traces_format == 1) then
            ! boucle sur les capteurs
            capteur=>listeCapteur
            do while (associated(capteur))
                call flushCapteur(capteur)
                capteur=>capteur%suivant
            enddo
        else
            ! Sauvegarde au format hdf5
            if (associated(listeCapteur)) then
                ! On ne fait rien sur ce proc si on n'a pas de capteur
                if (.not. traces_h5_created) then
                    call create_traces_h5_skel(Tdomain)
                    traces_h5_created = .true.
                end if
                call append_traces_h5(Tdomain)
            end if
        end if
    end subroutine flushAllCapteurs

    subroutine flushCapteur(capteur)
        implicit none
        type(tCapteur),pointer :: capteur
        !
        integer, parameter :: fileId=123
        integer :: j
        character(len=MAX_FILE_SIZE) :: fnamef

        if (capteur%icache==0) return

        call semname_capteur_type(capteur%nom,".txt",fnamef)

        open(fileId,file=trim(fnamef),status="unknown",form="formatted",position="append")
        do j=1,capteur%icache
        ! start modifs
            write(fileId,'(26(1X,E16.8E3))') capteur%valuecache(:,j)
            ! end modifs
        end do
        close(fileId)
        capteur%icache = 0
    end subroutine flushCapteur


    !---------------------------------------------------------------------
    !---------------------------------------------------------------------


    !! effectue l'interpolation des grandeurs dans la maille dans laquelle se trouve le capteur
    !! la maille se trouve dans un seul proc
    !! seul le proc gere l'ecriture
    !!
    subroutine sortieGrandeurCapteur_interp(Tdomain, capteur)
        use mpi
        implicit none

        type(tCapteur) :: capteur
        type (domain) :: TDomain
        integer :: rg

        integer :: i, j, k

        real, dimension(CAPT_DIM-1) :: grandeur
        real, dimension(:,:,:,:), allocatable :: fieldU, fieldV, fieldA
        real, dimension(:,:,:), allocatable :: fieldP
        ! start modifs
        real, dimension(:,:,:), allocatable :: DXX, DXY, DXZ
        real, dimension(:,:,:), allocatable :: DYX, DYY, DYZ
        real, dimension(:,:,:), allocatable :: DZX, DZY, DZZ
        real  :: eps_vol, eps_dev_xx, eps_dev_yy, eps_dev_zz, &
            eps_dev_xy, eps_dev_xz, eps_dev_yz
        real  :: sig_dev_xx, sig_dev_yy, sig_dev_zz, &
            sig_dev_xy, sig_dev_xz, sig_dev_yz
        real  :: P_energy, S_energy

        real, dimension (:,:), allocatable  :: htprimex, hprimey, hprimez
        ! end modifs
        integer :: n_el, ngllx, nglly, ngllz, mat, n_solid
        real :: xi, eta, zeta, weight
        real, dimension(:), allocatable :: outx, outy, outz
        ! start modifs
        logical :: aniso, solid
        real :: xmu, xlambda, xkappa, x2mu, xlambda2mu, onemSbeta, onemPbeta, eps_trace
        ! end modifs
        rg = Tdomain%rank

        ! ETAPE 0 : initialisations
        grandeur(:)=0. ! si maillage vide donc pas de pdg, on fait comme si il y en avait 1

        ! Recuperation du numero de la maille Sem et des abscisses
        n_el = capteur%n_el
        xi = capteur%xi
        eta = capteur%eta
        zeta = capteur%zeta

        ! ETAPE 1 : interpolations

        if((n_el/=-1) .AND. (capteur%numproc==rg)) then
            ngllx = Tdomain%specel(n_el)%ngllx
            nglly = Tdomain%specel(n_el)%nglly
            ngllz = Tdomain%specel(n_el)%ngllz
            allocate(outx(0:ngllx-1))
            allocate(outy(0:nglly-1))
            allocate(outz(0:ngllz-1))
            allocate(fieldU(0:ngllx-1,0:nglly-1,0:ngllz-1,0:2))
            allocate(fieldV(0:ngllx-1,0:nglly-1,0:ngllz-1,0:2))
            allocate(fieldA(0:ngllx-1,0:nglly-1,0:ngllz-1,0:2))
            allocate(fieldP(0:ngllx-1,0:nglly-1,0:ngllz-1))
            allocate(DXX(0:ngllx-1,0:nglly-1,0:ngllz-1))
            allocate(DXY(0:ngllx-1,0:nglly-1,0:ngllz-1))
            allocate(DXZ(0:ngllx-1,0:nglly-1,0:ngllz-1))
            allocate(DYX(0:ngllx-1,0:nglly-1,0:ngllz-1))
            allocate(DYY(0:ngllx-1,0:nglly-1,0:ngllz-1))
            allocate(DYZ(0:ngllx-1,0:nglly-1,0:ngllz-1))
            allocate(DZX(0:ngllx-1,0:nglly-1,0:ngllz-1))
            allocate(DZY(0:ngllx-1,0:nglly-1,0:ngllz-1))
            allocate(DZZ(0:ngllx-1,0:nglly-1,0:ngllz-1))
            allocate(hTprimex(0:ngllx-1,0:ngllx-1))
            allocate(hprimey(0:nglly-1,0:nglly-1))
            allocate(hprimez(0:ngllz-1,0:ngllz-1))

            mat=Tdomain%specel(n_el)%mat_index
            ! end modif

            do i = 0,ngllx - 1
                call  pol_lagrange(ngllx,Tdomain%sSubdomain(mat)%GLLcx,i,xi,outx(i))
            end do
            do j = 0,nglly - 1
                call  pol_lagrange(nglly,Tdomain%sSubdomain(mat)%GLLcy,j,eta,outy(j))
            end do
            do k = 0,ngllz - 1
                call  pol_lagrange(ngllz,Tdomain%sSubdomain(mat)%GLLcz,k,zeta,outz(k))
            end do
            call gather_elem_displ(Tdomain, n_el, fieldU)
            call gather_elem_veloc(Tdomain, n_el, fieldV)
            call gather_elem_accel(Tdomain, n_el, fieldA)
            call gather_elem_press(Tdomain, n_el, fieldP)

            ! start modif
            solid=Tdomain%specel(n_el)%solid
            n_solid=Tdomain%n_sls
            hTprimex=Tdomain%sSubDomain(mat)%hTprimex
            hprimey=Tdomain%sSubDomain(mat)%hprimey
            hprimez=Tdomain%sSubDomain(mat)%hprimez
            aniso=Tdomain%aniso

            if((solid) .and. (.not. Tdomain%specel(n_el)%PML))then   ! SOLID PART OF THE DOMAIN
                call physical_part_deriv(ngllx,nglly,ngllz,htprimex,hprimey,hprimez,Tdomain%specel(n_el)%InvGrad,fieldU(:,:,:,0),DXX,DYX,DZX)
                call physical_part_deriv(ngllx,nglly,ngllz,htprimex,hprimey,hprimez,Tdomain%specel(n_el)%InvGrad,fieldU(:,:,:,1),DXY,DYY,DZY)
                call physical_part_deriv(ngllx,nglly,ngllz,htprimex,hprimey,hprimez,Tdomain%specel(n_el)%InvGrad,fieldU(:,:,:,2),DXZ,DYZ,DZZ)
            endif
            eps_vol = 0
            eps_dev_xx = 0
            eps_dev_yy = 0
            eps_dev_zz = 0
            eps_dev_xy = 0
            eps_dev_xz = 0
            eps_dev_yz = 0

            sig_dev_xx = 0
            sig_dev_yy = 0
            sig_dev_zz = 0
            sig_dev_xy = 0
            sig_dev_xz = 0
            sig_dev_yz = 0

            P_energy = 0
            S_energy = 0

            ! end modif

            do i = 0,ngllx - 1
                do j = 0,nglly - 1
                    do k = 0,ngllz - 1
                        weight = outx(i)*outy(j)*outz(k)
                        grandeur(1:3) = grandeur(1:3) + weight*fieldU(i,j,k,:)
                        grandeur(4:6) = grandeur(4:6) + weight*fieldV(i,j,k,:)
                        grandeur(7:9) = grandeur(7:9) + weight*fieldA(i,j,k,:)
                        grandeur(10 ) = grandeur( 10) + weight*fieldP(i,j,k)
                        ! start modif
                        if ((solid) .and. (.not. Tdomain%specel(n_el)%PML)) then
                            eps_trace = DXX(i,j,k) + DYY(i,j,k) + DZZ(i,j,k)
                            eps_vol = eps_trace
                            eps_dev_xx = DXX(i,j,k) - eps_vol / 3
                            eps_dev_yy = DYY(i,j,k) - eps_vol / 3
                            eps_dev_zz = DZZ(i,j,k) - eps_vol / 3
                            eps_dev_xy = 0.5 * (DXY(i,j,k) + DYX(i,j,k))
                            eps_dev_xz = 0.5 * (DZX(i,j,k) + DXZ(i,j,k))
                            eps_dev_yz = 0.5 * (DZY(i,j,k) + DYZ(i,j,k))
                            if (aniso) then
                            else
                                xmu     = Tdomain%specel(n_el)%Mu(i,j,k)
                                xlambda = Tdomain%specel(n_el)%Lambda(i,j,k)
                                xkappa  = Tdomain%specel(n_el)%Kappa(i,j,k)

                                if (n_solid>0) then
                                    onemSbeta=Tdomain%specel(n_el)%sl%onemSbeta(i,j,k)
                                    onemPbeta=Tdomain%specel(n_el)%sl%onemPbeta(i,j,k)
                                    !  mu_relaxed -> mu_unrelaxed
                                    xmu    = xmu * onemSbeta
                                    !  kappa_relaxed -> kappa_unrelaxed
                                    xkappa = xkappa * onemPbeta
                                endif
                                x2mu       = 2. * xmu
                                xlambda2mu = xlambda + x2mu

                                sig_dev_xx = xlambda2mu * DXX(i,j,k) + xlambda * (DYY(i,j,k) + DZZ(i,j,k))
                                sig_dev_yy = xlambda2mu * DYY(i,j,k) + xlambda * (DXX(i,j,k) + DZZ(i,j,k))
                                sig_dev_zz = xlambda2mu * DZZ(i,j,k) + xlambda * (DXX(i,j,k) + DYY(i,j,k))
                                sig_dev_xy = xmu * (DXY(i,j,k) + DYX(i,j,k))
                                sig_dev_xz = xmu * (DXZ(i,j,k) + DZX(i,j,k))
                                sig_dev_yz = xmu * (DYZ(i,j,k) + DZY(i,j,k))

                                P_energy = .5 * xlambda2mu * eps_trace**2
                                S_energy = xmu * ((DXX(i,j,k) - eps_trace/ 3)**2 + &
                                                       (DYY(i,j,k) - eps_trace/ 3)**2 + &
                                                       (DZZ(i,j,k) - eps_trace/ 3)**2 + &
                                                        DXY(i,j,k)**2 + DYX(i,j,k)**2 + &
                                                        DXZ(i,j,k)**2 + DZX(i,j,k)**2 + &
                                                        DYZ(i,j,k)**2 + DZY(i,j,k)**2)

                            endif
                        endif
                        grandeur(11:23) = grandeur (11:23) + (/weight*eps_vol, &
                              weight*eps_dev_xx, weight*eps_dev_yy, weight*eps_dev_zz, &
                              weight*eps_dev_xy, weight*eps_dev_xz, weight*eps_dev_yz, &
                              weight*sig_dev_xx, weight*sig_dev_yy, weight*sig_dev_zz, &
                              weight*sig_dev_xy, weight*sig_dev_xz, weight*sig_dev_yz/)
                        ! end modif
                    enddo
                enddo
            enddo



            deallocate(outx)
            deallocate(outy)
            deallocate(outz)
            deallocate(fieldU)
            deallocate(fieldV)
            deallocate(fieldA)
            deallocate(fieldP)
            if (allocated(DXX)) deallocate(DXX)
            if (allocated(DXY)) deallocate(DXY)
            if (allocated(DXZ)) deallocate(DXZ)
            if (allocated(DYX)) deallocate(DYX)
            if (allocated(DYY)) deallocate(DYY)
            if (allocated(DYZ)) deallocate(DYZ)
            if (allocated(DZX)) deallocate(DZX)
            if (allocated(DZY)) deallocate(DZY)
            if (allocated(DZZ)) deallocate(DZZ)
            if (allocated(hTprimex)) deallocate(hTprimex)
            if (allocated(hprimey)) deallocate(hprimey)
            if (allocated(hprimez)) deallocate(hprimez)

            i = capteur%icache+1
            capteur%valuecache(1,i) = Tdomain%TimeD%rtime
            ! start modifs
            capteur%valuecache(2:26,i) = grandeur(:)
            ! end modifs
            capteur%icache = i
        endif

    end subroutine sortieGrandeurCapteur_interp

    !!on identifie la maille dans laquelle se trouve le capteur. Il peut y en avoir plusieurs,
    !! alors le capteur est sur une face, arete ou sur un sommet
    !!
    subroutine trouve_capteur(Tdomain, xc, yc, zc, n_el, n_eln, xi, eta, zeta)
        use mshape8
        use mshape27
        use mlocations3d
        implicit none
        type (domain), INTENT(INOUT)  :: Tdomain
        double precision, intent(in) :: xc, yc, zc
        integer, intent(out) :: n_el, n_eln
        double precision, intent(out) :: xi, eta, zeta
        !
        integer :: i
        logical :: inside
        integer :: nmax
        integer, parameter :: NMAXEL=20
        integer, dimension(NMAXEL) :: elems
        double precision, dimension(0:2,NMAXEL) :: coordloc
        double precision, parameter :: EPS = 1D-13, EPSN = 0.1D0

        nmax = NMAXEL
        call find_location(Tdomain, xc, yc, zc, nmax, elems, coordloc)
        n_el = -1
        n_eln = -1
        ! Cas ou la station est dans le maillage
        do i=1,nmax
            inside = .true.
            xi   = coordloc(0,i)
            eta  = coordloc(1,i)
            zeta = coordloc(2,i)
            if (xi<(-1-EPS) .or. eta<(-1-EPS) .or. zeta<(-1-EPS)) inside = .false.
            if (xi>(1+EPS) .or. eta>(1+EPS) .or. zeta>(1+EPS)) inside = .false.
            if (inside) then
                n_el = elems(i)
                return
            end if
        end do
        ! Cas ou la station est en dehors du maillage mais < abs(1.1)
        do i=1,nmax
            xi   = coordloc(0,i)
            eta  = coordloc(1,i)
            zeta = coordloc(2,i)
            if (abs(xi)<(1+EPS) .and. abs(eta)<(1+EPS) .and. abs(zeta)<(1+EPSN)) then
                if (zeta<0) zeta = -1.D0
                if (zeta>0) zeta = 1.D0
                n_eln = elems(i)
                return
            else if (abs(xi)<(1+EPS) .and. abs(eta)<(1+EPSN) .and. abs(zeta)<(1+EPS)) then
                if (eta<0) eta = -1.D0
                if (eta>0) eta = 1.D0
                n_eln = elems(i)
                return
            else if (abs(xi)<(1+EPSN) .and. abs(eta)<(1+EPS) .and. abs(zeta)<(1+EPS)) then
                if (xi<0) xi = -1.D0
                if (xi>0) xi = 1.D0
                n_eln = elems(i)
                return
            end if
        end do
        return
    end subroutine trouve_capteur

end module Mcapteur
!! Local Variables:
!! mode: f90
!! show-trailing-whitespace: t
!! f90-do-indent: 4
!! f90-if-indent: 4
!! f90-type-indent: 4
!! f90-program-indent: 4
!! f90-continuation-indent: 4
!! End:
!! vim: set sw=4 ts=8 et tw=80 smartindent : !!
