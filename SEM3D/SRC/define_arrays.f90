!>
!! \file define_arrays.f90
!! \brief Contient la routine Define_Arrays()
!! \author
!! \version 1.0
!! \date
!!
!<

subroutine Define_Arrays(Tdomain, rg)

    use sdomain
    use mpi
    use scomm
    use scommutils
    use assembly
    use constants
    use read_model_earthchunk
    use randomFieldND
    use writeResultFile_RF
    use displayCarvalhol
    use define_random
    implicit none

    interface
       subroutine define_FPML_DumpEnd(dir,ngllx,nglly,ngllz,Massmat,DumpMass,DumpV,Iv)
           implicit none
           integer, intent(in)   :: dir,ngllx,nglly,ngllz
           real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(in) :: MassMat
           real, dimension(1:ngllx-2,1:nglly-2,1:ngllz-2,0:1), intent(out) :: DumpV
           real, dimension(1:ngllx-2,1:nglly-2,1:ngllz-2,0:1),intent(in) :: DumpMass
           real, dimension(:,:,:), allocatable, intent(inout) :: Iv
       end subroutine define_FPML_DumpEnd
    end interface

    !INPUT & OUTPUT
    type (domain), intent (INOUT), target :: Tdomain
    integer      , intent(IN) :: rg

    !LOCAL VARIABLES
    integer, parameter :: etiquette = 100
    real,    external  :: pow
    integer :: n, m, mat, ngllx,nglly,ngllz, ngll1,ngll2, ngll, i,j,k, nf,ne,nv
    integer :: ngll_tot, ngllPML_tot, ngllNeu
    integer :: which_face
    integer :: imx,imy,imz,iflag,nnf,dir
    integer :: ipoint, icolonne,jlayer
    real    :: xp,yp,zp,xfact
    real    :: zg1,zd1,zg2,zd2,zz1,zz2,zfact
    real    :: xd1,xg1
    real    :: zrho,zrho1,zrho2,zCp,zCp1,zCp2,zCs,zCs1,zCs2
    real    :: Mu,Kappa,Lambda
    character(len=15) :: procFileName = "PropGlob"
    character(len=50) :: h5folder  = "./prop/h5", &
    					 XMFfolder = "./prop", &
    					 h5_to_xmf = "./h5"
    real, dimension(:,:,:), allocatable :: xix  ,xiy  ,xiz,         &
    									   etax ,etay ,etaz,        &
        								   zetax,zetay,zetaz,       &
        								   wx   ,wy   ,wz,          &
        								   Jac,temp_PMLx,temp_PMLy, &
    									   Rlam,Rmu,RKmod, Whei, LocMassMat

    !START Modif Random Field
    integer :: code, error, coord, nProp
    integer :: RFpoint, assocMat, imn, key, rgSubD
    double precision, dimension(:, :), allocatable :: xPoints;
    integer         , dimension(:)   , allocatable :: nSubDPoints;
    real            , dimension(:)   , allocatable :: avgProp;
    double precision, dimension(:, :), allocatable :: prop !Properties
    character(len=110) , dimension(:), allocatable :: HDF5NameList
    integer                                        :: randMethod = 1 !1 for Victor's method, 2 for Shinozuka's

	!END Modif Random Field

!!! Attribute elastic properties from material !!!

    if( Tdomain%earthchunk_isInit/=0) then
        call load_model(Tdomain%earthchunk_file, Tdomain%earthchunk_delta_lon, Tdomain%earthchunk_delta_lat)
    endif

	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	!General initialization!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	if(rg == 0) write(*,*) ">>>>Defining arrays"
	nProp        =  3
	allocate(avgProp(0:nProp-1)) !Obs: should have nProp declared before
	allocate(nSubDPoints(0:Tdomain%n_mat - 1))
	allocate(HDF5NameList(0:Tdomain%n_mat-1))
	HDF5NameList(:) = "not_Used"

	!Building subdomain masks and counting number of points per subdomain
	do mat = 0, Tdomain%n_mat - 1
		allocate(Tdomain%sSubDomain(mat)%globCoordMask(0:size(Tdomain%GlobCoord,1)-1,  &
	        	 									   0:size(Tdomain%GlobCoord,2)-1))
		call build_coord_mask(Tdomain, mat)
	    nSubDPoints(mat) = count(Tdomain%sSubDomain(mat)%globCoordMask(0,:)) !Identifier of number of points to the XMF file
	end do

	!call dispCarvalhol(Tdomain%sSubDomain(0)%globCoordMask(:,:), "Tdomain%sSubDomain(0)%globCoordMask(:,:)")

	if(Tdomain%any_Random) call define_random_subdomains(Tdomain, rg)

