/* This file is part of SEM                                                */
/*                                                                         */
/* Copyright CEA, ECP, IPGP                                                */
/*                                                                         */
#include <sstream>
#include <cstdio>
#include "mesh.h"
#include "metis.h"
#include <map>
#include <algorithm>
#include <vector>
#include <cstdlib>
#include <cstring>
#include "mesh_h5_output.h"
#include "meshpart.h"
#include "mesh_common.h"
#include <unistd.h>

using std::map;
using std::multimap;
using std::vector;
using std::pair;

// =====================================================





// =====================================================
int Mesh3D::add_node(double x, double y, double z)
{
    m_xco.push_back( x );
    m_yco.push_back( y );
    m_zco.push_back( z );
    return m_xco.size()-1;
}

int Mesh3D::add_elem(int mat_idx, const Elem& el)
{
    // Builds elem<->vertex graph
    for(int i=0;i<el.N;++i) {
	m_elems.push_back(el.v[i]);
    }
    m_elems_offs.push_back(m_elems.size());
    m_mat.push_back( mat_idx );
    return m_elems_offs.size()-1;
}


void Mesh3D::partition_mesh(int n_parts)
{
    int ne = n_elems();
    int nn = n_vertices();
    int ncommon = 1;
    int numflags = 0;
    int ncon=1;
    vector<int> vwgt;
    int *vsize=0L;
    int *adjwgt=0L;
    float *tpwgts=0L;
    float *ubvec=0L;
    int *options=0L;
    int edgecut;

    n_procs = n_parts;
    m_procs.resize(ne);
    m_xadj = 0L;
    m_adjncy = 0L;
    METIS_MeshToDual(&ne, &nn, &m_elems_offs[0], &m_elems[0],
		     &ncommon, &numflags, &m_xadj, &m_adjncy);

    //dump_connectivity("conn1.dat");
    // Tentative de reordonnancement des elements pour optimiser la reutilisation de cache
    // lors de la boucle sur les elements
//    vector<int> perm, iperm;
//    perm.resize(ne);
//    iperm.resize(ne);
//    METIS_NodeND(&ne, m_xadj, m_adjncy, 0L, 0L, &perm[0], &iperm[0]);
//    for(int k=0;k<m_xadj[ne];++k) {
//        m_adjncy[k] = perm[m_adjncy[k]];
//    }
//    dump_connectivity("conn2.dat");
    vwgt.resize(ne);
    // Define weights
    for(int k=0;k<ne;++k) {
        const Material& mat = m_materials[m_mat[k]];
        switch(mat.m_type) {
        case DM_SOLID:
            vwgt[k] = 3;
            break;
        case DM_FLUID:
            vwgt[k] = 1;
            break;
        case DM_SOLID_PML:
            vwgt[k] = 9;
            break;
        case DM_FLUID_PML:
            vwgt[k] = 3;
            break;
        default:
            vwgt[k] = 1;

        }
    }
    if (n_parts>1) {
        METIS_PartGraphKway(&ne, &ncon, m_xadj, m_adjncy,
                            &vwgt[0], vsize, adjwgt, &n_procs, tpwgts, ubvec,
                            options, &edgecut, &m_procs[0]);
    } else {
        for(int k=0;k<ne;++k) m_procs[k]=0;
    }
}


void Mesh3D::dump_connectivity(const char* fname)
{
    FILE* fmat = fopen(fname, "wb");
    int ne = n_elems();
    unsigned char* mat = (unsigned char*)malloc(ne*ne*sizeof(unsigned char));
    memset(mat, 0, ne*ne);
    for(int i=0;i<n_elems();++i) {
        for(int k=m_xadj[i];k<m_xadj[i+1];++k) {
            int j = m_adjncy[k];
            mat[i+ne*j] = 1;
            mat[j+ne*i] = 1;
        }
    }
    fwrite(mat, ne*ne, 1, fmat);
    fclose(fmat);
}


