!>
!! \file savefield.f90
!! \brief
!! \author
!! \version 1.0
!! \date
!! \bug V�rifier l'ordre des boucles dans la d�finition du tableau Field
!<
#ifdef MKA3D
subroutine savefield (Tdomain, it, sortie_capteur_vitesse, rg, i_snap)
#else
subroutine savefield (Tdomain, it, sortie_capteur_vitesse, rg, icount, i_snap)
#endif

    use sdomain
    use semdatafiles

    implicit none

    type (domain), intent(INOUT) :: Tdomain
    integer, intent (IN) :: it, rg, i_snap
    logical :: sortie_capteur_vitesse
    integer icount, nbvert, nv
    ! local variables
    integer :: i, j, k, n, ipoint
    character (len=MAX_FILE_SIZE) :: fnamef
#ifdef MKA3D
    integer :: n_vertex, n_face, n_edge
    real,allocatable :: Field(:,:)
    character(len=5) :: cit, crank
    integer :: ngllx, nglly, ngllz, ngll1, ngll2
#endif

#ifdef MKA3D
    allocate(Field(0:2,0:Tdomain%n_glob_points-1))

    ! interieur du domaine

    do n = 0,Tdomain%n_elem-1
        ngllx = Tdomain%specel(n)%ngllx
        nglly = Tdomain%specel(n)%nglly
        ngllz = Tdomain%specel(n)%ngllz
        do k = 1,ngllz-2
            do j = 1,nglly-2
                do i = 1,ngllx-2
                    ipoint = Tdomain%specel(n)%Iglobnum(i,j,k)
                    Field (0,ipoint) = Tdomain%specel(n)%Veloc(i,j,k,0)
                    Field (1,ipoint) = Tdomain%specel(n)%Veloc(i,j,k,1)
                    Field (2,ipoint) = Tdomain%specel(n)%Veloc(i,j,k,2)
                enddo
            enddo
        enddo

        ! Faces a z fixe  !On peut ecrire plusieurs fois les faces (voir test du Near_element en 2D)

        if(Tdomain%specel(n)%Orient_faces(0) == 0) then
            n_face = Tdomain%specel(n)%Near_faces(0)
            ngll1 = Tdomain%sFace(n_face)%ngll1
            ngll2 = Tdomain%sFace(n_face)%ngll2

            do j = 1, ngll2-2
                do i = 1, ngll1-2
                    ipoint = Tdomain%specel(n)%Iglobnum(i,j,0)
                    Field (0,ipoint) = Tdomain%sFace(n_face)%Veloc(i,j,0)
                    Field (1,ipoint) = Tdomain%sFace(n_face)%Veloc(i,j,1)
                    Field (2,ipoint) = Tdomain%sFace(n_face)%Veloc(i,j,2)
                enddo
            enddo
        endif

        if(Tdomain%specel(n)%Orient_faces(5) == 0) then
            n_face = Tdomain%specel(n)%Near_faces(5)
            ngll1 = Tdomain%sFace(n_face)%ngll1
            ngll2 = Tdomain%sFace(n_face)%ngll2

            do j = 1, ngll2-2
                do i = 1, ngll1-2
                    ipoint = Tdomain%specel(n)%Iglobnum(i,j,ngllz-1)
                    Field (0,ipoint) = Tdomain%sFace(n_face)%Veloc(i,j,0)
                    Field (1,ipoint) = Tdomain%sFace(n_face)%Veloc(i,j,1)
                    Field (2,ipoint) = Tdomain%sFace(n_face)%Veloc(i,j,2)
                enddo
            enddo
        endif
        ! Faces a y fixe  !On ne doit ecrire qu'une seule fois les faces (et pas deux fois)
        if(Tdomain%specel(n)%Orient_faces(1) == 0) then
            n_face = Tdomain%specel(n)%Near_faces(1)
            ngll1 = Tdomain%sFace(n_face)%ngll1
            ngll2 = Tdomain%sFace(n_face)%ngll2

            do k = 1, ngll2-2
                do i = 1, ngll1-2
                    ipoint = Tdomain%specel(n)%Iglobnum(i,0,k)
                    Field (0,ipoint) = Tdomain%sFace(n_face)%Veloc(i,k,0)
                    Field (1,ipoint) = Tdomain%sFace(n_face)%Veloc(i,k,1)
                    Field (2,ipoint) = Tdomain%sFace(n_face)%Veloc(i,k,2)
                enddo
            enddo
        endif

        if(Tdomain%specel(n)%Orient_faces(3) == 0) then
            n_face = Tdomain%specel(n)%Near_faces(3)
            ngll1 = Tdomain%sFace(n_face)%ngll1
            ngll2 = Tdomain%sFace(n_face)%ngll2
            do k = 1, ngll2-2
                do i = 1, ngll1-2
                    ipoint = Tdomain%specel(n)%Iglobnum(i,nglly-1,k)
                    Field (0,ipoint) = Tdomain%sFace(n_face)%Veloc(i,k,0)
                    Field (1,ipoint) = Tdomain%sFace(n_face)%Veloc(i,k,1)
                    Field (2,ipoint) = Tdomain%sFace(n_face)%Veloc(i,k,2)
                enddo
            enddo
        endif

        ! Faces a x fixe  !On ne doit ecrire qu'une seule fois les faces (et pas deux fois)
        if(Tdomain%specel(n)%Orient_faces(4) == 0) then
            n_face = Tdomain%specel(n)%Near_faces(4)
            ngll1 = Tdomain%sFace(n_face)%ngll1
            ngll2 = Tdomain%sFace(n_face)%ngll2
            do k = 1, ngll2-2
                do j = 1, ngll1-2
                    ipoint = Tdomain%specel(n)%Iglobnum(0,j,k)
                    Field (0,ipoint) = Tdomain%sFace(n_face)%Veloc(j,k,0)
                    Field (1,ipoint) = Tdomain%sFace(n_face)%Veloc(j,k,1)
                    Field (2,ipoint) = Tdomain%sFace(n_face)%Veloc(j,k,2)
                enddo
            enddo
        endif
        if(Tdomain%specel(n)%Orient_faces(2) == 0) then
            n_face = Tdomain%specel(n)%Near_faces(2)
            ngll1 = Tdomain%sFace(n_face)%ngll1
            ngll2 = Tdomain%sFace(n_face)%ngll2
            do k = 1, ngll2-2
                do j = 1, ngll1-2
                    ipoint = Tdomain%specel(n)%Iglobnum(ngllx-1,j,k)
                    Field (0,ipoint) = Tdomain%sFace(n_face)%Veloc(j,k,0)
                    Field (1,ipoint) = Tdomain%sFace(n_face)%Veloc(j,k,1)
                    Field (2,ipoint) = Tdomain%sFace(n_face)%Veloc(j,k,2)
                enddo
            enddo
        endif
        ! Aretes a x variant  !On ne doit ecrire qu'une seule fois les aretes (et pas deux fois)
        if ( Tdomain%specel(n)%Orient_Edges(0) == 0 ) then
            n_edge = Tdomain%specel(n)%Near_edges(0)
            ngll1 = Tdomain%sEdge(n_edge)%ngll
            do j = 1, ngll1-2
                ipoint = Tdomain%specel(n)%Iglobnum(j,0,0)
                Field (0,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,0)
                Field (1,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,1)
                Field (2,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,2)
            enddo
        endif

        if ( Tdomain%specel(n)%Orient_Edges(2) == 0 ) then
            n_edge = Tdomain%specel(n)%Near_edges(2)
            ngll1 = Tdomain%sEdge(n_edge)%ngll
            do j = 1, ngll1-2
                ipoint = Tdomain%specel(n)%Iglobnum(j,nglly-1,0)
                Field (0,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,0)
                Field (1,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,1)
                Field (2,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,2)
            enddo
        endif

        if ( Tdomain%specel(n)%Orient_Edges(5) == 0 ) then
            n_edge = Tdomain%specel(n)%Near_edges(5)
            ngll1 = Tdomain%sEdge(n_edge)%ngll
            do j = 1, ngll1-2
                ipoint = Tdomain%specel(n)%Iglobnum(j,0,ngllz-1)
                Field (0,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,0)
                Field (1,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,1)
                Field (2,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,2)
            enddo
        endif

        if ( Tdomain%specel(n)%Orient_Edges(9) == 0 ) then
            n_edge = Tdomain%specel(n)%Near_edges(9)
            ngll1 = Tdomain%sEdge(n_edge)%ngll
            do j = 1, ngll1-2
                ipoint = Tdomain%specel(n)%Iglobnum(j,nglly-1,ngllz-1)
                Field (0,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,0)
                Field (1,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,1)
                Field (2,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,2)
            enddo
        endif
        ! Aretes a y variant  !On ne doit ecrire qu'une seule fois les aretes (et pas deux fois)
        if ( Tdomain%specel(n)%Orient_Edges(1) == 0 ) then
            n_edge = Tdomain%specel(n)%Near_edges(1)
            ngll1 = Tdomain%sEdge(n_edge)%ngll
            do j = 1, ngll1-2
                ipoint = Tdomain%specel(n)%Iglobnum(ngllx-1,j,0)
                Field (0,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,0)
                Field (1,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,1)
                Field (2,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,2)
            enddo
        endif

        if ( Tdomain%specel(n)%Orient_Edges(3) == 0 ) then
            n_edge = Tdomain%specel(n)%Near_edges(3)
            ngll1 = Tdomain%sEdge(n_edge)%ngll
            do j = 1, ngll1-2
                ipoint = Tdomain%specel(n)%Iglobnum(0,j,0)
                Field (0,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,0)
                Field (1,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,1)
                Field (2,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,2)
            enddo
        endif

        if ( Tdomain%specel(n)%Orient_Edges(8) == 0 ) then
            n_edge = Tdomain%specel(n)%Near_edges(8)
            ngll1 = Tdomain%sEdge(n_edge)%ngll
            do j = 1, ngll1-2
                ipoint = Tdomain%specel(n)%Iglobnum(ngllx-1,j,ngllz-1)
                Field (0,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,0)
                Field (1,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,1)
                Field (2,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,2)
            enddo
        endif

        if ( Tdomain%specel(n)%Orient_Edges(11) == 0 ) then
            n_edge = Tdomain%specel(n)%Near_edges(11)
            ngll1 = Tdomain%sEdge(n_edge)%ngll
            do j = 1, ngll1-2
                ipoint = Tdomain%specel(n)%Iglobnum(0,j,ngllz-1)
                Field (0,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,0)
                Field (1,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,1)
                Field (2,ipoint) = Tdomain%sEdge(n_edge)%Veloc(j,2)
            enddo
        endif
        ! Aretes a z variant  !On ne doit ecrire qu'une seule fois les aretes (et pas deux fois)
        if ( Tdomain%specel(n)%Orient_Edges(4) == 0 ) then
            n_edge = Tdomain%specel(n)%Near_edges(4)
            ngll1 = Tdomain%sEdge(n_edge)%ngll
            do i = 1, ngll1-2
                ipoint = Tdomain%specel(n)%Iglobnum(ngllx-1,0,i)
                Field (0,ipoint) = Tdomain%sEdge(n_edge)%Veloc(i,0)
                Field (1,ipoint) = Tdomain%sEdge(n_edge)%Veloc(i,1)
                Field (2,ipoint) = Tdomain%sEdge(n_edge)%Veloc(i,2)
            enddo
        endif

        if ( Tdomain%specel(n)%Orient_Edges(6) == 0 ) then
            n_edge = Tdomain%specel(n)%Near_edges(6)
            ngll1 = Tdomain%sEdge(n_edge)%ngll
            do i = 1, ngll1-2
                ipoint = Tdomain%specel(n)%Iglobnum(0,0,i)
                Field (0,ipoint) = Tdomain%sEdge(n_edge)%Veloc(i,0)
                Field (1,ipoint) = Tdomain%sEdge(n_edge)%Veloc(i,1)
                Field (2,ipoint) = Tdomain%sEdge(n_edge)%Veloc(i,2)
            enddo
        endif

        if ( Tdomain%specel(n)%Orient_Edges(7) == 0 ) then
            n_edge = Tdomain%specel(n)%Near_edges(7)
            ngll1 = Tdomain%sEdge(n_edge)%ngll
            do i = 1, ngll1-2
                ipoint = Tdomain%specel(n)%Iglobnum(ngllx-1,nglly-1,i)
                Field (0,ipoint) = Tdomain%sEdge(n_edge)%Veloc(i,0)
                Field (1,ipoint) = Tdomain%sEdge(n_edge)%Veloc(i,1)
                Field (2,ipoint) = Tdomain%sEdge(n_edge)%Veloc(i,2)
            enddo
        endif

        if ( Tdomain%specel(n)%Orient_Edges(10) == 0 ) then
            n_edge = Tdomain%specel(n)%Near_edges(10)
            ngll1 = Tdomain%sEdge(n_edge)%ngll
            do i = 1, ngll1-2
                ipoint = Tdomain%specel(n)%Iglobnum(0,nglly-1,i)
                Field (0,ipoint) = Tdomain%sEdge(n_edge)%Veloc(i,0)
                Field (1,ipoint) = Tdomain%sEdge(n_edge)%Veloc(i,1)
                Field (2,ipoint) = Tdomain%sEdge(n_edge)%Veloc(i,2)
            enddo
        endif

        !! les sommets sont ecrits deux fois mais sans effet
        n_vertex = Tdomain%specel(n)%Near_vertices(0)
        ipoint = Tdomain%specel(n)%Iglobnum(0,0,0)
        Field (0,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(0)
        Field (1,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(1)
        Field (2,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(2)

        n_vertex = Tdomain%specel(n)%Near_vertices(1)
        ipoint = Tdomain%specel(n)%Iglobnum(ngllx-1,0,0)
        Field (0,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(0)
        Field (1,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(1)
        Field (2,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(2)

        n_vertex = Tdomain%specel(n)%Near_vertices(2)
        ipoint = Tdomain%specel(n)%Iglobnum(ngllx-1,nglly-1,0)
        Field (0,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(0)
        Field (1,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(1)
        Field (2,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(2)

        n_vertex = Tdomain%specel(n)%Near_vertices(3)
        ipoint = Tdomain%specel(n)%Iglobnum(0,nglly-1,0)
        Field (0,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(0)
        Field (1,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(1)
        Field (2,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(2)

        n_vertex = Tdomain%specel(n)%Near_vertices(4)
        ipoint = Tdomain%specel(n)%Iglobnum(0,0,ngllz-1)
        Field (0,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(0)
        Field (1,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(1)
        Field (2,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(2)

        n_vertex = Tdomain%specel(n)%Near_vertices(5)
        ipoint = Tdomain%specel(n)%Iglobnum(ngllx-1,0,ngllz-1)
        Field (0,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(0)
        Field (1,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(1)
        Field (2,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(2)

        n_vertex = Tdomain%specel(n)%Near_vertices(6)
        ipoint = Tdomain%specel(n)%Iglobnum(ngllx-1,nglly-1,ngllz-1)
        Field (0,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(0)
        Field (1,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(1)
        Field (2,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(2)

        n_vertex = Tdomain%specel(n)%Near_vertices(7)
        ipoint = Tdomain%specel(n)%Iglobnum(0,nglly-1,ngllz-1)
        Field (0,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(0)
        Field (1,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(1)
        Field (2,ipoint) = Tdomain%sVertex(n_vertex)%Veloc(2)
    enddo

    if (sortie_capteur_vitesse) then
        do ipoint=0,Tdomain%n_glob_points-1
            Tdomain%GrandeurVitesse(0,ipoint) = Field (0,ipoint)
            Tdomain%GrandeurVitesse(1,ipoint) = Field (1,ipoint)
            Tdomain%GrandeurVitesse(2,ipoint) = Field (2,ipoint)
        enddo
    endif


    if (Tdomain%logicD%save_snapshots .and. i_snap == 0) then
        !! fnamef de la forme fnamef="./Resultats/sem/vel_0530.dat.0002"

        call semname_savefield_results(it,rg,fnamef)
        open (61,file=fnamef,status="unknown",form="formatted")

        do ipoint=0,Tdomain%n_glob_points-1
            write (61,"(I8,3G17.8)") ipoint, Field (0,ipoint),Field (1,ipoint), &
                & Field(2,ipoint)
        enddo
        call flush(61)
        close(61)
    endif

    deallocate(Field)
    !!Version non MKA3D
#else
    if (Tdomain%logicD%Save_Surface .or. Tdomain%logicD%Neumann) then

        call semname_savefield_datfields(rg,"fieldx",icount)
        open (61, file=fnamef, status="unknown", form="formatted")
        call semname_savefield_datfields(rg,"fieldy",icount)
        open (62, file=fnamef, status="unknown", form="formatted")
        call semname_savefield_datfields(rg,"fieldz",icount)
        open (63, file=fnamef, status="unknown", form="formatted")

        if ( Tdomain%logicD%Save_Surface .and. Tdomain%logicD%Neumann ) then
            nbvert = Tdomain%sSurf%n_vertices+Tdomain%sNeu%n_vertices
        else if (Tdomain%logicD%Save_Surface) then
            nbvert = Tdomain%sSurf%n_vertices
        else if (Tdomain%logicD%Neumann) then
            nbvert = Tdomain%sNeu%n_vertices
        endif

        write (61,*) nbvert,Tdomain%TimeD%time_snapshots,Tdomain%TimeD%rtime
        write (62,*) nbvert,Tdomain%TimeD%time_snapshots,Tdomain%TimeD%rtime
        write (63,*) nbvert,Tdomain%TimeD%time_snapshots,Tdomain%TimeD%rtime

        if (Tdomain%logicD%Save_Surface) then
            do nv = 0,Tdomain%sSurf%n_vertices-1
                n = Tdomain%sSurf%nVertex(nv)%Vertex
                write (61,*) n+1, Tdomain%svertex(n)%Veloc(0)
                write (62,*) n+1, Tdomain%svertex(n)%Veloc(1)
                write (63,*) n+1, Tdomain%svertex(n)%Veloc(2)
            enddo
            if (Tdomain%logicD%Neumann) then
                do nv = 0,Tdomain%sNeu%n_vertices-1
                    n = Tdomain%sNeu%nVertex(nv)%Vertex
                    write (61,*) n+1, Tdomain%svertex(n)%Veloc(0)
                    write (62,*) n+1, Tdomain%svertex(n)%Veloc(1)
                    write (63,*) n+1, Tdomain%svertex(n)%Veloc(2)
                enddo
            endif
        else if (Tdomain%logicD%Neumann) then
            do nv = 0,Tdomain%sNeu%n_vertices-1
                n = Tdomain%sNeu%nVertex(nv)%Vertex
                write (61,*) n+1, Tdomain%svertex(n)%Veloc(0)
                write (62,*) n+1, Tdomain%svertex(n)%Veloc(1)
                write (63,*) n+1, Tdomain%svertex(n)%Veloc(2)
            enddo
        endif

        close(61)
        close(62)
        close(63)


    endif
#endif

    return

end subroutine savefield
!! Local Variables:
!! mode: f90
!! show-trailing-whitespace: t
!! End:
!! vim: set sw=4 ts=8 et tw=80 smartindent : !!