!	!START TESTING BLOCK
!	write(*,*) "////////////RANG ", rg, "-----------------------"
!	write(*,*) "Tdomain%not_PML_List = ", Tdomain%not_PML_List
!	write(*,*) "Tdomain%subD_exist   = ", Tdomain%subD_exist
!	write(*,*) "nSubDPoints(:)       = ", nSubDPoints(:)
!	!call dispCarvalhol(transpose(Tdomain%GlobCoord(:,:)), "transpose(Tdomain%GlobCoord) = ")
!	write(*,*) ""
!	do mat = 0, Tdomain%n_mat - 1
!		write(*,*) "MATERIAL ", mat, " RANG ", rg
!		!write(*,*)"...%globCoordMask(0,:) = ", Tdomain%sSubDomain(mat)%globCoordMask(0,:)
!		write(*,*) "number of points = ",nSubDPoints(mat)
!		write(*,*) "..%material_type = ", Tdomain%sSubdomain(mat)%material_type
!		write(*,*) "assocMat         =", assocMat
!		write(*,*) "(assocMat)%material_type = ", Tdomain%sSubdomain(assocMat)%material_type
!		write(*,*) "..%chosenSeed(:) = ", Tdomain%sSubdomain(mat)%chosenSeed(:)
!		write(*,*) "..%MinBound(:)   = ", Tdomain%sSubdomain(mat)%MinBound(:)
!		write(*,*) "..%MaxBound(:)   = ", Tdomain%sSubdomain(mat)%MaxBound(:)
!	    !call dispCarvalhol(transpose(Tdomain%sSubDomain(0)%globCoordMask(:,:)), &
!	    !				  "transpose(Tdomain%sSubDomain(0)%globCoordMask(:,:)) = ")
!		write(*,*) ""
!	end do
!	!END TESTING BLOCK

	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	!Building and applying properties per subdomain!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	if(rg == 0) write(*,*) ">>>>Building and applying properties per subdomain"



	!write(*,*) ">>>>Building and applying properties per subdomain"
	do mat = 0, Tdomain%n_mat - 1
		if(rg == 0) write(*,*) ""
		if(rg == 0) write(*,*) "///////////MATERIAL ", mat, " in rang ", rg
		if(rg == 0) write(*,*) "                  Type: ", Tdomain%sSubdomain(mat)%material_type
		if(rg == 0) write(*,*) "Associated to material: ", Tdomain%sSubdomain(mat)%assocMat
		!if(rg == 0) write(*,*) "    Number of Elements: ", size(Tdomain%sSubDomain(mat)%elemList)
		!if(rg == 0) write(*,*) "  Present in this proc? ", Tdomain%subD_exist(mat)
		!if(rg == 0) write(*,*) ""

		if(.not.Tdomain%subD_exist(mat)) then
			!if(rg == 0) write(*,*) ">>>>This material is not present in this proc"
			allocate(xPoints (0:-1, 0:2))
			allocate(prop(0:nSubDPoints(mat)-1, 0:2))

	    else
			if(rg == 0) write(*,*) ">>>>Allocating Local Coordinates (xPoints) and properties (prop)"
	        allocate(xPoints (0:size(Tdomain%GlobCoord, 1)-1, 0:nSubDPoints(mat)-1)) !Subdomain coordinates ((:,0) = X, (:,1) = Y, (:,2) = Z) per proc
	        allocate(prop(0:nSubDPoints(mat)-1, 0:nProp-1)) !Subdomain properties Matrix ((:,0) = Dens, (:,1) = Lambda, (:,2) = Mu) per proc

	        xPoints = reshape(pack(Tdomain%GlobCoord(:,:), &
	        					   mask = Tdomain%sSubDomain(mat)%globCoordMask(:,:)), &
	            			  shape = [3, nSubDPoints(mat)])
	        avgProp = [Tdomain%sSubDomain(mat)%Ddensity, &
	            	   Tdomain%sSubDomain(mat)%DLambda,  &
	            	   Tdomain%sSubDomain(mat)%DMu]
	        assocMat = Tdomain%sSubdomain(mat)%assocMat
    		ngllx    = Tdomain%sSubDomain(mat)%NGLLx
    		nglly    = Tdomain%sSubDomain(mat)%NGLLy
    		ngllz    = Tdomain%sSubDomain(mat)%NGLLz
    		!prop     = -1 !For tests, should be deleted in the future

	!////////////////////
	!//////////////////// CASE R
	!////////////////////

	        if(Tdomain%sSubdomain(assocMat)%material_type == "R") then
	        	if(.not. Tdomain%logicD%run_restart) then
	        		call build_random_properties(Tdomain, rg, mat, xPoints, prop, randMethod) !1 for Victor's method, 2 for Shinozuka's
				else
					call read_random_properties(Tdomain, rg, mat, prop, &
					                            trim(procFileName), trim(h5folder), &
					                            ["_proc", "_subD"], [rg, mat])
				end if
	!////////////////////
	!//////////////////// CASE MATERIAL_EARTHCHUNK AND MATERIAL_GRADIENT (TO BE REMODELED)
	!////////////////////

	        else if (Tdomain%sSubDomain(mat)%material_definition == MATERIAL_EARTHCHUNK .or. &
	        		 Tdomain%sSubDomain(mat)%material_definition == MATERIAL_GRADIENT) then
				write(*,*) "WARNING material definition is 'MATERIAL_EARTHCHUNK' or 'MATERIAL_GRADIENT', not tested after random material integration"
				do m = 0, Tdomain%sSubDomain(mat)%nElem - 1
		    		n = Tdomain%sSubDomain(mat)%elemList(m)

		        !    integration de la prise en compte du gradient de proprietes
					select case(Tdomain%sSubDomain(mat)%material_definition)

			            case( MATERIAL_EARTHCHUNK )
			                call initialize_material_earthchunk(Tdomain%specel(n), Tdomain%sSubDomain(mat), Tdomain%GlobCoord, size(Tdomain%GlobCoord,2))

			            case( MATERIAL_GRADIENT )
			                !    on copie toujours le materiau de base
			                Tdomain%specel(n)%Density = Tdomain%sSubDomain(mat)%Ddensity
			                Tdomain%specel(n)%Lambda = Tdomain%sSubDomain(mat)%DLambda
			                Tdomain%specel(n)%Kappa = Tdomain%sSubDomain(mat)%DKappa
			                Tdomain%specel(n)%Mu = Tdomain%sSubDomain(mat)%DMu
			                !    si le flag gradient est actif alors on peut changer les proprietes

			                if ( Tdomain%logicD%grad_bassin ) then
			                    !    debut modification des proprietes des couches de materiaux
			                    !    bassin    voir programme Surface.f90

			                    !     n_layer nombre de couches
			                    !     n_colonne nombre de colonnes en x ici uniquement
			                    !     x_type == 0 on remet des materiaux  homogenes dans chaque bloc
			                    !     x_type == 1 on met des gradients pour chaque colonne en interpolant
			                    !     suivant z
			                    !       integer  :: n_colonne, n_layer, x_type
			                    !    x_coord correspond aux abscisses des colonnes
			                    !       real, pointer, dimension(:) :: x_coord
			                    !      z_layer profondeur de  linterface pour chaque x de colonne
			                    !      on definit egalement le materiaux par rho, Cp , Cs
			                    !       real, pointer, dimension(:,:) :: z_layer, z_rho, z_Cp, z_Cs


			                    !     on cherche tout d abord a localiser la maille a partir d un
			                    !     point de Gauss interne milieux (imx,imy,imz)
			                    imx = 1+(ngllx-1)/2
			                    imy = 1+(nglly-1)/2
			                    imz = 1+(ngllz-1)/2
			                    !     on impose qu une maille appartienne a un seul groupe de gradient de
			                    !     proprietes
			                    ipoint = Tdomain%specel(n)%Iglobnum(imx,imy,imz)
			                    xp = Tdomain%GlobCoord(0,ipoint)
			                    yp = Tdomain%GlobCoord(1,ipoint)
			                    zp = Tdomain%GlobCoord(2,ipoint)
			                    iflag = 0
			                    if ( Tdomain%sBassin%x_type .eq. 2 ) then
			                        if ( zp .gt. Tdomain%sBassin%zmax) then
			                            iflag = 1
			                        endif
			                        if ( zp .lt. Tdomain%sBassin%zmin) then
			                            iflag = 1
			                        endif
			                    endif
			                    !  si iflag nul on peut faire les modifications  pour toute la maille
			                    if ( iflag .eq. 0 ) then
			                        icolonne = 0
			                        xfact = 0.D0
			                        do i = 1, Tdomain%sBassin%n_colonne
			                            if ( xp .ge. Tdomain%sBassin%x_coord(i-1) .and.  xp .lt. Tdomain%sBassin%x_coord(i) ) then
			                                icolonne = i-1
			                                xfact = (xp - Tdomain%sBassin%x_coord(i-1))/(Tdomain%sBassin%x_coord(i)-Tdomain%sBassin%x_coord(i-1))
			                            endif
			                        enddo

			                        jlayer = 0
			                        zfact = 0.D0
			                        do j = 1,Tdomain%sBassin%n_layer
			                            zg1 = Tdomain%sBassin%z_layer(icolonne,j-1)
			                            zd1 = Tdomain%sBassin%z_layer(icolonne+1,j-1)
			                            zz1 = zg1 + xfact*(zd1-zg1)
			                            zg2 = Tdomain%sBassin%z_layer(icolonne,j)
			                            zd2 = Tdomain%sBassin%z_layer(icolonne+1,j)
			                            zz2 = zg2 + xfact*(zd2-zg2)
			                            if ( zp .ge. zz1 .and. zp .lt. zz2 ) then
			                                jlayer = j-1
			                                zfact = ( zp -zz1)/(zz2-zz1)
			                            endif
			                        enddo
			                        !        limite du sous-domaine de gradient
			                        xg1 = Tdomain%sBassin%x_coord(icolonne)
			                        xd1 = Tdomain%sBassin%x_coord(icolonne+1)
			                        zg1 = Tdomain%sBassin%z_layer(icolonne,jlayer)
			                        zd1 = Tdomain%sBassin%z_layer(icolonne+1,jlayer)
			                        zg2 = Tdomain%sBassin%z_layer(icolonne,jlayer+1)
			                        zd2 = Tdomain%sBassin%z_layer(icolonne+1,jlayer+1)
			                        !
			                        zrho1 = Tdomain%sBassin%z_rho(icolonne,jlayer)
			                        zrho2 = Tdomain%sBassin%z_rho(icolonne,jlayer+1)
			                        zCp1 = Tdomain%sBassin%z_Cp(icolonne,jlayer)
			                        zCp2 = Tdomain%sBassin%z_Cp(icolonne,jlayer+1)
			                        zCs1 = Tdomain%sBassin%z_Cs(icolonne,jlayer)
			                        zCs2 = Tdomain%sBassin%z_Cs(icolonne,jlayer+1)

			                        if ( Tdomain%sBassin%x_type .eq. 0 ) then
			                            !   on met les memes proprietes dans toute la maille
			                            zfact = 0.D0
			                            zrho   = zrho1 + zfact*(zrho2-zrho1)
			                            zCp   = zCp1 + zfact*(zCp2-zCp1)
			                            zCs   = zCs1 + zfact*(zCs2-zCs1)
			                            !     calcul des coeffcients elastiques
			                            Mu     = zrho*zCs*zCs
			                            Lambda = zrho*(zCp*zCp - zCs*zCs)
			                            Kappa  = Lambda + 2.D0*Mu/3.D0
			                        endif

			                        !     boucle sur les points de Gauss de la maille
			                        !     xp, yp, zp coordonnees du point de Gauss
			                        do k = 0, ngllz -1
			                            do j = 0,nglly-1
			                                do i = 0,ngllx-1
			                                    ipoint = Tdomain%specel(n)%Iglobnum(i,j,k)
			                                    xp = Tdomain%GlobCoord(0,ipoint)
			                                    yp = Tdomain%GlobCoord(1,ipoint)
			                                    zp = Tdomain%GlobCoord(2,ipoint)
			                                    if ( Tdomain%sBassin%x_type .ge. 1 ) then
			                                        !    interpolations  pour le calcul du gradient
			                                        xfact = ( xp - xg1)/(xd1-xg1)
			                                        zz1   = zg1 + xfact*(zd1-zg1)
			                                        zz2   = zg2 + xfact*(zd2-zg2)
			                                        zfact = ( zp - zz1)/(zz2-zz1)
			                                        zrho  = zrho1 + zfact*(zrho2-zrho1)
			                                        zCp   = zCp1 + zfact*(zCp2-zCp1)
			                                        zCs   = zCs1 + zfact*(zCs2-zCs1)
			                                        !     calcul des coeffcients elastiques
			                                        Mu     = zrho*zCs*zCs
			                                        Lambda = zrho*(zCp*zCp - zCs*zCs)
			                                        Kappa  = Lambda + 2.D0*Mu/3.D0
			                                    endif
			                                    Tdomain%specel(n)%Density(i,j,k) = zrho
			                                    Tdomain%specel(n)%Lambda(i,j,k) = Lambda
			                                    Tdomain%specel(n)%Kappa(i,j,k) = Kappa
			                                    Tdomain%specel(n)%Mu(i,j,k) = Mu
			                                enddo
			                            enddo
			                        enddo
			                        !    fin test iflag nul
			                    endif
			                    !    fin modification des proprietes des couches de materiaux
			                endif
			            case default
			            	write(*,*) "Material ", mat, " is not treated in case switch"

					end select
					!END select by "Tdomain%sSubDomain(mat)%material_definition"

					!Putting properties in "prop" (TO BE REMADE)
	                do i = 0, ngllx-1
	                    do j = 0, nglly-1
	                        do k = 0, ngllz-1

	                        	ipoint  = Tdomain%specel(n)%Iglobnum(i,j,k)
	                        	!write(*,*) "ipoint = ", ipoint
	                        	RFpoint = count(Tdomain%sSubDomain(mat)%globCoordMask(0,0:ipoint)) - 1
	                        	!write(*,*) "RFpoint = ", RFpoint
	                        	!write(*,*) "size(Tdomain%sSubDomain(mat)%prop) = ", size(Tdomain%sSubDomain(mat)%prop)
                                prop(RFpoint, 0) = Tdomain%specel(n)%Density(i,j,k)
                                prop(RFpoint, 1) = Tdomain%specel(n)%Lambda(i,j,k)
                                prop(RFpoint, 2) = Tdomain%specel(n)%Mu(i,j,k)
	                        end do
	                    end do
	                end do
				end do
				!END Loop over subdomain elements

	!////////////////////
	!//////////////////// CASE MATERIAL_CONSTANT AND OTHERS
	!////////////////////
	        else
	        	if(rg == 0) write(*,*) ">>>>Building constant properties"
	            do i = 0, nProp - 1
	                prop(:,i) = avgProp(i)
	            end do
			end if

	!////////////////////
	!//////////////////// APPLYING PROPERTIES TO THE ELEMENTS
	!////////////////////
			if(rg == 0) write(*,*) ">>>>Applying calculated properties"
	    	!call dispCarvalhol(prop, "prop", "F30.10")
			do m = 0, Tdomain%sSubDomain(mat)%nElem - 1
		    	n = Tdomain%sSubDomain(mat)%elemList(m)
				do i = 0, ngllx-1
			    	do j = 0, nglly-1
			        	do k = 0, ngllz-1
			            	ipoint  = Tdomain%specel(n)%Iglobnum(i,j,k)
			                RFpoint = count(Tdomain%sSubDomain(mat)%globCoordMask(0,0:ipoint)) - 1
		                    Tdomain%specel(n)%Density(i,j,k) = prop(RFpoint, 0)
		                    Tdomain%specel(n)%Lambda(i,j,k)  = prop(RFpoint, 1)
		                    Tdomain%specel(n)%Mu(i,j,k)      = prop(RFpoint, 2)
			        	end do
			    	end do
				end do
				if(Tdomain%sSubDomain(mat)%material_definition /= MATERIAL_GRADIENT) then
					Tdomain%specel(n)%Kappa = Tdomain%sSubDomain(mat)%DKappa
				end if
		    end do
		end if
		!Subdomain existence condition

	!////////////////////
	!//////////////////// WRITING .h5 file
	!////////////////////
		if(rg == 0) write(*,*) ">>>>>Writing .h5 file"
		if(rg == 0) write(*,*) "procFileName = ", procFileName
		call write_ResultHDF5Unstruct_MPI(xPoints, prop, trim(procFileName), &
										  rg, trim(h5folder), &
	    								  Tdomain%communicateur, ["_proc", "_subD"], [rg, mat], HDF5NameList(mat))
	    deallocate(xPoints)
	    deallocate(prop)
	end do
	!END Loop over subdomains

	!Writing XMF File
	if(rg == 0) write(*,*) ">>>>Writing XMF file"
	!write(*,*) "HDF5NameList in rang ", rg, " = ", HDF5NameList
	call writeXMF_RF_MPI(nProp, HDF5NameList, nSubDPoints, Tdomain%n_dime, trim(string_join(procFileName,"-byProc-")), rg, trim(XMFfolder), &
    					 Tdomain%communicateur, trim(h5_to_xmf), ["Density","Lambda","Mu"], byProc = .true.)
	call writeXMF_RF_MPI(nProp, HDF5NameList, nSubDPoints, Tdomain%n_dime, trim(string_join(procFileName,"-bySubD-")), rg, trim(XMFfolder), &
    					 Tdomain%communicateur, trim(h5_to_xmf), ["Density","Lambda","Mu"], byProc = .false.)
  	!if(rg == 0) write(*,*) "After XMF creation"