void Mesh3D::write_materials(const std::string& str)
{
    printf("Writing Materials");
    write_materials_v2(str);
}

int Mesh3D::read_materials(const std::string& str)
{
    printf("Reading Materials\n");
    return read_materials_v2(str);
}

int Mesh3D::read_materials_v2(const std::string& str)
{
    int         nmats;
    int           k=0;
    char         type;
    char *buffer=NULL;
    size_t linesize=0;
    double  vs,vp,rho;
    int         ngllx;
    double    Qp, Qmu;


    FILE* f = fopen(str.c_str(), "r");
    if (!f) {
        printf("Error: Could not open file: '%s'\n", str.c_str());
        exit(1);
    }
    getData_line(&buffer, &linesize, f);
    sscanf(buffer, "%d", &nmats);
    for(int k=0;k<nmats;++k)  {
        getData_line(&buffer, &linesize, f);
        sscanf(buffer, "%c %lf %lf %lf %d %lf %lf",
               &type, &vp, &vs, &rho, &ngllx, &Qp, &Qmu);

        printf("Mat: %2ld : %c vp=%lf vs=%lf\n", m_materials.size(), type, vp, vs);

        m_materials.push_back(Material(type, vp, vs, rho, Qp, Qmu, ngllx));
    }
    free(buffer);
    return nmats;
}

#define TF(e)  (e ? 'T' : 'F')

void Mesh3D::define_associated_materials()
{
    int nmats = m_materials.size();
    
    for(int k=0;k<nmats;++k) {
        const Material& mat = m_materials[k];
    
        m_bbox[k].set_assocMat(k);
        
        if (mat.is_pml()) {
        	m_bbox[k].set_assocMat(mat.associated_material);
        }
    }
    
    /*
    if( access( "assocMat.spec", F_OK ) != -1 ) {
        printf("\n WARNING! assocMat.spec exists \n");
        FILE* f = fopen("assocMat.spec", "r");
        int k;
        int assocMat;

        while (!feof (f))
        {  
            fscanf (f, "%d", &k);
            fscanf (f, "%d", &assocMat);
            
            printf (" -Material %d associated to Material %d \n", k, assocMat);

            m_bbox[k].set_assocMat(assocMat);      
        }
        fclose (f);    
    }
    else {
        printf("\n WARNING! assocMat.spec doesn't exist \n");
    }
    */

}
void Mesh3D::write_materials_v2(const std::string& str)
{
    FILE* f = fopen(str.c_str(), "w");
    int nmats = m_materials.size();

    fprintf(f, "%d\n", nmats);
    for(int k=0;k<nmats;++k) {
        const Material& mat = m_materials[k];
        fprintf(f, "%c %lf %lf %lf %d %lf %lf\n",
                mat.cinitial_type,
                mat.Pspeed, mat.Sspeed, mat.rho,
                mat.m_ngll,
                mat.Qpression, mat.Qmu);
    }

    fprintf(f, "# PML properties\n");
    fprintf(f, "# npow,Apow,posX,widthX,posY,widthY,posZ,widthZ,mat\n");

    for(int k=0;k<nmats;++k) {
        const Material& mat = m_materials[k];

        if (!mat.is_pml()) continue;
        fprintf(f, "2 10. %lf %lf %lf %lf %lf %lf %d\n",
                mat.xpos, mat.xwidth,
                mat.ypos, mat.ywidth,
                mat.zpos, mat.zwidth, mat.associated_material);

    }

}

