!! This file is part of SEM
!!
!! Copyright CEA, ECP, IPGP
!!
!>
!! \file forces_int.f90
!! \brief
!! \author
!! \version 1.0
!! \date
!!
!<
module forces_aniso
    use deriv3d
    use sdomain
    use schamps
    implicit none

contains

    subroutine forces_int(Elem, mat, htprimex, hprimey, htprimey, hprimez, htprimez,  &
        n_solid, aniso, solid, champs1, nl_flag)

        type (Element), intent (INOUT) :: Elem
        type (subdomain), intent(IN) :: mat
        real, dimension (0:Elem%ngllx-1, 0:Elem%ngllx-1), intent (IN) :: htprimex
        real, dimension (0:Elem%nglly-1, 0:Elem%nglly-1), intent (IN) :: hprimey, htprimey
        real, dimension (0:Elem%ngllz-1, 0:Elem%ngllz-1), intent (IN) :: hprimez, hTprimez
        integer, intent(IN) :: n_solid
        logical, intent(IN) :: aniso
        logical, intent(IN) :: solid   ! flag : solid or fluid element?
        type(champs), intent(inout) :: champs1

        integer :: m1,m2,m3, i,j,k,i_dir
        real :: epsilon_trace_over_3
        real, dimension (0:Elem%ngllx-1, 0:Elem%nglly-1, 0:Elem%ngllz-1) ::  DXX,DXY,DXZ, &
            DYX,DYY,DYZ, &
            DZX,DZY,DZZ, &
            Fox,Foy,Foz, &
            dPhiX,dPhiY,dPhiZ,Fo_Fl

        real, dimension(:,:,:), allocatable :: epsilondev_xx_loc, epsilondev_yy_loc, &
            epsilondev_xy_loc, epsilondev_xz_loc, epsilondev_yz_loc
        real, dimension(:,:,:), allocatable :: epsilonvol_loc
        real, dimension(:,:,:,:), allocatable :: Depla
        real, dimension(:,:,:), allocatable :: Phi
        integer, intent(in) :: nl_flag
        real, dimension(:,:,:,:), allocatable :: Sigma_ij_N_el, Xkin_ij_N_el, EpsPl_ij_N_el
        real, dimension(:,:,:),   allocatable :: Riso_N_el, PlastMult_N_el

        m1 = Elem%ngllx;   m2 = Elem%nglly;   m3 = Elem%ngllz

        if(solid)then   ! SOLID PART OF THE DOMAIN
            allocate(Depla(0:m1-1,0:m2-1,0:m3-1,0:2))
            do i_dir = 0,2
                do k = 0,m3-1
                    do j = 0,m2-1
                        do i = 0,m1-1
                            Depla(i,j,k,i_dir) = champs1%Depla(Elem%Isol(i,j,k),i_dir)
                        enddo
                    enddo
                enddo
            enddo

            call physical_part_deriv(m1,m2,m3,htprimex,hprimey,hprimez,Elem%InvGrad,Depla(:,:,:,0),dxx,dyx,dzx)
            call physical_part_deriv(m1,m2,m3,htprimex,hprimey,hprimez,Elem%InvGrad,Depla(:,:,:,1),dxy,dyy,dzy)
            call physical_part_deriv(m1,m2,m3,htprimex,hprimey,hprimez,Elem%InvGrad,Depla(:,:,:,2),dxz,dyz,dzz)
            deallocate(Depla)

            if (nl_flag == 1) then
                allocate(EpsPl_ij_N_el(0:5,0:m1-1,0:m2-1,0:m3-1))
                allocate(Sigma_ij_N_el(0:5,0:m1-1,0:m2-1,0:m3-1))
                allocate(Xkin_ij_N_el(0:5,0:m1-1,0:m2-1,0:m3-1))
                allocate(Riso_N_el(0:m1-1,0:m2-1,0:m3-1))

                do k = 0,m3-1
                    do j = 0,m2-1
                        do i = 0,m1-1
                            Riso_N_el(i,j,k) = champs1%Riso(Elem%Isol(i,j,k))
                            do i_dir = 0,5
                                EpsPl_ij_N_el(i_dir,i,j,k) = champs1%Epsilon_pl(Elem%Isol(i,j,k),i_dir)
                                Sigma_ij_N_el(i_dir,i,j,k) = champs1%Stress(Elem%Isol(i,j,k),i_dir)
                                Xkin_ij_N_el(i_dir,i,j,k)  = champs1%Xkin(Elem%Isol(i,j,k),i_dir)
                            enddo
                        enddo
                    enddo
                enddo
            end if
            ! ! !

            if (n_solid>0) then
                if (aniso) then
                else
                    allocate (epsilonvol_loc(0:m1-1,0:m2-1,0:m3-1))
                endif
                allocate (epsilondev_xx_loc(0:m1-1,0:m2-1,0:m3-1))
                allocate (epsilondev_yy_loc(0:m1-1,0:m2-1,0:m3-1))
                allocate (epsilondev_xy_loc(0:m1-1,0:m2-1,0:m3-1))
                allocate (epsilondev_xz_loc(0:m1-1,0:m2-1,0:m3-1))
                allocate (epsilondev_yz_loc(0:m1-1,0:m2-1,0:m3-1))
                do i = 0,m1-1
                    do j = 0,m2-1
                        do k = 0,m3-1
                            epsilon_trace_over_3 = 0.333333333333333333333333333333d0 * (DXX(i,j,k) + DYY(i,j,k) + DZZ(i,j,k))
                            if (aniso) then
                            else
                                epsilonvol_loc(i,j,k) = DXX(i,j,k) + DYY(i,j,k) + DZZ(i,j,k)
                            endif
                            epsilondev_xx_loc(i,j,k) = DXX(i,j,k) - epsilon_trace_over_3
                            epsilondev_yy_loc(i,j,k) = DYY(i,j,k) - epsilon_trace_over_3
                            epsilondev_xy_loc(i,j,k) = 0.5 * (DXY(i,j,k) + DYX(i,j,k))
                            epsilondev_xz_loc(i,j,k) = 0.5 * (DZX(i,j,k) + DXZ(i,j,k))
                            epsilondev_yz_loc(i,j,k) = 0.5 * (DZY(i,j,k) + DYZ(i,j,k))
                        enddo
                    enddo
                enddo
            endif

            if (aniso) then
                if (n_solid>0) then
                    call calcul_forces_aniso_att(Fox,Foy,Foz, &
                        Elem%Invgrad, &
                        htprimex, htprimey, htprimez, &
                        Elem%Jacob, mat%GLLwx, mat%GLLwy, mat%GLLwz, &
                        DXX,DXY,DXZ, &
                        DYX,DYY,DYZ, &
                        DZX,DZY,DZZ, &
                        Elem%Mu, Elem%Lambda, Elem%sl%Cij, &
                        
                        m1,m2,m3, n_solid, &
                        Elem%sl%onemSbeta, Elem%sl%R_xx_, Elem%sl%R_yy_, &
                        Elem%sl%R_xy_, Elem%sl%R_xz_, Elem%sl%R_yz_)
                    call attenuation_aniso_update(Elem%sl%epsilondev_xx_,Elem%sl%epsilondev_yy_, &
                        Elem%sl%epsilondev_xy_,Elem%sl%epsilondev_xz_,Elem%sl%epsilondev_yz_, &
                        epsilondev_xx_loc,epsilondev_yy_loc, &
                        epsilondev_xy_loc,epsilondev_xz_loc,epsilondev_yz_loc, &
                        Elem%sl%R_xx_,Elem%sl%R_yy_,Elem%sl%R_xy_,Elem%sl%R_xz_,Elem%sl%R_yz_, &
                        Elem%sl%factor_common_3,Elem%sl%alphaval_3,Elem%sl%betaval_3,Elem%sl%gammaval_3, &
                        Elem%Mu, m1,m2,m3, n_solid)
                    deallocate(epsilondev_xx_loc,epsilondev_yy_loc,epsilondev_xy_loc,epsilondev_xz_loc,epsilondev_yz_loc)
                    !      deallocate(epsilonvol_loc)
                else
                    call calcul_forces_aniso(Fox,Foy,Foz,  &
                        Elem%Invgrad, &
                        htprimex, htprimey, htprimez, &
                        Elem%Jacob, mat%GLLwx, mat%GLLwy, mat%GLLwz, &
                        DXX,DXY,DXZ, &
                        DYX,DYY,DYZ, &
                        DZX,DZY,DZZ, &
                        Elem%sl%Cij, &
                        m1,m2,m3)
                endif
            else
                if (n_solid>0) then
                    call calcul_forces_att(Fox,Foy,Foz, &
                        Elem%Invgrad, &
                        htprimex, htprimey, htprimez, &
                        Elem%Jacob, mat%GLLwx, mat%GLLwy, mat%GLLwz, &
                        DXX,DXY,DXZ, &
                        DYX,DYY,DYZ, &
                        DZX,DZY,DZZ, &
                        Elem%Mu, Elem%Kappa, &
                        m1,m2,m3, n_solid, &
                        Elem%sl%R_xx_, Elem%sl%R_yy_, &
                        Elem%sl%R_xy_, Elem%sl%R_xz_, Elem%sl%R_yz_, &
                        Elem%sl%R_vol_, &
                        Elem%sl%onemSbeta, &
                        Elem%sl%onemPbeta &
                        )
                    !                             Elem%Mu, Elem%Lambda, &
                    !                             m1,m2,m3, n_solid, &
                    !                             Elem%onemSbeta, Elem%R_xx_, Elem%R_yy_, &
                    !                             Elem%R_xy_, Elem%R_xz_, Elem%R_yz_)
                    call attenuation_update(Elem%sl%epsilondev_xx_,Elem%sl%epsilondev_yy_, &
                        Elem%sl%epsilondev_xy_,Elem%sl%epsilondev_xz_,Elem%sl%epsilondev_yz_, &
                        epsilondev_xx_loc,epsilondev_yy_loc, &
                        epsilondev_xy_loc,epsilondev_xz_loc,epsilondev_yz_loc, &
                        Elem%sl%R_xx_,Elem%sl%R_yy_,Elem%sl%R_xy_,Elem%sl%R_xz_,Elem%sl%R_yz_, &
                        Elem%sl%factor_common_3,Elem%sl%alphaval_3,Elem%sl%betaval_3,Elem%sl%gammaval_3, &
                        Elem%Mu, m1,m2,m3, n_solid, &
                        Elem%Kappa, Elem%sl%epsilonvol_,epsilonvol_loc,Elem%sl%R_vol_, &
                        Elem%sl%factor_common_P,Elem%sl%alphaval_P,Elem%sl%betaval_P,Elem%sl%gammaval_P)
                    !                              kappa_,elsilonvol_,epsilon_vol_loc,R_vol_, &
                    !                              factor_common_P_,alphaval_P_,betaval_P_,gammaval_P_)
                    deallocate(epsilondev_xx_loc,epsilondev_yy_loc,epsilondev_xy_loc,epsilondev_xz_loc,epsilondev_yz_loc)
                    deallocate(epsilonvol_loc)
                else


                    if (nl_flag == 1) then

                        call calcul_forces_nl(Fox,Foy,Foz,  &
                            Elem%Invgrad, &
                            htprimex, htprimey, htprimez, &
                            Elem%Jacob, mat%GLLwx, mat%GLLwy, mat%GLLwz, &
                            DXX, DXY, DXZ, DYX, DYY, DYZ, DZX, DZY, DZZ, &
                            Elem%Mu, Elem%Lambda, m1, m2 ,m3, &
                            EpsPl_ij_N_el, Sigma_ij_N_el, &
                            Xkin_ij_N_el, Riso_N_el, &
                            Elem%sl%nl_param_el%lmc_param_el%sigma_yld, &
                            Elem%sl%nl_param_el%lmc_param_el%b_iso,    &
                            Elem%sl%nl_param_el%lmc_param_el%Rinf_iso, &
                            Elem%sl%nl_param_el%lmc_param_el%C_kin,    &
                            Elem%sl%nl_param_el%lmc_param_el%kapa_kin)

                    else
                        call calcul_forces_el(Fox,Foy,Foz,  &
                            Elem%Invgrad, &
                            htprimex, htprimey, htprimez, &
                            Elem%Jacob, mat%GLLwx, mat%GLLwy, mat%GLLwz, &
                            DXX,DXY,DXZ, &
                            DYX,DYY,DYZ, &
                            DZX,DZY,DZZ, &
                            Elem%Mu, Elem%Lambda, &
                            m1,m2,m3)
                    end if
                endif
            endif

            do k = 0,m3-1
                do j = 0,m2-1
                    do i = 0,m1-1
                        champs1%Forces(Elem%Isol(i,j,k),0) = champs1%Forces(Elem%Isol(i,j,k),0)-Fox(i,j,k)
                        champs1%Forces(Elem%Isol(i,j,k),1) = champs1%Forces(Elem%Isol(i,j,k),1)-Foy(i,j,k)
                        champs1%Forces(Elem%Isol(i,j,k),2) = champs1%Forces(Elem%Isol(i,j,k),2)-Foz(i,j,k)
                        if (nl_flag == 1) then
                            do i_dir = 0,5
                                champs1%Epsilon_pl(Elem%Isol(i,j,k),i_dir) = EpsPl_ij_N_el(i_dir,i,j,k)
                                champs1%Stress(Elem%Isol(i,j,k),i_dir)     = Sigma_ij_N_el(i_dir,i,j,k)
                                champs1%Xkin(Elem%Isol(i,j,k),i_dir)       = Xkin_ij_N_el(i_dir,i,j,k)
                            end do
                            champs1%Riso(Elem%Isol(i,j,k)) = Riso_N_el(i,j,k)
                        end if
                    enddo
                enddo
            enddo
            if(allocated(EpsPl_ij_N_el)) deallocate(EpsPl_ij_N_el)
            if(allocated(Sigma_ij_N_el)) deallocate(Sigma_ij_N_el)
            if(allocated(Xkin_ij_N_el))  deallocate(Xkin_ij_N_el)
            if(allocated(Riso_N_el))     deallocate(Riso_N_el)
            if(allocated(PlastMult_N_el))deallocate(PlastMult_N_el)
        !---------------------------------
        else      ! FLUID PART OF THE DOMAIN
            ! d(rho*Phi)_dX
            ! d(rho*Phi)_dY
            ! d(rho*Phi)_dZ
            allocate(Phi(0:m1-1,0:m2-1,0:m3-1))
            do k = 0,m3-1
                do j = 0,m2-1
                    do i = 0,m1-1
                        Phi(i,j,k) = champs1%Phi(Elem%Iflu(i,j,k))
                    enddo
                enddo
            enddo
            call physical_part_deriv(m1,m2,m3,htprimex,hprimey,hprimez,Elem%InvGrad, Phi, &
                dPhiX, dPhiY, dPhiZ)
            deallocate(Phi)

            ! internal forces
            call calcul_forces_fluid(Fo_Fl,                &
                Elem%Invgrad, &
                htprimex,htprimey,htprimez, &
                Elem%Jacob,mat%GLLwx,mat%GLLwy,mat%GLLwz, &
                dPhiX,dPhiY,dPhiZ,       &
                Elem%Density,            &
                m1,m2,m3)

            do k = 0,m3-1
                do j = 0,m2-1
                    do i = 0,m1-1
                        champs1%ForcesFl(Elem%Iflu(i,j,k)) = champs1%ForcesFl(Elem%Iflu(i,j,k))-Fo_Fl(i,j,k)
                    enddo
                enddo
            enddo

        end if

        return
    end subroutine forces_int

    subroutine forces_int_flu_pml(Elem, mat, champs1)
        type (Element), intent (INOUT) :: Elem
        type (subdomain), intent(IN) :: mat
        type(champs), intent(inout) :: champs1
        !
        integer :: m1, m2, m3
        integer :: i, j, k, l, ind
        real :: sum_vx, sum_vy, sum_vz, acoeff
        real, dimension(0:2,0:Elem%ngllx-1,0:Elem%nglly-1,0:Elem%ngllz-1)  :: ForcesFl

        m1 = Elem%ngllx ; m2 = Elem%nglly ; m3 = Elem%ngllz

        do k = 0,m3-1
            do j = 0,m2-1
                do i=0,m1-1
                    ind = Elem%flpml%IFluPml(i,j,k)
                    sum_vx = 0d0
                    sum_vy = 0d0
                    sum_vz = 0d0
                    do l = 0,m1-1
                        acoeff = - mat%hprimex(i,l)*mat%GLLwx(l)*mat%GLLwy(j)*mat%GLLwz(k)*Elem%Jacob(l,j,k)
                        sum_vx = sum_vx + acoeff*Elem%InvGrad(0,0,l,j,k)*Elem%flpml%Veloc(l,j,k,0)
                        sum_vy = sum_vy + acoeff*Elem%InvGrad(1,0,l,j,k)*Elem%flpml%Veloc(l,j,k,1)
                        sum_vz = sum_vz + acoeff*Elem%InvGrad(2,0,l,j,k)*Elem%flpml%Veloc(l,j,k,2)
                    end do
                    ForcesFl(0,i,j,k) = sum_vx
                    ForcesFl(1,i,j,k) = sum_vy
                    ForcesFl(2,i,j,k) = sum_vz
                end do
            end do
        end do
        do k = 0,m3-1
            do l = 0,m2-1
                do j = 0,m2-1
                    do i=0,m1-1
                        ind = Elem%flpml%IFluPml(i,j,k)
                        acoeff = - mat%hprimey(j,l)*mat%GLLwx(i)*mat%GLLwy(l)*mat%GLLwz(k)*Elem%Jacob(i,l,k)
                        sum_vx = acoeff*Elem%InvGrad(0,1,i,l,k)*Elem%flpml%Veloc(i,l,k,0)
                        sum_vy = acoeff*Elem%InvGrad(1,1,i,l,k)*Elem%flpml%Veloc(i,l,k,1)
                        sum_vz = acoeff*Elem%InvGrad(2,1,i,l,k)*Elem%flpml%Veloc(i,l,k,2)
                        ForcesFl(0,i,j,k) = ForcesFl(0,i,j,k) + sum_vx
                        ForcesFl(1,i,j,k) = ForcesFl(1,i,j,k) + sum_vy
                        ForcesFl(2,i,j,k) = ForcesFl(2,i,j,k) + sum_vz
                    end do
                end do
            end do
        end do
        ! TODO reorder loops ?
        do l = 0,m3-1
            do k = 0,m3-1
                do j = 0,m2-1
                    do i=0,m1-1
                        ind = Elem%flpml%IFluPml(i,j,k)
                        acoeff = - mat%hprimez(k,l)*mat%GLLwx(i)*mat%GLLwy(j)*mat%GLLwz(l)*Elem%Jacob(i,j,l)
                        sum_vx = acoeff*Elem%InvGrad(0,2,i,j,l)*Elem%flpml%Veloc(i,j,l,0)
                        sum_vy = acoeff*Elem%InvGrad(1,2,i,j,l)*Elem%flpml%Veloc(i,j,l,1)
                        sum_vz = acoeff*Elem%InvGrad(2,2,i,j,l)*Elem%flpml%Veloc(i,j,l,2)
                        ForcesFl(0,i,j,k) = ForcesFl(0,i,j,k) + sum_vx
                        ForcesFl(1,i,j,k) = ForcesFl(1,i,j,k) + sum_vy
                        ForcesFl(2,i,j,k) = ForcesFl(2,i,j,k) + sum_vz
                    end do
                end do
            end do
        end do
        
        ! Assemblage
        do k = 0,m3-1
            do j = 0,m2-1
                do i = 0,m1-1
                    ind = Elem%flpml%IFluPml(i,j,k)
                    ! We should have atomic adds with openmp // here
                    champs1%fpml_Forces(ind+0) = champs1%fpml_Forces(ind+0) + ForcesFl(0,i,j,k)
                    champs1%fpml_Forces(ind+1) = champs1%fpml_Forces(ind+1) + ForcesFl(1,i,j,k)
                    champs1%fpml_Forces(ind+2) = champs1%fpml_Forces(ind+2) + ForcesFl(2,i,j,k)
                enddo
            enddo
        enddo

        return
    end subroutine forces_int_flu_pml


    subroutine pred_flu_pml(Elem, mat, dt, champs1)
        implicit none

        type(Element), intent(inout) :: Elem
        type (subdomain), intent(IN) :: mat
        type(champs), intent(inout) :: champs1
        real, intent(in) :: dt
        !
        real, dimension(0:Elem%ngllx-1, 0:Elem%nglly-1, 0:Elem%ngllz-1) :: dVelPhi_dx, dVelPhi_dy, dVelPhi_dz
        integer :: m1, m2, m3
        integer :: i, j, k, ind
        real, dimension(:,:,:), allocatable :: VelPhi

        m1 = Elem%ngllx ; m2 = Elem%nglly ; m3 = Elem%ngllz

        allocate(VelPhi(0:m1-1,0:m2-1,0:m3-1))
        ! prediction in the element
        ! We do the sum V1+V2+V3 and F1+F2+F3 here
        do k = 0,m3-1
            do j = 0,m2-1
                do i = 0,m1-1
                    ind = Elem%flpml%IFluPml(i,j,k)
                    VelPhi(i,j,k) = champs1%fpml_VelPhi(ind)+ &
                        champs1%fpml_VelPhi(ind+1)+champs1%fpml_VelPhi(ind+2)
                enddo
            enddo
        enddo
        ! XXX DumpS{xyz}(:,:,:,1) doit etre multiplie par 1/density
        ! d(rho*Phi)_d(xi,eta,zeta)
        call physical_part_deriv(m1,m2,m3,mat%htprimex,mat%hprimey,mat%hprimez,Elem%InvGrad, &
            VelPhi(:,:,:), dVelPhi_dx, dVelPhi_dy, dVelPhi_dz)

        ! prediction for (physical) velocity (which is the equivalent of a stress, here)
        ! V_x^x
        Elem%flpml%Veloc(:,:,:,0) = Elem%xpml%DumpSx(:,:,:,0) * Elem%flpml%Veloc(:,:,:,0) + &
            Elem%xpml%DumpSx(:,:,:,1) * Dt * dVelPhi_dx
        ! V_x^y = 0
        ! V_x^z = 0
        ! V_y^x = 0
        ! V_y^y
        Elem%flpml%Veloc(:,:,:,1) = Elem%xpml%DumpSy(:,:,:,0) * Elem%flpml%Veloc(:,:,:,1) + &
            Elem%xpml%DumpSy(:,:,:,1) * Dt * dVelPhi_dy
        ! V_y^z = 0
        ! V_z^x = 0
        ! V_z^y = 0
        ! V_z^z
        Elem%flpml%Veloc(:,:,:,2) = Elem%xpml%DumpSz(:,:,:,0) * Elem%flpml%Veloc(:,:,:,2) + &
            Elem%xpml%DumpSz(:,:,:,1) * Dt * dVelPhi_dz
        return
    end subroutine Pred_Flu_Pml

    subroutine pred_sol_pml(Elem, mat, dt, champs1)
        implicit none

        type(Element), intent(inout) :: Elem
        type (subdomain), intent(IN) :: mat
        type(champs), intent(inout) :: champs1
        real, intent(in) :: dt
        !
        real, dimension(0:Elem%ngllx-1, 0:Elem%nglly-1, 0:Elem%ngllz-1) :: dVx_dx, dVx_dy, dVx_dz
        real, dimension(0:Elem%ngllx-1, 0:Elem%nglly-1, 0:Elem%ngllz-1) :: dVy_dx, dVy_dy, dVy_dz
        real, dimension(0:Elem%ngllx-1, 0:Elem%nglly-1, 0:Elem%ngllz-1) :: dVz_dx, dVz_dy, dVz_dz
        integer :: m1, m2, m3
        integer :: i, j, k, ind, i_dir
        real, dimension (:,:,:,:), allocatable :: Veloc

        m1 = Elem%ngllx ; m2 = Elem%nglly ; m3 = Elem%ngllz

        allocate(Veloc(0:m1-1,0:m2-1,0:m3-1,0:2))
        do i_dir = 0,2
            do k = 0,m3-1
                do j = 0,m2-1
                    do i = 0,m1-1
                        ind = Elem%slpml%ISolPml(i,j,k)
                        Veloc(i,j,k,i_dir) = champs1%VelocPML(ind,i_dir)+champs1%VelocPML(ind+1,i_dir)+champs1%VelocPML(ind+2,i_dir)
                    enddo
                enddo
            enddo
        enddo

        ! partial of velocity components with respect to xi,eta,zeta
        call physical_part_deriv(m1,m2,m3,mat%htprimex,mat%hprimey,mat%hprimez,Elem%InvGrad, Veloc(:,:,:,0),dVx_dx,dVx_dy,dVx_dz)
        call physical_part_deriv(m1,m2,m3,mat%htprimex,mat%hprimey,mat%hprimez,Elem%InvGrad, Veloc(:,:,:,1),dVy_dx,dVy_dy,dVy_dz)
        call physical_part_deriv(m1,m2,m3,mat%htprimex,mat%hprimey,mat%hprimez,Elem%InvGrad, Veloc(:,:,:,2),dVz_dx,dVz_dy,dVz_dz)

        deallocate(Veloc)

        ! Stress_xx
        Elem%slpml%Diagonal_Stress1(:,:,:,0) = Elem%xpml%DumpSx(:,:,:,0)*Elem%slpml%Diagonal_Stress1(:,:,:,0) + Elem%xpml%DumpSx(:,:,:,1)*Dt*(Elem%Lambda+2*Elem%Mu)*dVx_dx
        Elem%slpml%Diagonal_Stress2(:,:,:,0) = Elem%xpml%DumpSy(:,:,:,0)*Elem%slpml%Diagonal_Stress2(:,:,:,0) + Elem%xpml%DumpSy(:,:,:,1)*Dt*(Elem%Lambda)*dVy_dy
        Elem%slpml%Diagonal_Stress3(:,:,:,0) = Elem%xpml%DumpSz(:,:,:,0)*Elem%slpml%Diagonal_Stress3(:,:,:,0) + Elem%xpml%DumpSz(:,:,:,1)*Dt*(Elem%Lambda)*dVz_dz

        ! Stress_yy
        Elem%slpml%Diagonal_Stress1(:,:,:,1) = Elem%xpml%DumpSx(:,:,:,0)*Elem%slpml%Diagonal_Stress1(:,:,:,1) + Elem%xpml%DumpSx(:,:,:,1)*Dt*(Elem%Lambda)*dVx_dx
        Elem%slpml%Diagonal_Stress2(:,:,:,1) = Elem%xpml%DumpSy(:,:,:,0)*Elem%slpml%Diagonal_Stress2(:,:,:,1) + Elem%xpml%DumpSy(:,:,:,1)*Dt*(Elem%Lambda+2*Elem%Mu)*dVy_dy
        Elem%slpml%Diagonal_Stress3(:,:,:,1) = Elem%xpml%DumpSz(:,:,:,0)*Elem%slpml%Diagonal_Stress3(:,:,:,1) + Elem%xpml%DumpSz(:,:,:,1)*Dt*(Elem%Lambda)*dVz_dz

        ! Stress_zz
        Elem%slpml%Diagonal_Stress1(:,:,:,2) = Elem%xpml%DumpSx(:,:,:,0)*Elem%slpml%Diagonal_Stress1(:,:,:,2) + Elem%xpml%DumpSx(:,:,:,1)*Dt*(Elem%Lambda)*dVx_dx
        Elem%slpml%Diagonal_Stress2(:,:,:,2) = Elem%xpml%DumpSy(:,:,:,0)*Elem%slpml%Diagonal_Stress2(:,:,:,2) + Elem%xpml%DumpSy(:,:,:,1)*Dt*(Elem%Lambda)*dVy_dy
        Elem%slpml%Diagonal_Stress3(:,:,:,2) = Elem%xpml%DumpSz(:,:,:,0)*Elem%slpml%Diagonal_Stress3(:,:,:,2) + Elem%xpml%DumpSz(:,:,:,1)*Dt*(Elem%Lambda+2*Elem%Mu)*dVz_dz
        Elem%slpml%Diagonal_Stress = Elem%slpml%Diagonal_Stress1 + Elem%slpml%Diagonal_Stress2 + Elem%slpml%Diagonal_Stress3

        ! Stress_xy
        Elem%slpml%Residual_Stress1 (:,:,:,0) = Elem%xpml%DumpSx(:,:,:,0)*Elem%slpml%Residual_Stress1 (:,:,:,0) + Elem%xpml%DumpSx(:,:,:,1)*Dt*(Elem%Mu)*dVy_dx
        Elem%slpml%Residual_Stress2 (:,:,:,0) = Elem%xpml%DumpSy(:,:,:,0)*Elem%slpml%Residual_Stress2 (:,:,:,0) + Elem%xpml%DumpSy(:,:,:,1)*Dt*(Elem%Mu)*dVx_dy
        Elem%slpml%Residual_Stress3 (:,:,:,0) = Elem%xpml%DumpSz(:,:,:,0)*Elem%slpml%Residual_Stress3 (:,:,:,0)

        ! Stress_xz
        Elem%slpml%Residual_Stress1 (:,:,:,1) = Elem%xpml%DumpSx(:,:,:,0)*Elem%slpml%Residual_Stress1 (:,:,:,1) + Elem%xpml%DumpSx(:,:,:,1)*Dt*(Elem%Mu)*dVz_dx
        Elem%slpml%Residual_Stress2 (:,:,:,1) = Elem%xpml%DumpSy(:,:,:,0)*Elem%slpml%Residual_Stress2 (:,:,:,1)
        Elem%slpml%Residual_Stress3 (:,:,:,1) = Elem%xpml%DumpSz(:,:,:,0)*Elem%slpml%Residual_Stress3 (:,:,:,1) + Elem%xpml%DumpSz(:,:,:,1)*Dt*(Elem%Mu)*dVx_dz

        ! Stress_yz
        Elem%slpml%Residual_Stress1 (:,:,:,2) = Elem%xpml%DumpSx(:,:,:,0)*Elem%slpml%Residual_Stress1 (:,:,:,2)
        Elem%slpml%Residual_Stress2 (:,:,:,2) = Elem%xpml%DumpSy(:,:,:,0)*Elem%slpml%Residual_Stress2 (:,:,:,2) + Elem%xpml%DumpSy(:,:,:,1)*Dt*(Elem%Mu)*dVz_dy
        Elem%slpml%Residual_Stress3 (:,:,:,2) = Elem%xpml%DumpSz(:,:,:,0)*Elem%slpml%Residual_Stress3 (:,:,:,2) + Elem%xpml%DumpSz(:,:,:,1)*Dt*(Elem%Mu)*dVy_dz

        Elem%slpml%Residual_Stress = Elem%slpml%Residual_Stress1 + Elem%slpml%Residual_Stress2 + Elem%slpml%Residual_Stress3

    end subroutine pred_sol_pml

    subroutine forces_int_sol_pml(Elem, mat, champs1)
        type (Element), intent (INOUT) :: Elem
        type (subdomain), intent(IN) :: mat
        type(champs), intent(inout) :: champs1
        !
        integer :: m1, m2, m3
        integer :: i, j, k, l, ind
        real :: sum_vx, sum_vy, sum_vz, acoeff
        real, dimension(0:2,0:Elem%ngllx-1,0:Elem%nglly-1,0:Elem%ngllz-1)  :: Forces1, Forces2, Forces3

        m1 = Elem%ngllx ; m2 = Elem%nglly ; m3 = Elem%ngllz


        do k = 0,m3-1
            do j = 0,m2-1
                do i=0,m1-1
                    sum_vx = 0d0
                    sum_vy = 0d0
                    sum_vz = 0d0
                    do l = 0,m1-1
                        acoeff = - mat%hprimex(i,l)*mat%GLLwx(l)*mat%GLLwy(j)*mat%GLLwz(k)*Elem%Jacob(l,j,k)
                        sum_vx = sum_vx + acoeff*Elem%InvGrad(0,0,l,j,k)*Elem%slpml%Diagonal_Stress(l,j,k,0)
                        sum_vx = sum_vx + acoeff*Elem%InvGrad(1,0,l,j,k)*Elem%slpml%Residual_Stress(l,j,k,0)
                        sum_vx = sum_vx + acoeff*Elem%InvGrad(2,0,l,j,k)*Elem%slpml%Residual_Stress(l,j,k,1)

                        sum_vy = sum_vy + acoeff*Elem%InvGrad(0,0,l,j,k)*Elem%slpml%Residual_Stress(l,j,k,0)
                        sum_vy = sum_vy + acoeff*Elem%InvGrad(1,0,l,j,k)*Elem%slpml%Diagonal_Stress(l,j,k,1)
                        sum_vy = sum_vy + acoeff*Elem%InvGrad(2,0,l,j,k)*Elem%slpml%Residual_Stress(l,j,k,2)

                        sum_vz = sum_vz + acoeff*Elem%InvGrad(0,0,l,j,k)*Elem%slpml%Residual_Stress(l,j,k,1)
                        sum_vz = sum_vz + acoeff*Elem%InvGrad(1,0,l,j,k)*Elem%slpml%Residual_Stress(l,j,k,2)
                        sum_vz = sum_vz + acoeff*Elem%InvGrad(2,0,l,j,k)*Elem%slpml%Diagonal_Stress(l,j,k,2)
                    end do
                    Forces1(0,i,j,k) = sum_vx
                    Forces1(1,i,j,k) = sum_vy
                    Forces1(2,i,j,k) = sum_vz
                end do
            end do
        end do

        do k = 0,m3-1
            Forces2(:,:,:,k) = 0d0
            do l = 0,m2-1
                do j = 0,m2-1
                    do i=0,m1-1
                        acoeff = - mat%hprimey(j,l)*mat%GLLwx(i)*mat%GLLwy(l)*mat%GLLwz(k)*Elem%Jacob(i,l,k)
                        sum_vx = acoeff*(Elem%InvGrad(0,1,i,l,k)*Elem%slpml%Diagonal_Stress(i,l,k,0) + &
                            Elem%InvGrad(1,1,i,l,k)*Elem%slpml%Residual_Stress(i,l,k,0) + &
                            Elem%InvGrad(2,1,i,l,k)*Elem%slpml%Residual_Stress(i,l,k,1))

                        sum_vy = acoeff*(Elem%InvGrad(0,1,i,l,k)*Elem%slpml%Residual_Stress(i,l,k,0) + &
                            Elem%InvGrad(1,1,i,l,k)*Elem%slpml%Diagonal_Stress(i,l,k,1) + &
                            Elem%InvGrad(2,1,i,l,k)*Elem%slpml%Residual_Stress(i,l,k,2))

                        sum_vz = acoeff*(Elem%InvGrad(0,1,i,l,k)*Elem%slpml%Residual_Stress(i,l,k,1) + &
                            Elem%InvGrad(1,1,i,l,k)*Elem%slpml%Residual_Stress(i,l,k,2) + &
                            Elem%InvGrad(2,1,i,l,k)*Elem%slpml%Diagonal_Stress(i,l,k,2))
                        Forces2(0,i,j,k) = Forces2(0,i,j,k) + sum_vx
                        Forces2(1,i,j,k) = Forces2(1,i,j,k) + sum_vy
                        Forces2(2,i,j,k) = Forces2(2,i,j,k) + sum_vz
                    end do
                end do
            end do
        end do
        ! TODO reorder loops ?
        Forces3 = 0
        do l = 0,m3-1
            do k = 0,m3-1
                do j = 0,m2-1
                    do i=0,m1-1
                        acoeff = - mat%hprimez(k,l)*mat%GLLwx(i)*mat%GLLwy(j)*mat%GLLwz(l)*Elem%Jacob(i,j,l)
                        sum_vx = acoeff*(Elem%InvGrad(0,2,i,j,l)*Elem%slpml%Diagonal_Stress(i,j,l,0) + &
                            Elem%InvGrad(1,2,i,j,l)*Elem%slpml%Residual_Stress(i,j,l,0) + &
                            Elem%InvGrad(2,2,i,j,l)*Elem%slpml%Residual_Stress(i,j,l,1))

                        sum_vy = acoeff*(Elem%InvGrad(0,2,i,j,l)*Elem%slpml%Residual_Stress(i,j,l,0) + &
                            Elem%InvGrad(1,2,i,j,l)*Elem%slpml%Diagonal_Stress(i,j,l,1) + &
                            Elem%InvGrad(2,2,i,j,l)*Elem%slpml%Residual_Stress(i,j,l,2))

                        sum_vz = acoeff*(Elem%InvGrad(0,2,i,j,l)*Elem%slpml%Residual_Stress(i,j,l,1) + &
                            Elem%InvGrad(1,2,i,j,l)*Elem%slpml%Residual_Stress(i,j,l,2) + &
                            Elem%InvGrad(2,2,i,j,l)*Elem%slpml%Diagonal_Stress(i,j,l,2))
                        Forces3(0,i,j,k) = Forces3(0,i,j,k) + sum_vx
                        Forces3(1,i,j,k) = Forces3(1,i,j,k) + sum_vy
                        Forces3(2,i,j,k) = Forces3(2,i,j,k) + sum_vz
                    end do
                end do
            end do
        end do


        ! Assemblage
        do k = 0,m3-1
            do j = 0,m2-1
                do i = 0,m1-1
                    ind = Elem%slpml%ISolPml(i,j,k)
                    champs1%ForcesPML(ind+0,:) = champs1%ForcesPML(ind+0,:) + Forces1(:,i,j,k)
                    champs1%ForcesPML(ind+1,:) = champs1%ForcesPML(ind+1,:) + Forces2(:,i,j,k)
                    champs1%ForcesPML(ind+2,:) = champs1%ForcesPML(ind+2,:) + Forces3(:,i,j,k)
                enddo
            enddo
        enddo
    end subroutine forces_int_sol_pml

end module forces_aniso

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