!
!	!Converting "R" subdomains to "S" subdomains (same treatement from now on)
!	do mat = 0, Tdomain%n_mat - 1
!		if(Tdomain%sSubdomain(mat)%material_type == "R") Tdomain%sSubdomain(mat)%material_type = "S"
!	end do

!	!Printing for verification
!	do n = 0,Tdomain%n_elem-1
!		if(rg < 6) then
!			write(*,*) ""
!			write(*,*) "rang = ", rg
!			write(*,*) "ELEM ", n
!			write(*,*) "Dens = ", Tdomain%specel(n)%Density
!		end if
!	end do

    !Deallocating
	if (allocated(xPoints))  deallocate(xPoints)
	if (allocated(prop))     deallocate(prop)

	do mat = 0, Tdomain%n_mat - 1
	    !if (allocated(Tdomain%sSubDomain(mat)%prop))          deallocate(Tdomain%sSubDomain(mat)%prop)
	    if (allocated(Tdomain%sSubDomain(mat)%margiFirst))    deallocate(Tdomain%sSubDomain(mat)%margiFirst)
	    if (allocated(Tdomain%sSubDomain(mat)%MinBound))      deallocate(Tdomain%sSubDomain(mat)%MinBound)
	    if (allocated(Tdomain%sSubDomain(mat)%MaxBound))      deallocate(Tdomain%sSubDomain(mat)%MaxBound)
	    if (allocated(Tdomain%sSubDomain(mat)%chosenSeed))    deallocate(Tdomain%sSubDomain(mat)%chosenSeed)
	    if (allocated(Tdomain%sSubDomain(mat)%corrL))         deallocate(Tdomain%sSubDomain(mat)%corrL)
	    !To discuss deallocation of the above
	    if (allocated(Tdomain%sSubDomain(mat)%globCoordMask)) deallocate(Tdomain%sSubDomain(mat)%globCoordMask)
	    if (allocated(Tdomain%sSubdomain(mat)%elemList))      deallocate(Tdomain%sSubdomain(mat)%elemList)
	end do

	if(allocated(HDF5NameList)) deallocate (HDF5NameList)
	if(allocated(nSubDPoints))  deallocate (nSubDPoints)
	if(allocated(avgProp))      deallocate(avgProp)
	!write(*,*) "After deallocation"


	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!From here on no modification caused by Random Fields integration on this file

    do n = 0,Tdomain%n_elem-1
        mat = Tdomain%specel(n)%mat_index
        !        il faut avoir passe avant de courant.f90 pour avoir le bon pas de temps
        !          print*," valeur du pas de temps ",Tdomain%sSubdomain(mat)%Dt
        ngllx = Tdomain%specel(n)%ngllx
        nglly = Tdomain%specel(n)%nglly
        ngllz = Tdomain%specel(n)%ngllz
        !je sais pas trop ce que tout ça fait

        if (Tdomain%aniso) then
        else
            if ((.not. Tdomain%specel(n)%PML) .and. (Tdomain%n_sls>0))  then
                !   Tdomain%specel(n)%Kappa = Tdomain%sSubDomain(mat)%DKappa
            endif
        endif

        !  modif mariotti fevrier 2007 cea
        if ((.not. Tdomain%specel(n)%PML) .and. (Tdomain%n_sls>0))  then
            if (Tdomain%aniso) then
                Tdomain%specel(n)%sl%Q = Tdomain%sSubDomain(mat)%Qmu
            else
                Tdomain%specel(n)%sl%Qs = Tdomain%sSubDomain(mat)%Qmu
                Tdomain%specel(n)%sl%Qp = Tdomain%sSubDomain(mat)%Qpression
            endif
        endif

        allocate(Jac(0:ngllx-1,0:nglly-1,0:ngllz-1))
        allocate(xix(0:ngllx-1,0:nglly-1,0:ngllz-1))
        allocate(xiy(0:ngllx-1,0:nglly-1,0:ngllz-1))
        allocate(xiz(0:ngllx-1,0:nglly-1,0:ngllz-1))
        allocate(etax(0:ngllx-1,0:nglly-1,0:ngllz-1))
        allocate(etay(0:ngllx-1,0:nglly-1,0:ngllz-1))
        allocate(etaz(0:ngllx-1,0:nglly-1,0:ngllz-1))
        allocate(zetax(0:ngllx-1,0:nglly-1,0:ngllz-1))
        allocate(zetay(0:ngllx-1,0:nglly-1,0:ngllz-1))
        allocate(zetaz(0:ngllx-1,0:nglly-1,0:ngllz-1))
        allocate(Whei(0:ngllx-1,0:nglly-1,0:ngllz-1))
        allocate(RKmod(0:ngllx-1,0:nglly-1,0:ngllz-1))
        allocate(Rlam(0:ngllx-1,0:nglly-1,0:ngllz-1))
        allocate(Rmu(0:ngllx-1,0:nglly-1,0:ngllz-1))

        !- general (element) weighting: tensorial property..
        do k = 0,ngllz-1
            do j = 0,nglly-1
                do i = 0,ngllx-1
                    Whei(i,j,k) = Tdomain%sSubdomain(mat)%GLLwx(i) *       &
                        Tdomain%sSubdomain(mat)%GLLwy(j)*Tdomain%sSubdomain(mat)%GLLwz(k)
                enddo
            enddo
        enddo

        xix = Tdomain%specel(n)%InvGrad(:,:,:,0,0)
        xiy = Tdomain%specel(n)%InvGrad(:,:,:,1,0)
        xiz = Tdomain%specel(n)%InvGrad(:,:,:,2,0)

        etax = Tdomain%specel(n)%InvGrad(:,:,:,0,1)
        etay = Tdomain%specel(n)%InvGrad(:,:,:,1,1)
        etaz = Tdomain%specel(n)%InvGrad(:,:,:,2,1)

        zetax = Tdomain%specel(n)%InvGrad(:,:,:,0,2)
        zetay = Tdomain%specel(n)%InvGrad(:,:,:,1,2)
        zetaz = Tdomain%specel(n)%InvGrad(:,:,:,2,2)

        Jac  = Tdomain%specel(n)%Jacob
        Rlam = Tdomain%specel(n)%Lambda
        Rmu  = Tdomain%specel(n)%Mu
        RKmod = Rlam + 2. * Rmu

       !- verif. for fluid part
        if(.not. Tdomain%specel(n)%solid .and. maxval(RMu) > 1.d-5) stop "Fluid element with a non null shear modulus."

        !- mass matrix elements
        if(Tdomain%specel(n)%solid)then
            Tdomain%specel(n)%MassMat = Whei*Tdomain%specel(n)%Density*Jac
        else   ! fluid case: inertial term ponderation by the inverse of the bulk modulus
            Tdomain%specel(n)%MassMat = Whei*Jac/Rlam
        end if

        !- parts of the internal forces terms: Acoeff; to be compared to
        !  general expressions = products of material properties and nabla operators

!        if(.not. Tdomain%specel(n)%PML)then
!            if(Tdomain%specel(n)%solid)then
                !call define_Acoeff_iso(ngllx,nglly,ngllz,Rkmod,Rmu,Rlam,xix,xiy,xiz,    &
                !    etax,etay,etaz,zetax,zetay,zetaz,Whei,Jac,Tdomain%specel(n)%Acoeff)