void Mesh3D::read_mesh_file(const std::string& fname)
{
    int d0,d1, tag;
    std::vector<int> tagg;
    hid_t file_id = H5Fopen(fname.c_str(), H5F_ACC_RDONLY, H5P_DEFAULT);
    h5h_read_dset_Nx3(file_id, "/Nodes", m_xco, m_yco, m_zco);
    if (H5Lexists(file_id, "/Sem3D/Hexa8", H5P_DEFAULT)) {
        read_mesh_hexa8(file_id);
    }
    else if (H5Lexists(file_id, "/Sem3D/Hexa27", H5P_DEFAULT)) {
        read_mesh_hexa27(file_id);}
    else{
        printf("ERR: only Quad4 and Quad8 are supported \n");
        exit(1);
    }
    h5h_read_dset_2d(file_id, "/Sem3D/Mat",d0,d1,m_mat);
    for (int i=0; i<d0; i++){
        tag=m_mat[3*d0-i*3-2];
        tagg.push_back(tag);
    }
    for (int i=0; i<d0; i++){
        m_mat[d0-i-1]=tagg[i];
        m_mat.pop_back();
        m_mat.pop_back();
    }
    printf("size new %d",m_mat.size()); 
    std::vector<int> domain=m_mat;
    std::sort( domain.begin(), domain.end() );
    domain.erase( std::unique( domain.begin(), domain.end() ), domain.end() );

    for (int i=0; i< m_mat.size(); i++){
        m_mat[i]=std::distance(domain.begin(), find(domain.begin(),domain.end(),m_mat[i]));}

    if ((H5Lexists(file_id, "/Mesh_quad4/Quad4", H5P_DEFAULT)>0)) {
        read_mesh_Quad8(file_id);}
    else {
        if (domain.size() > m_materials.size()){
            printf("\n\n ERROR: Nb of physical volume in PythonHDF5.h5 is greater than that given in material.input \n");
            exit(1);}
        else if (domain.size() < m_materials.size()){ int mmm=m_materials.size();
            for (int i= domain.size()-1; i < mmm; i++) m_materials.pop_back();}
    }
}

void Mesh3D::read_mesh_hexa8(hid_t file_id)
{
    int nel, nnodes;
    h5h_read_dset_2d(file_id, "/Sem3D/Hexa8", nel, nnodes, m_elems);
    set_control_nodes(8);
    if (nnodes!=8) {
        printf("Error: dataset /Sem/Hexa8 is not of size NEL*8\n");
        exit(1);
    }
    for(int k=0;k<nel;++k) {
        m_elems_offs.push_back(8*(k+1));
    }
}

void Mesh3D::read_mesh_Quad8(hid_t file_id)
{
    int nel, nnodes;
    std::vector<int> m_Quad, elemtrace, m_matQuad;

    set_control_nodes(8);
    h5h_read_dset_2d(file_id, "/Mesh_quad4/Quad4", nel, nnodes,m_Quad);
    if (nnodes!=4) {
        printf("Error: dataset /Mesh_quad4/Quad4 is not of size NEL*4\n");
        exit(1);
    }

  h5h_read_dset(file_id, "/Mesh_quad4/Mat", m_matQuad);
  
  std::vector<int> domain=m_matQuad;
  std::sort( domain.begin(), domain.end() );
  domain.erase( std::unique( domain.begin(), domain.end() ), domain.end() );
  
  for (int i=0; i< m_matQuad.size(); i++){
      m_matQuad[i]=std::distance(domain.begin(), find(domain.begin(),domain.end(),m_matQuad[i]));}

  for (int i=0; i< domain.size(); i++){
       std::ostringstream convert;
       convert << domain[i];
       m_surf_matname.push_back("surface"+convert.str());}
   
  printf("\n");
  printf("Nb surfaces in PythonHDF5.h5 : %d \n\n", m_surf_matname.size());

  elemtrace = m_elems;
  int imat  = m_mat.size();
  int mmm   = imat;
   
  for(int k=0; k< nel; ++k){
     m_elems_offs.push_back(8*(k+1+mmm));     
     std::vector<int> elemneed, elems;
     for(int j=0; j< nnodes; j++) elems.push_back(m_Quad[k*4+j]);
     int elmat=imat+k;
     int tg4nodes=m_matQuad[k]; 
     int el8mat=-1;
     findelem(elmat, elemtrace, elems, elemneed,el8mat);
     m_mat.push_back(m_mat[el8mat]);
      
     for(int j=0; j< elemneed.size(); j++) m_elems.push_back(elemneed[j]);
     surfelem[imat+k] = std::pair<std::pair< std::vector<int>, int >, int > ( std::pair< std::vector<int>, int > (elemneed,m_mat[el8mat]), tg4nodes);
   }
}

