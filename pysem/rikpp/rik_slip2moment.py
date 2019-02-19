# -*- coding: utf-8 -*-
#!/usr/bin/env python
"""
Main file to convert RIK output into SEM3D input
"""

#=======================================================================
# Required modules
#=======================================================================
import os
import numpy as np
import h5py
from matplotlib import pyplot as plt
import seaborn as sns
import rik_pp_lib as rp
from scipy.integrate import cumtrapz
#=======================================================================
# General informations
#=======================================================================
__author__ = "Filippo Gatti"
__copyright__ = "Copyright 2018, MSSMat UMR CNRS 8579 - CentraleSupélec"
__credits__ = ["Filippo Gatti"]
__license__ = "GPL"
__version__ = "1.0.1"
__maintainer__ = "Filippo Gatti"
__email__ = "filippo.gatti@centralesupelec.fr"
__status__ = "Beta"

class SEM_source(object):
    def __init__(self,e=0.,n=0.,z=0.):
        self.e = e
        self.n = n
        self.z = z
    def __call__(self,e=0.,n=0.,z=0.):
        self.e = e
        self.n = n
        self.z = z
    def get_hypo(self):
        return np.array([self.e,self.n,self.z])

class RIK_source(object):
    def __init__(self,x=0.,y=0.,z=0.,hypfile=None):
        self.x = x
        self.y = y
        self.z = z
        if hypfile:
            self.read_hypo(hypfile)
    def __call__(self,x=0.,y=0.,z=0.):
        self.x = x
        self.y = y
        self.z = z
        if hypfile:
            self.read_hypo(hypfile)
    def read_hypo(self,hypfile):
        self.x, self.y = rp.readhypo(hypfile)
    def get_hypo(self):
        return np.array([self.x,self.y,self.z])