!            else   ! fluid case
!                call define_Acoeff_fluid(ngllx,nglly,ngllz,Tdomain%specel(n)%Density,xix,xiy,xiz,    &
!                    etax,etay,etaz,zetax,zetay,zetaz,Whei,Jac,Tdomain%specel(n)%Acoeff)
!            end if

        if(Tdomain%specel(n)%PML)then   ! PML case: valid for solid and fluid parts
            if(Tdomain%specel(n)%solid)then
                call define_Acoeff_PML_iso(ngllx,nglly,ngllz,Rkmod,Rmu,Rlam,xix,xiy,xiz,    &
                    etax,etay,etaz,zetax,zetay,zetaz,Whei,Jac,Tdomain%specel(n)%sl%Acoeff)
            else  ! fluid case
                call define_Acoeff_PML_fluid(ngllx,nglly,ngllz,Tdomain%specel(n)%Density,xix,xiy,xiz,    &
                    etax,etay,etaz,zetax,zetay,zetaz,Whei,Jac,Tdomain%specel(n)%fl%Acoeff)
            end if

            !- definition of the attenuation coefficient in PMLs (alpha in the literature)
            allocate(wx(0:ngllx-1,0:nglly-1,0:ngllz-1))
            allocate(wy(0:ngllx-1,0:nglly-1,0:ngllz-1))
            allocate(wz(0:ngllx-1,0:nglly-1,0:ngllz-1))

            call define_alpha_PML(Tdomain%sSubDomain(mat)%Px,0,Tdomain%sSubDomain(mat)%Left, &
                ngllx,nglly,ngllz,ngllx,Tdomain%n_glob_points,Tdomain%GlobCoord,       &
                Tdomain%sSubDomain(mat)%GLLcx,RKmod(:,0,0),                            &
                Tdomain%specel(n)%Density(:,0,0),Tdomain%specel(n)%Iglobnum(0,0,0),    &
                Tdomain%specel(n)%Iglobnum(ngllx-1,0,0),Tdomain%sSubdomain(mat)%Apow,  &
                Tdomain%sSubdomain(mat)%npow,wx)
            call define_alpha_PML(Tdomain%sSubDomain(mat)%Py,1,Tdomain%sSubDomain(mat)%Forward, &
                ngllx,nglly,ngllz,nglly,Tdomain%n_glob_points,Tdomain%GlobCoord,          &
                Tdomain%sSubDomain(mat)%GLLcy,RKmod(0,:,0),                               &
                Tdomain%specel(n)%Density(0,:,0),Tdomain%specel(n)%Iglobnum(0,0,0),       &
                Tdomain%specel(n)%Iglobnum(0,nglly-1,0),Tdomain%sSubdomain(mat)%Apow,     &
                Tdomain%sSubdomain(mat)%npow,wy)
            call define_alpha_PML(Tdomain%sSubDomain(mat)%Pz,2,Tdomain%sSubDomain(mat)%Down, &
                ngllx,nglly,ngllz,ngllz,Tdomain%n_glob_points,Tdomain%GlobCoord,       &
                Tdomain%sSubDomain(mat)%GLLcz,RKmod(0,0,:),                            &
                Tdomain%specel(n)%Density(0,0,:),Tdomain%specel(n)%Iglobnum(0,0,0),    &
                Tdomain%specel(n)%Iglobnum(0,0,ngllz-1),Tdomain%sSubdomain(mat)%Apow,  &
                Tdomain%sSubdomain(mat)%npow,wz)


            !- M-PMLs
            if(Tdomain%logicD%MPML)then
                allocate(temp_PMLx(0:ngllx-1,0:nglly-1,0:ngllz-1))
                allocate(temp_PMLy(0:ngllx-1,0:nglly-1,0:ngllz-1))
                temp_PMLx(:,:,:) = wx(:,:,:)
                temp_PMLy(:,:,:) = wy(:,:,:)
                wx(:,:,:) = wx(:,:,:)+Tdomain%MPML_coeff*(wy(:,:,:)+wz(:,:,:))
                wy(:,:,:) = wy(:,:,:)+Tdomain%MPML_coeff*(temp_PMLx(:,:,:)+wz(:,:,:))
                wz(:,:,:) = wz(:,:,:)+Tdomain%MPML_coeff*(temp_PMLx(:,:,:)+temp_PMLy(:,:,:))
                deallocate(temp_PMLx,temp_PMLy)
            end if

            !- strong formulation for stresses. Dumped mass elements, convolutional terms.
            if(Tdomain%specel(n)%FPML)then
                call define_FPML_DumpInit(ngllx,nglly,ngllz,Tdomain%sSubdomain(mat)%Dt,        &
                    Tdomain%sSubdomain(mat)%freq,wx,Tdomain%specel(n)%Density,             &
                    whei,Jac,Tdomain%specel(n)%slpml%DumpSx,Tdomain%specel(n)%slpml%DumpMass(:,:,:,0), &
                    Tdomain%specel(n)%slpml%Isx,Tdomain%specel(n)%slpml%Ivx)
                call define_FPML_DumpInit(ngllx,nglly,ngllz,Tdomain%sSubdomain(mat)%Dt,        &
                    Tdomain%sSubdomain(mat)%freq,wy,Tdomain%specel(n)%Density,             &
                    whei,Jac,Tdomain%specel(n)%slpml%DumpSy,Tdomain%specel(n)%slpml%DumpMass(:,:,:,1), &
                    Tdomain%specel(n)%slpml%Isy,Tdomain%specel(n)%slpml%Ivy)
                call define_FPML_DumpInit(ngllx,nglly,ngllz,Tdomain%sSubdomain(mat)%Dt,        &
                    Tdomain%sSubdomain(mat)%freq,wz,Tdomain%specel(n)%Density,             &
                    whei,Jac,Tdomain%specel(n)%slpml%DumpSz,Tdomain%specel(n)%slpml%DumpMass(:,:,:,2), &
                    Tdomain%specel(n)%slpml%Isz,Tdomain%specel(n)%slpml%Ivz)
            else
                call define_PML_DumpInit(ngllx,nglly,ngllz,Tdomain%sSubdomain(mat)%Dt,   &
                    wx,Tdomain%specel(n)%Density,RKmod,whei,Jac,                         &
                    Tdomain%specel(n)%slpml%DumpSx,Tdomain%specel(n)%slpml%DumpMass(:,:,:,0), &
                    Tdomain%specel(n)%solid)
                call define_PML_DumpInit(ngllx,nglly,ngllz,Tdomain%sSubdomain(mat)%Dt,   &
                    wy,Tdomain%specel(n)%Density,RKmod,whei,Jac,                         &
                    Tdomain%specel(n)%slpml%DumpSy,Tdomain%specel(n)%slpml%DumpMass(:,:,:,1), &
                    Tdomain%specel(n)%solid)
                call define_PML_DumpInit(ngllx,nglly,ngllz,Tdomain%sSubdomain(mat)%Dt,   &
                    wz,Tdomain%specel(n)%Density,RKmod,whei,Jac,                         &
                    Tdomain%specel(n)%slpml%DumpSz,Tdomain%specel(n)%slpml%DumpMass(:,:,:,2), &
                    Tdomain%specel(n)%solid)
            endif
            deallocate(wx,wy,wz)

        endif

        deallocate(Jac,xix,xiy,xiz,etax,etay,etaz,zetax,zetay,zetaz,Whei,RKmod,Rmu,Rlam)


    enddo ! end of the loop upon elements

    if( Tdomain%earthchunk_isInit/=0) then
        ! call clean_model()
    endif



    !- Mass and DumpMass Communications (assemblage) inside Processors
    do n = 0,Tdomain%n_elem-1
        call get_Mass_Elem2Face(Tdomain,n)
        call get_Mass_Elem2Edge(Tdomain,n)
        call get_Mass_Elem2Vertex(Tdomain,n)
    enddo


    !- Inverting Mass Matrix expression
    do n = 0,Tdomain%n_elem-1
        ngllx = Tdomain%specel(n)%ngllx
        nglly = Tdomain%specel(n)%nglly
        ngllz = Tdomain%specel(n)%ngllz

        if(Tdomain%specel(n)%PML)then   ! dumped masses in PML
            if(Tdomain%specel(n)%FPML)then
                call define_FPML_DumpEnd(0,ngllx,nglly,ngllz,Tdomain%specel(n)%MassMat,   &
                    Tdomain%specel(n)%slpml%DumpMass,Tdomain%specel(n)%slpml%DumpVx,Tdomain%specel(n)%slpml%Ivx)
                call define_FPML_DumpEnd(1,ngllx,nglly,ngllz,Tdomain%specel(n)%MassMat,   &
                    Tdomain%specel(n)%slpml%DumpMass,Tdomain%specel(n)%slpml%DumpVy,Tdomain%specel(n)%slpml%Ivy)
                call define_FPML_DumpEnd(2,ngllx,nglly,ngllz,Tdomain%specel(n)%MassMat,   &
                    Tdomain%specel(n)%slpml%DumpMass,Tdomain%specel(n)%slpml%DumpVz,Tdomain%specel(n)%slpml%Ivz)
            else
                call define_PML_DumpEnd(n,rg,ngllx,nglly,ngllz,Tdomain%specel(n)%MassMat,   &
                    Tdomain%specel(n)%slpml%DumpMass(:,:,:,0),Tdomain%specel(n)%slpml%DumpVx)
                call define_PML_DumpEnd(n,rg,ngllx,nglly,ngllz,Tdomain%specel(n)%MassMat,   &
                    Tdomain%specel(n)%slpml%DumpMass(:,:,:,1),Tdomain%specel(n)%slpml%DumpVy)
                call define_PML_DumpEnd(n,rg,ngllx,nglly,ngllz,Tdomain%specel(n)%MassMat,   &
                    Tdomain%specel(n)%slpml%DumpMass(:,:,:,2),Tdomain%specel(n)%slpml%DumpVz)
            end if
            deallocate(Tdomain%specel(n)%slpml%DumpMass)
        end if
        ! all elements
        allocate(LocMassMat(1:ngllx-2,1:nglly-2,1:ngllz-2))
        LocMassMat(:,:,:) = Tdomain%specel(n)%MassMat(1:ngllx-2,1:nglly-2,1:ngllz-2)
        LocMassmat(:,:,:) = 1d0/LocMassMat(:,:,:)  ! inversion
        deallocate(Tdomain%specel(n)%MassMat)
        allocate(Tdomain%specel(n)%MassMat(1:ngllx-2,1:nglly-2,1:ngllz-2))
        Tdomain%specel(n)%MassMat(:,:,:) = LocMassMat(:,:,:)

        deallocate(LocMassMat)

        !deallocate(Tdomain%specel(n)%Lambda)
        !deallocate(Tdomain%specel(n)%Mu)
        !deallocate(Tdomain%specel(n)%InvGrad)

    enddo


    !- defining Neumann properties (Btn: the complete normal term, ponderated
    !      by Gaussian weights)
    if(Tdomain%logicD%neumann_local_present)then
        call define_FEV_Neumann(Tdomain)
    endif

    !- defining Solid/Fluid faces'properties
    if(Tdomain%logicD%SF_local_present)then
        !  Btn: the complete normal term, ponderated by GLL weights
        call define_Face_SF(Tdomain)
        ! density (which links VelPhi and pressure)
        do nf = 0,Tdomain%SF%SF_n_faces-1
            nnf = Tdomain%SF%SF_Face(nf)%Face(0)
            if(nnf < 0) cycle
            n = Tdomain%sFace(nnf)%which_elem
            dir = Tdomain%sFace(nnf)%dir
            ngll1 = Tdomain%SF%SF_Face(nf)%ngll1
            ngll2 = Tdomain%SF%SF_Face(nf)%ngll2
            ngllx = Tdomain%specel(n)%ngllx
            nglly = Tdomain%specel(n)%nglly
            ngllz = Tdomain%specel(n)%ngllz
            if(dir == 0)then
                Tdomain%SF%SF_Face(nf)%density(0:ngll1-1,0:ngll2-1) =    &
                    Tdomain%specel(n)%density(0:ngllx-1,0:nglly-1,0)
            else if(dir == 1)then
                Tdomain%SF%SF_Face(nf)%density(0:ngll1-1,0:ngll2-1) =    &
                    Tdomain%specel(n)%density(0:ngllx-1,0,0:ngllz-1)
            else if(dir == 2)then
                Tdomain%SF%SF_Face(nf)%density(0:ngll1-1,0:ngll2-1) =    &
                    Tdomain%specel(n)%density(ngllx-1,0:nglly-1,0:ngllz-1)
            else if(dir == 3)then
                Tdomain%SF%SF_Face(nf)%density(0:ngll1-1,0:ngll2-1) =    &
                    Tdomain%specel(n)%density(0:ngllx-1,nglly-1,0:ngllz-1)
            else if(dir == 4)then
                Tdomain%SF%SF_Face(nf)%density(0:ngll1-1,0:ngll2-1) =    &
                    Tdomain%specel(n)%density(0,0:nglly-1,0:ngllz-1)
            else if(dir == 5)then
                Tdomain%SF%SF_Face(nf)%density(0:ngll1-1,0:ngll2-1) =    &
                    Tdomain%specel(n)%density(0:ngllx-1,0:nglly-1,ngllz-1)
            end if
        end do
    endif


    !----------------------------------------------------------
    !- MPI communications: assemblage between procs
    !----------------------------------------------------------
    if(Tdomain%n_proc > 1)then
        !-------------------------------------------------
        !- from external faces, edges and vertices to Communication global arrays
        do n = 0,Tdomain%n_proc-1
            call Comm_Mass_Complete(n,Tdomain)
            call Comm_Mass_Complete_PML(n,Tdomain)
            call Comm_Normal_Neumann(n,Tdomain)
        enddo

        call exchange_sem(Tdomain, rg)

        ! now: assemblage on external faces, edges and vertices
        do n = 0,Tdomain%n_proc-1
            ngll_tot = 0
            ngllPML_tot = 0
            ngllNeu = 0

            call Comm_Mass_Face(Tdomain,n,ngll_tot,ngllPML_tot)
            call Comm_Mass_Edge(Tdomain,n,ngll_tot,ngllPML_tot)
            call Comm_Mass_Vertex(Tdomain,n,ngll_tot,ngllPML_tot)

            ! Neumann
            do i = 0,Tdomain%sComm(n)%Neu_ne_shared-1
                ne = Tdomain%sComm(n)%Neu_edges_shared(i)
                ngll1 = Tdomain%Neumann%Neu_Edge(ne)%ngll
                if(Tdomain%sComm(n)%Neu_mapping_edges_shared(i) == 0)then
                    do j = 1,Tdomain%Neumann%Neu_Edge(ne)%ngll-2
                        Tdomain%Neumann%Neu_Edge(ne)%BtN(j,0:2) = Tdomain%Neumann%Neu_Edge(ne)%Btn(j,0:2) +  &
                            Tdomain%sComm(n)%TakeNeu(ngllNeu,0:2)
                        ngllNeu = ngllNeu + 1
                    enddo
                else if(Tdomain%sComm(n)%Neu_mapping_edges_shared(i) == 1)then
                    do j = 1,Tdomain%Neumann%Neu_Edge(ne)%ngll-2
                        Tdomain%Neumann%Neu_Edge(ne)%Btn(ngll1-1-j,0:2) = Tdomain%Neumann%Neu_Edge(ne)%Btn(ngll1-1-j,0:2) + &
                            Tdomain%sComm(n)%TakeNeu(ngllNeu,0:2)
                        ngllNeu = ngllNeu + 1
                    enddo
                else
                    print*,'Pb with coherency number for edge in define arrays'
                    STOP 1
                endif
            enddo
            do i = 0,Tdomain%sComm(n)%Neu_nv_shared-1
                nv = Tdomain%sComm(n)%Neu_vertices_shared(i)
                Tdomain%Neumann%Neu_Vertex(nv)%Btn(0:2) = Tdomain%Neumann%Neu_Vertex(nv)%Btn(0:2) + &
                    Tdomain%sComm(n)%TakeNeu(ngllNeu,0:2)
                ngllNeu = ngllNeu + 1
            enddo


            if(Tdomain%sComm(n)%ngll_tot > 0)then
                deallocate(Tdomain%sComm(n)%Give)
                deallocate(Tdomain%sComm(n)%Take)
            endif
            if(Tdomain%sComm(n)%ngllPML_tot > 0)then
                deallocate(Tdomain%sComm(n)%GivePML)
                deallocate(Tdomain%sComm(n)%TakePML)
            endif
            if(Tdomain%sComm(n)%ngllNeu > 0)then
                deallocate(Tdomain%sComm(n)%GiveNeu)
                deallocate(Tdomain%sComm(n)%TakeNeu)
            endif
            ! end of the loop upon processors
        enddo
        !--------------------------------------------------------------
    endif

    !- back to local properties: now we can calculate PML properties
    !     at nodes of faces, edges and vertices.
    do nf = 0,Tdomain%n_face-1
        if(Tdomain%sFace(nf)%PML)then
            ngll1 = Tdomain%sFace(nf)%ngll1 ; ngll2 = Tdomain%sFace(nf)%ngll2
            call define_PML_Face_DumpEnd(ngll1,ngll2,Tdomain%sFace(nf)%Massmat,  &
                Tdomain%sFace(nf)%spml%DumpMass(:,:,0),Tdomain%sFace(nf)%spml%DumpVx)
            call define_PML_Face_DumpEnd(ngll1,ngll2,Tdomain%sFace(nf)%Massmat,  &
                Tdomain%sFace(nf)%spml%DumpMass(:,:,1),Tdomain%sFace(nf)%spml%DumpVy)
            call define_PML_Face_DumpEnd(ngll1,ngll2,Tdomain%sFace(nf)%Massmat,  &
                Tdomain%sFace(nf)%spml%DumpMass(:,:,2),Tdomain%sFace(nf)%spml%DumpVz)
            deallocate(Tdomain%sFace(nf)%spml%DumpMass)
        endif
        Tdomain%sFace(nf)%MassMat = 1./ Tdomain%sFace(nf)%MassMat
    enddo

    do ne = 0,Tdomain%n_edge-1
        if(Tdomain%sEdge(ne)%PML)then
            ngll = Tdomain%sEdge(ne)%ngll
            call define_PML_Edge_DumpEnd(ngll,Tdomain%sEdge(ne)%Massmat,    &
                Tdomain%sEdge(ne)%spml%DumpMass(:,0),Tdomain%sEdge(ne)%spml%DumpVx)
            call define_PML_Edge_DumpEnd(ngll,Tdomain%sEdge(ne)%Massmat,    &
                Tdomain%sEdge(ne)%spml%DumpMass(:,1),Tdomain%sEdge(ne)%spml%DumpVy)
            call define_PML_Edge_DumpEnd(ngll,Tdomain%sEdge(ne)%Massmat,    &
                Tdomain%sEdge(ne)%spml%DumpMass(:,2),Tdomain%sEdge(ne)%spml%DumpVz)
            deallocate(Tdomain%sEdge(ne)%spml%DumpMass)
        endif
        Tdomain%sEdge(ne)%MassMat = 1./ Tdomain%sEdge(ne)%MassMat
    enddo

    do nv = 0,Tdomain%n_vertex-1
        if(Tdomain%sVertex(nv)%PML)then
            call define_PML_Vertex_DumpEnd(Tdomain%sVertex(nv)%Massmat,    &
                Tdomain%sVertex(nv)%spml%DumpMass(0),Tdomain%sVertex(nv)%spml%DumpVx)
            call define_PML_Vertex_DumpEnd(Tdomain%sVertex(nv)%Massmat,    &
                Tdomain%sVertex(nv)%spml%DumpMass(1),Tdomain%sVertex(nv)%spml%DumpVy)
            call define_PML_Vertex_DumpEnd(Tdomain%sVertex(nv)%Massmat,    &
                Tdomain%sVertex(nv)%spml%DumpMass(2),Tdomain%sVertex(nv)%spml%DumpVz)
        endif
        Tdomain%sVertex(nv)%MassMat = 1./ Tdomain%sVertex(nv)%MassMat
    enddo

    return