void Mesh3D::findelem(int& imat, std::vector<int>& eltr, std::vector<int>& elems, std::vector<int>& elemneed, int &elmat)
{
    bool found=false;
    //std::vector<double> seting_el=m_matseting.find(m_mat[imat])->second;

    for(int i=0; i< eltr.size()/8; i++){
        std::vector<int> elems_i;
        elems_i.clear();
        for(int j=0; j<8; j++) elems_i.push_back(eltr[i*8+j]);
        if (elems_i.size()==8){
            int p=0;
            for (int k=0; k< elems.size(); k++){
                if (std::find(elems_i.begin(),elems_i.end(),elems[k])!=elems_i.end()) {p++;}
            }
            //std::vector<double> seting_i = m_matseting.find(m_mat[i])->second;
            //if ((p==4)&&(seting_i==seting_el)){elemneed = elems_i; found=true; elmat=i;}
            if ((p==4)){elemneed = elems_i; found=true; elmat=i;}
        }
        if (found) break;
    }
    if (!found){
        printf(" Error: Unable to find Hexa8 elem corresponding to Quad4 \n\n");
        elemneed = elems;exit(1);
    }
}

void Mesh3D::read_mesh_hexa27(hid_t file_id)
{
    set_control_nodes(27);
}

void Mesh3D::build_vertex_to_elem_map()
{
    int nel = n_elems();
    m_vertex_to_elem.init(nel);
    m_vertex_domains.clear();
    m_vertex_domains.resize(n_vertices(), 0);
    for(int i=0;i<nel;++i) {
        for(int k=m_elems_offs[i];k<m_elems_offs[i+1];++k) {
            int vtx = m_elems[k];
            int mat = m_mat[i];
            int domain = m_materials[mat].domain();
            m_vertex_to_elem.add_link(vtx, i);
            m_vertex_domains[vtx] |= (1<<domain);

            // Update bounding boxen
            m_bbox[mat].update_bounds(Vec3(m_xco[vtx],m_yco[vtx],m_zco[vtx]));
//            printf("VX[%d] dom=%d/%02x, %02x\n", vtx, domain, (int)(1<<domain), m_vertex_domains[vtx]);
        }
    }
//    for(int k=0;k<n_vertices();++k) {
//        printf("VX[%d] dom=%02x\n", k, m_vertex_domains[k]);
//    }
}

void Mesh3D::build_sf_interface()
{
    PFace fc;
    Surface* sf = get_surface("sf");
    for(int el=0;el<n_elems();++el) {
        int dom0 = get_elem_domain(el);
        for(int k=m_xadj[el];k<m_xadj[el+1];++k) {
            int neighbour = m_adjncy[k];
            int dom1 = get_elem_domain(neighbour);
            // Make sure the face normal points inside fluid or fluidpml domain
            if ((dom0==DM_FLUID && dom1==DM_SOLID) ||
                (dom0==DM_FLUID_PML && dom1==DM_SOLID_PML))
            {
                if (get_common_face(el, neighbour, fc)) {
                    fc.set_domain(dom0);
                    sf->add_face(fc,0);
                    fc.set_domain(dom1);
                    fc.orient = -fc.orient;
                    sf->add_face(fc,0);
                }
            }
            if ((dom1==DM_FLUID && dom0==DM_SOLID) ||
                (dom1==DM_FLUID_PML && dom0==DM_SOLID_PML))
            {
                if (get_common_face(neighbour, el, fc)) {
                    fc.set_domain(dom1);
                    sf->add_face(fc,0);
                    fc.set_domain(dom0);
                    fc.orient = -fc.orient;
                    sf->add_face(fc,0);
                }
            }
        }
    }
}