if __name__=='__main__':
    fld = '/home/filippo/Data/Filippo/ares/workdir/RIK/napa_2014/results'
    plot_figure     = True
    figurename = 'napa_2014_moment_vs_time.png'

    # Saving point-coordinates in file ...?
    coord_file_name = 'source_coordinates.csv'

    # Input files 
    RIK_slipfile = os.path.join(fld, 'slipdistribution.dat')
    mrfile = os.path.join(fld, 'MomentRate.dat')
    hypfile = os.path.join(fld,'nucleationpoint.dat')

    NT = 480
    dt = 0.025
    T_total = (NT-1)*dt
    time = np.linspace(0.0, T_total, NT)
    # Nombre de points de grille (toute la grille si different 
    # que strong-motion generation area)
    NL = 150 #210
    NW = 100 #170

    # Les angles 
    strike = 38#35.0
    dip    = 63#35.0
    rake   = 172#-172.0
    # Les angles en radian
    aS    = np.pi/180.0* strike
    aR    = np.pi/180.0* rake
    aD    = np.pi/180.0* dip
    # Rotation matrix
    print 'Rotation matrix: '
    MatMesh = rp.get_rotation_tensor(aS, aD)

    src_sem = SEM_source(e=2.2754e+06,n=4.2421e+06,z=-10.0e+3)
    # Lire les coordonnees de l'hypocentre (point de nucleation)
    src_rik = RIK_source(hypfile=hypfile)
    src_rik(z=10.e+3)
    # On suppose que l'hypocentre est  (en metres)
    RIK_hypocenter = src_rik.get_hypo()  # Y_RIK, X_RIK, DEPTH(DOWNWARD)
    SEM_hypocenter = src_sem.get_hypo()  # EST,   NORD,  UPWARD

    MR = rp.read_moment_rate_RIK (mrfile, (int(NL), int(NW), int(NT)))

    # Creation des fichiers d'entree pour SEM
    kinefile_out  = h5py.File('napa2014_kine.hdf5', 'w')
    slipfile_out  = h5py.File('napa2014_moment.hdf5','w')
    # Attribuer les proprietes temporelles
    kinefile_out.attrs['Nt'] = NT
    kinefile_out.attrs['dt'] = time[1]-time[0]
    kinefile_out.attrs['Ns'] = NL 
    kinefile_out.attrs['Nd'] = NW

    # Vecteurs du normale et du slip
    rp.vecteurs(aD,aS,aR,kinefile_out)

    # Coordonnees des points dans le repere SEM3D
    xgrid = kinefile_out.create_dataset('x', (NL, NW), chunks=(1, 1))
    ygrid = kinefile_out.create_dataset('y', (NL, NW), chunks=(1, 1))
    depth = kinefile_out.create_dataset('z', (NL, NW), chunks=(1, 1))

    xgrid[:,:] = 0.0
    ygrid[:,:] = 0.0
    depth[:,:] = 0.0

    # x,y koordinatlari (RIK) - metre
    print '*********'
    print 'Hypocenter of RIK model:'
    print RIK_hypocenter[0], RIK_hypocenter[1], RIK_hypocenter[2]
    print 'Hypocenter of SEM model:'
    print SEM_hypocenter[0], SEM_hypocenter[1], SEM_hypocenter[2]
    # RIK model - Les coordonnees de x et y
    RIK_xcoord = np.genfromtxt(RIK_slipfile, usecols=1)  # Y_RIK
    RIK_ycoord = np.genfromtxt(RIK_slipfile, usecols=0)  # X_RIK

    # Creer le matrice hdf5 pour le temps
    slipfile_out.create_dataset('time', data=time)

    # Creer le matrice hdf5 pour le moment
    Moment = slipfile_out.create_dataset('moment', (NL, NW, NT), chunks=(1, 1, NT))

    # Integration pour calculer le moment
    print 'INTEGRATION'
    n = 0
    for i in range(0, NL):
        for j in range(0, NW):
            n = n+ 1
            Moment[i,j,:] = cumtrapz(MR[i,j,:],dx=dt,initial=0.) #
            print NT, dt, '  --->  Point ', n

    print 'Total point number in fault plane: ', NL*NW
    n = 0
    for j in np.arange(NW):
        for i in np.arange(NL):
            # en kilometres
            if (NL*NW > 1):
                xgrid[i,j] = RIK_xcoord[n]
                ygrid[i,j] = RIK_ycoord[n]
            else:
                print 'ATTENTION: CHANGE THIS FOR MODELS WITH MORE THAN 1 POINT'
                xgrid[i,j] = RIK_xcoord
                ygrid[i,j] = RIK_ycoord
            depth[i,j] = (RIK_hypocenter[2]/1e3+ np.sin(aD)* (RIK_hypocenter[0]/1e3-xgrid[i,j]))

            # en metres
            xgrid[i,j] = xgrid[i,j]* 1e3
            ygrid[i,j] = ygrid[i,j]* 1e3
            depth[i,j] = depth[i,j]* 1e3

            n = n+1
    # ATTENTION: Once rotate edip sonra farkina bakiyorum
    fark  = np.dot(MatMesh,RIK_hypocenter)
    fark  = (SEM_hypocenter-fark)

    print 'fark', fark
    # Opening file to save SEM3D coordinates of grid points
    coord_file = open (coord_file_name, 'w+')
    # Burada rotation yapiyorum
    n = 0
    dx_plane = xgrid[0,1]-xgrid[0,0]
    dy_plane = ygrid[1,0]-ygrid[0,0]
    dz_plane = depth[0,1]-depth[0,0]
    print('dx-dy-dz plane')
    print(dx_plane,dy_plane,dz_plane)
    dx_rot = np.dot(MatMesh,np.array([dx_plane,dy_plane,dz_plane]))
    print('dx-dy-dz rot')
    print(dx_rot[0],dx_rot[1],dx_rot[2])
    coord_file.write('{:>10},{:>15},{:>15},{:>15}\n'.format('N','X','Y','Z'))
    for j in np.arange(NW):
        for i in np.arange(NL):
            n = n+ 1
            print 'Point ',n,	
            # Rotasyon uyguluyorum
            coord = np.array([xgrid[i,j], ygrid[i,j], depth[i,j]])
            dum   = np.dot(MatMesh,coord)

            # Aradaki farki ekliyorum; boylelikle translate ediyor
            xgrid[i,j] = dum[0]+ fark[0]
            ygrid[i,j] = dum[1]+ fark[1]
            depth[i,j] = dum[2]+ fark[2]

            # Writing out the cordinates
            coord_file.write('{:>10d},{:>15.5f},{:>15.5f},{:>15.5f}\n'.format(\
                n,xgrid[i,j],ygrid[i,j],depth[i,j]))
            print '***'
    coord_file.close()
    exit()

    if plot_figure:
        ### PLOTTING ###
        fig = plt.figure(figsize=(12,10))
        sns.set_style('whitegrid')
        ax  = fig.add_subplot(111)

        # ax.set_xlim([0,1])
        # #
        for i in range(0, NL):
            for j in range(0, NW):
                ax.plot(time, Moment[i,j,:], label='Point '+str(i+1),color='Gray')
        # #
        ax.set_xlabel('Time [s]'    ,fontsize=20)
        ax.set_ylabel('Moment [Nm]' ,fontsize=20)
        # ax.legend()
        plt.show()
        fig.savefig(figurename,dpi=300)

    # Fermeture des fichiers hdf5
    kinefile_out.close()
    slipfile_out.close()