end subroutine define_arrays
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
subroutine define_Acoeff_iso(ngllx,nglly,ngllz,Rkmod,Rmu,Rlam,xix,xiy,xiz,    &
    etax,etay,etaz,zetax,zetay,zetaz,Whei,Jac,Acoeff)
    implicit none

    integer, intent(in)  :: ngllx,nglly,ngllz
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(in) :: Rkmod,Rmu,Rlam,  &
        xix,xiy,xiz,etax,etay,etaz,zetax,zetay,zetaz,Whei,Jac
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1,0:44), intent(out) :: Acoeff

    Acoeff(:,:,:,0) = -Whei*(RKmod*xix**2+Rmu*(xiy**2+xiz**2))*Jac
    Acoeff(:,:,:,1) = -Whei*(RKmod*xix*etax+Rmu*(xiy*etay+xiz*etaz))*Jac
    Acoeff(:,:,:,2) = -Whei*(RKmod*xix*zetax+Rmu*(xiy*zetay+xiz*zetaz))*Jac
    Acoeff(:,:,:,3) = -Whei*(Rlam+Rmu)*xix*xiy*Jac
    Acoeff(:,:,:,4) = -Whei*(Rlam*xix*etay+Rmu*xiy*etax)*Jac
    Acoeff(:,:,:,5) = -Whei*(Rlam*xix*zetay+Rmu*xiy*zetax)*Jac
    Acoeff(:,:,:,6) = -Whei*(Rlam+Rmu)*xix*xiz*Jac
    Acoeff(:,:,:,7) = -Whei*(Rlam*xix*etaz+Rmu*xiz*etax)*Jac
    Acoeff(:,:,:,8) = -Whei*(Rlam*xix*zetaz+rmu*xiz*zetax)*Jac
    Acoeff(:,:,:,9) = -Whei*(RKmod*etax**2+Rmu*(etay**2+etaz**2))*Jac
    Acoeff(:,:,:,10) = -Whei*(RKmod*etax*zetax+Rmu*(etay*zetay+etaz*zetaz))*Jac
    Acoeff(:,:,:,11) = -Whei*(Rlam*etax*xiy+Rmu*etay*xix)*Jac
    Acoeff(:,:,:,12) = -Whei*(Rlam+Rmu)*etay*etax*Jac
    Acoeff(:,:,:,13) = -Whei*(Rlam*etax*zetay+Rmu*etay*zetax)*Jac
    Acoeff(:,:,:,14) = -Whei*(Rlam*etax*xiz+Rmu*etaz*xix)*Jac
    Acoeff(:,:,:,15) = -Whei*(Rlam+Rmu)*etaz*etax*Jac
    Acoeff(:,:,:,16) = -Whei*(Rlam*etax*zetaz+Rmu*etaz*zetax)*Jac
    Acoeff(:,:,:,17) = -Whei*(RKmod*zetax**2+Rmu*(zetay**2+zetaz**2))*Jac
    Acoeff(:,:,:,18) = -Whei*(Rlam*zetax*xiy+Rmu*zetay*xix)*Jac
    Acoeff(:,:,:,19) = -Whei*(Rlam*zetax*etay+Rmu*zetay*etax)*Jac
    Acoeff(:,:,:,20) = -Whei*(Rlam+Rmu)*zetax*zetay*Jac
    Acoeff(:,:,:,21) = -Whei*(Rlam*zetax*xiz+Rmu*zetaz*xix)*Jac
    Acoeff(:,:,:,22) = -Whei*(Rlam*zetax*etaz+Rmu*zetaz*etax)*Jac
    Acoeff(:,:,:,23) = -Whei*(Rlam+Rmu)*zetax*zetaz*Jac
    Acoeff(:,:,:,24) = -Whei*(RKmod*xiy**2+Rmu*(xix**2+xiz**2))*Jac
    Acoeff(:,:,:,25) = -Whei*(RKmod*xiy*etay+Rmu*(xix*etax+xiz*etaz))*Jac
    Acoeff(:,:,:,26) = -Whei*(RKmod*xiy*zetay+Rmu*(xix*zetax+xiz*zetaz))*Jac
    Acoeff(:,:,:,27) = -Whei*(Rlam+Rmu)*xiy*xiz*Jac
    Acoeff(:,:,:,28) = -Whei*(Rlam*etaz*xiy+Rmu*etay*xiz)*Jac
    Acoeff(:,:,:,29) = -Whei*(Rlam*zetaz*xiy+Rmu*zetay*xiz)*Jac
    Acoeff(:,:,:,30) = -Whei*(RKmod*etay**2+Rmu*(etax**2+etaz**2))*Jac
    Acoeff(:,:,:,31) = -Whei*(RKmod*zetay*etay+Rmu*(zetax*etax+zetaz*etaz))*Jac
    Acoeff(:,:,:,32) = -Whei*(Rlam*etay*xiz+Rmu*etaz*xiy)*Jac
    Acoeff(:,:,:,33) = -Whei*(Rlam+Rmu)*etay*etaz*Jac
    Acoeff(:,:,:,34) = -Whei*(Rlam*zetaz*etay+Rmu*zetay*etaz)*Jac
    Acoeff(:,:,:,35) = -Whei*(RKmod*zetay**2+Rmu*(zetax**2+zetaz**2))*Jac
    Acoeff(:,:,:,36) = -Whei*(Rlam*xiz*zetay+Rmu*xiy*zetaz)*Jac
    Acoeff(:,:,:,37) = -Whei*(Rlam*zetay*etaz+Rmu*zetaz*etay)*Jac
    Acoeff(:,:,:,38) = -Whei*(Rlam+Rmu)*zetay*zetaz*Jac
    Acoeff(:,:,:,39) = -Whei*(RKmod*xiz**2+Rmu*(xix**2+xiy**2))*Jac
    Acoeff(:,:,:,40) = -Whei*(RKmod*xiz*etaz+Rmu*(xix*etax+xiy*etay))*Jac
    Acoeff(:,:,:,41) = -Whei*(RKmod*xiz*zetaz+Rmu*(xix*zetax+xiy*zetay))*Jac
    Acoeff(:,:,:,42) = -Whei*(RKmod*etaz**2+Rmu*(etax**2+etay**2))*Jac
    Acoeff(:,:,:,43) = -Whei*(RKmod*zetaz*etaz+Rmu*(zetax*etax+zetay*etay))*Jac
    Acoeff(:,:,:,44) = -Whei*(RKmod*zetaz**2+Rmu*(zetax**2+zetay**2))*Jac

    return