bool Mesh3D::get_common_face(int e0, int e1, PFace& fc)
{
    int nodes0[8];
    int nodes1[8];
    int face0[4];
    std::set<int> inter;
    get_elem_nodes(e0, nodes0);
    get_elem_nodes(e1, nodes1);
    std::set<int> snodes1(nodes1,nodes1+8);
    // walks faces from e0 and return fc if found in e1 with orientation from e0
    for(int nf=0;nf<6;++nf) {
        for(int p=0;p<4;++p) {
            face0[p] = nodes0[RefFace[nf].v[p]];
        }
        std::set<int> sface0(face0,face0+4);
        inter.clear();
        std::set_intersection(sface0.begin(),sface0.end(),snodes1.begin(),snodes1.end(),
                              std::inserter(inter,inter.begin()));
        if (inter.size()==4) {
            fc.set_face(face0);
            return true;
        }
    }
    return false;
}

void Mesh3D::get_neighbour_elements(int nn, const int* n, std::set<int>& elemset) const
{
    std::set<int> elems, temp;
    m_vertex_to_elem.vertex_to_elements(n[0], elemset);
    for(int k=1;k<nn;++k) {
        int vertex_id = n[k];
        elems.clear();
        temp.clear();
        m_vertex_to_elem.vertex_to_elements(n[k], elems);
        std::set_intersection(elemset.begin(), elemset.end(),
                              elems.begin(), elems.end(),
                              std::inserter(temp, temp.begin()));
        elemset.swap(temp);
    }
}

void Mesh3D::save_bbox()
{
    FILE* fbbox;
    double tol_x, tol_y, tol_z;
    fbbox = fopen("domains.txt", "w");
    map<int,AABB>::const_iterator bbox;
    for(bbox=m_bbox.begin();bbox!=m_bbox.end();++bbox) {
        //fprintf(fbbox, "%3d %8.3g %8.3g %8.3g %8.3g %8.3g %8.3g\n", bbox->first,
        tol_x = (bbox->second.max[0] - bbox->second.min[0])/100.0;
        tol_y = (bbox->second.max[1] - bbox->second.min[1])/100.0;
        tol_z = (bbox->second.max[2] - bbox->second.min[2])/100.0;
        fprintf(fbbox, "%6d %15.6f %15.6f %15.6f %15.6f %15.6f %15.6f %6d\n", bbox->first,
                bbox->second.min[0]-tol_x,
                bbox->second.min[1]-tol_y,
                bbox->second.min[2]-tol_z,
                bbox->second.max[0]+tol_x,
                bbox->second.max[1]+tol_y,
                bbox->second.max[2]+tol_z,
                bbox->first);
                //bbox->second.assocMat);
    }
}

void Mesh3D::generate_output(int nprocs)
{
    build_vertex_to_elem_map();
    save_bbox();
    partition_mesh(nprocs);
    // partition_mesh builds adjacency map that is used by build_sf_interface
    // Later on, we will want to treat SF interfaces like all others.
    // That is when we will be able to generate normals for all surfaces
    // build_sf_interface();

    for(int part=0;part<nprocs;++part) {
	Mesh3DPart loc(*this, part);

	loc.compute_part();
	loc.output_mesh_part();
	loc.output_mesh_part_xmf();
    }
    output_all_meshes_xmf(nprocs);
}


/* Local Variables:                                                        */
/* mode: c++                                                               */
/* show-trailing-whitespace: t                                             */
/* coding: utf-8                                                           */
/* c-file-style: "stroustrup"                                              */
/* End:                                                                    */
/* vim: set sw=4 ts=8 et tw=80 smartindent :                               */