end subroutine define_Acoeff_iso
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
subroutine define_Acoeff_fluid(ngllx,nglly,ngllz,Density,xix,xiy,xiz,    &
    etax,etay,etaz,zetax,zetay,zetaz,Whei,Jac,Acoeff)

    implicit none

    integer, intent(in)  :: ngllx,nglly,ngllz
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(in) :: Density,  &
        xix,xiy,xiz,etax,etay,etaz,zetax,zetay,zetaz,Whei,Jac
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1,0:5), intent(out) :: Acoeff

    Acoeff(:,:,:,0) = -Whei*(xix**2+xiy**2+xiz**2)*Jac/density
    Acoeff(:,:,:,1) = -Whei*(xix*etax+xiy*etay+xiz*etaz)*Jac/density
    Acoeff(:,:,:,2) = -Whei*(xix*zetax+xiy*zetay+xiz*zetaz)*Jac/density
    Acoeff(:,:,:,3) = -Whei*(etax**2+etay**2+etaz**2)*Jac/density
    Acoeff(:,:,:,4) = -Whei*(etax*zetax+etay*zetay+etaz*zetaz)*Jac/density
    Acoeff(:,:,:,5) = -Whei*(zetax**2+zetay**2+zetaz**2)*Jac/density


end subroutine define_Acoeff_fluid
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
subroutine define_Acoeff_PML_iso(ngllx,nglly,ngllz,Rkmod,Rmu,Rlam,xix,xiy,xiz,    &
    etax,etay,etaz,zetax,zetay,zetaz,Whei,Jac,Acoeff)

    implicit none

    integer, intent(in)  :: ngllx,nglly,ngllz
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(in) :: Rkmod,Rmu,Rlam,  &
        xix,xiy,xiz,etax,etay,etaz,zetax,zetay,zetaz,Whei,Jac
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1,0:35), intent(out) :: Acoeff


    Acoeff(:,:,:,0) = RKmod *xix
    Acoeff(:,:,:,1) = RKmod *etax
    Acoeff(:,:,:,2) = RKmod *zetax
    Acoeff(:,:,:,3) = RLam *xiy
    Acoeff(:,:,:,4) = RLam *etay
    Acoeff(:,:,:,5) = RLam *zetay
    Acoeff(:,:,:,6) = RLam *xiz
    Acoeff(:,:,:,7) = RLam *etaz
    Acoeff(:,:,:,8) = RLam *zetaz
    Acoeff(:,:,:,9) = RLam *xix
    Acoeff(:,:,:,10) = RLam *etax
    Acoeff(:,:,:,11) = RLam *zetax
    Acoeff(:,:,:,12) = RKmod *xiy
    Acoeff(:,:,:,13) = RKmod *etay
    Acoeff(:,:,:,14) = RKmod *zetay
    Acoeff(:,:,:,15) = RKmod *xiz
    Acoeff(:,:,:,16) = RKmod *etaz
    Acoeff(:,:,:,17) = RKmod *zetaz
    Acoeff(:,:,:,18) = RMu *xix
    Acoeff(:,:,:,19) = RMu *etax
    Acoeff(:,:,:,20) = RMu *zetax
    Acoeff(:,:,:,21) = RMu *xiy
    Acoeff(:,:,:,22) = RMu *etay
    Acoeff(:,:,:,23) = RMu *zetay
    Acoeff(:,:,:,24) = RMu *xiz
    Acoeff(:,:,:,25) = RMu *etaz
    Acoeff(:,:,:,26) = RMu *zetaz
    Acoeff(:,:,:,27) = -Whei * xix * Jac
    Acoeff(:,:,:,28) = -Whei * xiy * Jac
    Acoeff(:,:,:,29) = -Whei * xiz * Jac
    Acoeff(:,:,:,30) = -Whei * etax * Jac
    Acoeff(:,:,:,31) = -Whei * etay * Jac
    Acoeff(:,:,:,32) = -Whei * etaz * Jac
    Acoeff(:,:,:,33) = -Whei * zetax * Jac
    Acoeff(:,:,:,34) = -Whei * zetay * Jac
    Acoeff(:,:,:,35) = -Whei * zetaz * Jac

    return

end subroutine define_Acoeff_PML_iso
!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
subroutine define_Acoeff_PML_fluid(ngllx,nglly,ngllz,density,xix,xiy,xiz,    &
    etax,etay,etaz,zetax,zetay,zetaz,Whei,Jac,Acoeff)

    implicit none

    integer, intent(in)  :: ngllx,nglly,ngllz
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(in) :: density,  &
        xix,xiy,xiz,etax,etay,etaz,zetax,zetay,zetaz,Whei,Jac
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1,0:17), intent(out) :: Acoeff


    Acoeff(:,:,:,0) = xix(:,:,:)/density(:,:,:)
    Acoeff(:,:,:,1) = etax(:,:,:)/density(:,:,:)
    Acoeff(:,:,:,2) = zetax(:,:,:)/density(:,:,:)
    Acoeff(:,:,:,3) = xiy(:,:,:)/density(:,:,:)
    Acoeff(:,:,:,4) = etay(:,:,:)/density(:,:,:)
    Acoeff(:,:,:,5) = zetay(:,:,:)/density(:,:,:)
    Acoeff(:,:,:,6) = xiz(:,:,:)/density(:,:,:)
    Acoeff(:,:,:,7) = etaz(:,:,:)/density(:,:,:)
    Acoeff(:,:,:,8) = zetaz(:,:,:)/density(:,:,:)
    Acoeff(:,:,:,9) = -whei(:,:,:)*xix(:,:,:)*Jac(:,:,:)
    Acoeff(:,:,:,10) = -whei(:,:,:)*etax(:,:,:)*Jac(:,:,:)
    Acoeff(:,:,:,11) = -whei(:,:,:)*zetax(:,:,:)*Jac(:,:,:)
    Acoeff(:,:,:,12) = -whei(:,:,:)*xiy(:,:,:)*Jac(:,:,:)
    Acoeff(:,:,:,13) = -whei(:,:,:)*etay(:,:,:)*Jac(:,:,:)
    Acoeff(:,:,:,14) = -whei(:,:,:)*zetay(:,:,:)*Jac(:,:,:)
    Acoeff(:,:,:,15) = -whei(:,:,:)*xiz(:,:,:)*Jac(:,:,:)
    Acoeff(:,:,:,16) = -whei(:,:,:)*etaz(:,:,:)*Jac(:,:,:)
    Acoeff(:,:,:,17) = -whei(:,:,:)*zetaz(:,:,:)*Jac(:,:,:)

    return

end subroutine define_Acoeff_PML_fluid
!-------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------
subroutine define_alpha_PML(lattenu,dir,ldir_attenu,ngllx,nglly,ngllz,ngll,n_pts,   &
    Coord,GLLc,Rkmod,Density,ind_min,ind_max,Apow,npow,alpha)
    !- routine determines attenuation profile in an PML layer (see Festa & Vilotte)
    !   dir = attenuation's direction, ldir_attenu = the logical giving the orientation

    implicit none

    logical, intent(in)   :: lattenu,ldir_attenu
    integer, intent(in) :: dir,ngllx,nglly,ngllz,ngll,n_pts,ind_min,ind_max,npow
    real, dimension(0:2,0:n_pts-1), intent(in) :: Coord
    real, dimension(0:ngll-1), intent(in) :: GLLc,RKmod,Density
    real, intent(in)  :: Apow
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(out) :: alpha
    integer  :: i
    real  :: dh
    real, dimension(0:ngll-1)  :: ri,vp
    real, external  :: pow

    if(.not. lattenu)then   ! no attenuation in the dir-direction
        alpha(:,:,:) = 0d0
    else  ! yes, attenuation in this dir-direction
        dh = Coord(dir,ind_min)
        dh = abs(Coord(dir,ind_max)-dh)
        if(ldir_attenu)then  ! Left in x, Forward in y, Down in z
            ri(:) = 0.5d0*(1d0+GLLc(ngll-1:0:-1))*float(ngll-1)
        else  ! Right in x, Backward in y, Up in z
            ri(:) = 0.5d0*(1d0+GLLc(0:ngll-1))*float(ngll-1)
        end if
        vp(:) = sqrt(Rkmod(:)/Density(:))
        select case(dir)
        case(0)  ! dir = x
            do i = 0,ngll-1
                alpha(i,0:,0:) = pow(ri(i),vp(i),ngll-1,dh,Apow,npow)
            end do
        case(1)  ! dir = y
            do i = 0,ngll-1
                alpha(0:,i,0:) = pow(ri(i),vp(i),ngll-1,dh,Apow,npow)
            end do
        case(2)  ! dir = z
            do i = 0,ngll-1
                alpha(0:,0:,i) = pow(ri(i),vp(i),ngll-1,dh,Apow,npow)
            end do
        end select
    end if

    return

end subroutine define_alpha_PML
!----------------------------------------------------------------------------------
!----------------------------------------------------------------------------------
subroutine define_FPML_DumpInit(ngllx,nglly,ngllz,dt,freq,alpha,density,whei,jac,  &
    DumpS,DumpMass,Is,Iv)
    !- defining parameters related to stresses and mass matrix elements, in the case of
    !    a FPML, along a given splitted direction:
    implicit none

    integer, intent(in)  :: ngllx,nglly,ngllz
    real, intent(in) :: dt,freq
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(in) :: alpha
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(in) :: density,whei,Jac
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1,0:1), intent(out) :: DumpS
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(out) :: DumpMass,Is,Iv
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1)  :: Id

    Id = 1d0

    DumpS(:,:,:,1) = Id + 0.5d0*dt*alpha*freq
    DumpS(:,:,:,1) = 1d0/DumpS(:,:,:,1)
    DumpS(:,:,:,0) = (Id - 0.5d0*dt*alpha*freq)*DumpS(:,:,:,1)

    DumpMass(:,:,:) = 0.5d0*Density(:,:,:)*Whei(:,:,:)*Jac(:,:,:)*alpha(:,:,:)*dt*freq

    Is(:,:,:) = dt*alpha(:,:,:)*freq*DumpS(:,:,:,1)

    Iv(:,:,:)= Density(:,:,:)*Whei(:,:,:)*Dt*alpha(:,:,:)*Jac(:,:,:)*freq

    return

end subroutine define_FPML_DumpInit
!----------------------------------------------------------------------------------
!----------------------------------------------------------------------------------
subroutine define_PML_DumpInit(ngllx,nglly,ngllz,dt,alpha,density,RKmod,whei,jac,  &
    DumpS,DumpMass,solid)
    !- defining parameters related to stresses and mass matrix elements, in the case of
    !    a PML, along a given splitted direction:
    implicit none

    integer, intent(in)  :: ngllx,nglly,ngllz
    real, intent(in) :: dt
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(in) :: alpha
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(in) :: density,RKmod,whei,Jac
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1,0:1), intent(out) :: DumpS
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(out) :: DumpMass
    logical, intent(in)   :: solid
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1)  :: Id

    Id = 1d0

    DumpS(:,:,:,1) = Id + 0.5d0*dt*alpha
    DumpS(:,:,:,1) = 1d0/DumpS(:,:,:,1)
    DumpS(:,:,:,0) = (Id - 0.5d0*dt*alpha)*DumpS(:,:,:,1)

    DumpMass(:,:,:) = 0.5d0*Density(:,:,:)*Whei(:,:,:)*Jac(:,:,:)*alpha(:,:,:)*dt
    if(.not. solid) DumpMass(:,:,:) = DumpMass(:,:,:)/RKmod(:,:,:)/Density(:,:,:)

    return

end subroutine define_PML_DumpInit
!----------------------------------------------------------------------------------
!----------------------------------------------------------------------------------
subroutine define_PML_DumpEnd(n,rg,ngllx,nglly,ngllz,Massmat,DumpMass,DumpV)

    implicit none
    integer, intent(in)   :: ngllx,nglly,ngllz,n,rg
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(in) :: MassMat
    real, dimension(1:ngllx-2,1:nglly-2,1:ngllz-2,0:1), intent(out) :: DumpV
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(in) :: DumpMass
    real, dimension(1:ngllx-2,1:nglly-2,1:ngllz-2)  :: LocMassMat

    LocMassMat(:,:,:) = MassMat(1:ngllx-2,1:nglly-2,1:ngllz-2)
    DumpV(:,:,:,1) = LocMassMat + DumpMass(1:ngllx-2,1:nglly-2,1:ngllz-2)
    DumpV(:,:,:,1) = 1d0/DumpV(:,:,:,1)
    DumpV(:,:,:,0) = LocMassMat - DumpMass(1:ngllx-2,1:nglly-2,1:ngllz-2)
    DumpV(:,:,:,0) = DumpV(:,:,:,0) * DumpV(:,:,:,1)

    return

end subroutine define_PML_DumpEnd
!----------------------------------------------------------------------------------
!----------------------------------------------------------------------------------
subroutine define_FPML_DumpEnd(dir,ngllx,nglly,ngllz,Massmat,DumpMass,DumpV,Iv)

    implicit none
    integer, intent(in)   :: dir,ngllx,nglly,ngllz
    real, dimension(0:ngllx-1,0:nglly-1,0:ngllz-1), intent(in) :: MassMat
    real, dimension(1:ngllx-2,1:nglly-2,1:ngllz-2,0:1), intent(out) :: DumpV
    real, dimension(1:ngllx-2,1:nglly-2,1:ngllz-2,0:1),intent(in) :: DumpMass
    real, dimension(:,:,:), allocatable, intent(inout) :: Iv
    real, dimension(1:ngllx-2,1:nglly-2,1:ngllz-2)  :: LocMassMat

    LocMassMat(:,:,:) = MassMat(1:ngllx-2,1:nglly-2,1:ngllz-2)

    DumpV(:,:,:,1) = LocMassMat + DumpMass(1:ngllx-2,1:nglly-2,1:ngllz-2,dir)
    DumpV(:,:,:,1) = 1d0/DumpV(:,:,:,1)
    DumpV(:,:,:,0) = LocMassMat - DumpMass(1:ngllx-2,1:nglly-2,1:ngllz-2,dir)
    DumpV(:,:,:,0) = DumpV(:,:,:,0) * DumpV(:,:,:,1)

    LocMassMat = Iv(1:ngllx-2,1:nglly-2,1:ngllz-2)
    deallocate(Iv)
    allocate(Iv(1:ngllx-2,1:nglly-2,1:ngllz-2))
    Iv = LocMassMat*DumpV(:,:,:,1)

    return

end subroutine define_FPML_DumpEnd
!----------------------------------------------------------------------------------
!----------------------------------------------------------------------------------
subroutine Comm_Mass_Complete(n,Tdomain)
    use sdomain
    implicit none

    integer, intent(in)  :: n
    type(domain), intent(inout) :: Tdomain
    integer  :: i,j,k,ngll,nf,ne,nv

    ngll = 0
    ! faces
    do i = 0,Tdomain%sComm(n)%nb_faces-1
        nf = Tdomain%sComm(n)%faces(i)
        do j = 1,Tdomain%sFace(nf)%ngll2-2
            do k = 1,Tdomain%sFace(nf)%ngll1-2
                Tdomain%sComm(n)%Give(ngll) = Tdomain%sFace(nf)%MassMat(k,j)
                ngll = ngll + 1
            enddo
        enddo
    enddo
    ! edges
    do i = 0,Tdomain%sComm(n)%nb_edges-1
        ne = Tdomain%sComm(n)%edges(i)
        do j = 1,Tdomain%sEdge(ne)%ngll-2
            Tdomain%sComm(n)%Give(ngll) = Tdomain%sEdge(ne)%MassMat(j)
            ngll = ngll + 1
        enddo
    enddo
    ! vertices
    do i = 0,Tdomain%sComm(n)%nb_vertices-1
        nv =  Tdomain%sComm(n)%vertices(i)
        Tdomain%sComm(n)%Give(ngll) = Tdomain%svertex(nv)%MassMat
        ngll = ngll + 1
    enddo

    if(ngll /= Tdomain%sComm(n)%ngll_tot) &
        stop "Incompatibility in mass transmission between procs."

end subroutine Comm_Mass_Complete
!----------------------------------------------------------------------------------
!----------------------------------------------------------------------------------
subroutine Comm_Mass_Complete_PML(n,Tdomain)
    use sdomain
    implicit none

    integer, intent(in)  :: n
    type(domain), intent(inout) :: Tdomain
    integer  :: i,j,k,ngllPML,nf,ne,nv

    ngllPML = 0
    ! faces
    do i = 0,Tdomain%sComm(n)%nb_faces-1
        nf = Tdomain%sComm(n)%faces(i)
        if(Tdomain%sFace(nf)%PML)then
            do j = 1,Tdomain%sFace(nf)%ngll2-2
                do k = 1,Tdomain%sFace(nf)%ngll1-2
                    Tdomain%sComm(n)%GivePML(ngllPML,0:2) = Tdomain%sFace(nf)%spml%DumpMass(k,j,0:2)
                    if(Tdomain%any_FPML)then
                        Tdomain%sComm(n)%GivePML(ngllPML,3) = Tdomain%sFace(nf)%spml%Ivx(k,j)
                        Tdomain%sComm(n)%GivePML(ngllPML,4) = Tdomain%sFace(nf)%spml%Ivy(k,j)
                        Tdomain%sComm(n)%GivePML(ngllPML,5) = Tdomain%sFace(nf)%spml%Ivz(k,j)
                    endif
                    ngllPML = ngllPML + 1
                enddo
            enddo
        endif
    enddo
    ! edges
    do i = 0,Tdomain%sComm(n)%nb_edges-1
        ne = Tdomain%sComm(n)%edges(i)
        if(Tdomain%sEdge(ne)%PML)then
            do j = 1,Tdomain%sEdge(ne)%ngll-2
                Tdomain%sComm(n)%GivePML(ngllPML,0:2) = Tdomain%sEdge(ne)%spml%DumpMass(j,0:2)
                if(Tdomain%any_FPML)then
                    Tdomain%sComm(n)%GivePML(ngllPML,3) = Tdomain%sEdge(ne)%spml%Ivx(j)
                    Tdomain%sComm(n)%GivePML(ngllPML,4) = Tdomain%sEdge(ne)%spml%Ivy(j)
                    Tdomain%sComm(n)%GivePML(ngllPML,5) = Tdomain%sEdge(ne)%spml%Ivz(j)
                endif
                ngllPML = ngllPML + 1
            enddo
        endif
    enddo
    do i = 0,Tdomain%sComm(n)%nb_vertices-1
        nv = Tdomain%sComm(n)%vertices(i)
        if(Tdomain%sVertex(nv)%PML)then
            Tdomain%sComm(n)%GivePML(ngllPML,0:2) = Tdomain%sVertex(nv)%spml%DumpMass(0:2)
            if(Tdomain%any_FPML)then
                Tdomain%sComm(n)%GivePML(ngllPML,3) = Tdomain%sVertex(nv)%spml%Ivx(0)
                Tdomain%sComm(n)%GivePML(ngllPML,4) = Tdomain%sVertex(nv)%spml%Ivy(0)
                Tdomain%sComm(n)%GivePML(ngllPML,5) = Tdomain%sVertex(nv)%spml%Ivz(0)
            endif
            ngllPML = ngllPML + 1
        endif
    enddo

    if(ngllPML /= Tdomain%sComm(n)%ngllPML_tot) &
        stop "Incompatibility in mass transmission between procs."

end subroutine Comm_Mass_Complete_PML
!----------------------------------------------------------------------------------
!----------------------------------------------------------------------------------
subroutine Comm_Normal_Neumann(n,Tdomain)
    use sdomain
    implicit none

    integer, intent(in)  :: n
    type(domain), intent(inout) :: Tdomain
    integer  :: i,j,ngllneu,ne,nv

    ngllNeu = 0

    do i = 0,Tdomain%sComm(n)%Neu_ne_shared-1
        ne = Tdomain%sComm(n)%Neu_edges_shared(i)
        do j = 1,Tdomain%Neumann%Neu_Edge(ne)%ngll-2
            Tdomain%sComm(n)%GiveNeu(ngllNeu,0:2) = Tdomain%Neumann%Neu_Edge(ne)%BtN(j,0:2)
            ngllNeu = ngllNeu + 1
        enddo
    enddo
    do i = 0,Tdomain%sComm(n)%Neu_nv_shared-1
        nv = Tdomain%sComm(n)%Neu_vertices_shared(i)
        Tdomain%sComm(n)%GiveNeu(ngllNeu,0:2) = Tdomain%Neumann%Neu_Vertex(nv)%BtN(0:2)
        ngllNeu = ngllNeu + 1
    enddo

    if(ngllNeu /= Tdomain%sComm(n)%ngllNeu) &
        stop "Incompatibility in Neumann normal transmission between procs."

end subroutine Comm_Normal_Neumann
!----------------------------------------------------------------------------------
!----------------------------------------------------------------------------------
subroutine define_PML_Face_DumpEnd(ngll1,ngll2,Massmat,DumpMass,DumpV)

    implicit none
    integer, intent(in)   :: ngll1,ngll2
    real, dimension(1:ngll1-2,1:ngll2-2), intent(in) :: MassMat
    real, dimension(1:ngll1-2,1:ngll2-2,0:1), intent(out) :: DumpV
    real, dimension(1:ngll1-2,1:ngll2-2), intent(in) :: DumpMass

    DumpV(:,:,1) = MassMat + DumpMass
    DumpV(:,:,1) = 1d0/DumpV(:,:,1)
    DumpV(:,:,0) = MassMat - DumpMass
    DumpV(:,:,0) = DumpV(:,:,0) * DumpV(:,:,1)

    return

end subroutine define_PML_Face_DumpEnd
!----------------------------------------------------------------------------------
!----------------------------------------------------------------------------------
subroutine define_PML_Edge_DumpEnd(ngll,Massmat,DumpMass,DumpV)

    implicit none
    integer, intent(in)   :: ngll
    real, dimension(1:ngll-2), intent(in) :: MassMat
    real, dimension(1:ngll-2,0:1), intent(out) :: DumpV
    real, dimension(1:ngll-2), intent(in) :: DumpMass

    DumpV(:,1) = MassMat + DumpMass
    DumpV(:,1) = 1d0/DumpV(:,1)
    DumpV(:,0) = MassMat - DumpMass
    DumpV(:,0) = DumpV(:,0) * DumpV(:,1)

    return

end subroutine define_PML_Edge_DumpEnd
!----------------------------------------------------------------------------------
!----------------------------------------------------------------------------------
subroutine define_PML_Vertex_DumpEnd(Massmat,DumpMass,DumpV)

    implicit none
    real, intent(in) :: MassMat
    real, dimension(0:1), intent(out) :: DumpV
    real, intent(in) :: DumpMass

    DumpV(1) = MassMat + DumpMass
    DumpV(1) = 1d0/DumpV(1)
    DumpV(0) = MassMat - DumpMass
    DumpV(0) = DumpV(0) * DumpV(1)

    return

end subroutine define_PML_Vertex_DumpEnd
!----------------------------------------------------------------------------------
!----------------------------------------------------------------------------------
!! Local Variables:
!! mode: f90
!! show-trailing-whitespace: t
!! End:
!! vim: set sw=4 ts=8 et tw=80 smartindent : !!
