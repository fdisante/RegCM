!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!
!    This file is part of ICTP RegCM.
!
!    ICTP RegCM is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    ICTP RegCM is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with ICTP RegCM.  If not, see <http://www.gnu.org/licenses/>.
!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

module mod_zita

  use mod_realkinds
  use mod_intkinds
  use mod_constants
  use mod_dynparam , only : mo_a0 , mo_b0 , mo_ztop , mo_mfac

  implicit none

  private

  real(rkx) , parameter :: t0 = stdt
  real(rkx) , parameter :: hzita = rgas*t0*regrav

  interface zita_interp
    module procedure zh3d
    module procedure zh4d
  end interface zita_interp

  public :: model_dz
  public :: md_zeta , md_zeta_h , md_fmz , md_fmz_h , md_hzita , md_zfz
  public :: gzita
  public :: zita_interp

  contains

  pure real(rkx) function model_dz(kz)
    implicit none
    integer(ik4) , intent(in) :: kz
    model_dz = mo_mfac*mo_ztop/real(kz,rkx)
  end function model_dz

  pure real(rkx) function md_hzita( )
    implicit none
    md_hzita = hzita * (1.0_rkx - mo_b0)
  end function md_hzita

  pure real(rkx) function md_zfz( )
    implicit none
    md_zfz = mo_ztop/(exp(mo_ztop/md_hzita())-1.0_rkx)
  end function md_zfz

  ! Decay function
  pure real(rkx) elemental function gzita(zita)
    implicit none
    real(rkx) , intent(in) :: zita
    real(rkx) :: ratio
    ratio = zita/mo_ztop
    gzita = 1.0_rkx - mo_a0 * ratio - &
            (3.0_rkx - 2.0_rkx * mo_a0) * ratio**2 + &
            (2.0_rkx - mo_a0) * ratio**3
  end function gzita

  ! Derivative of decay function
  pure real(rkx) elemental function gzitap(zita)
    implicit none
    real(rkx) , intent(in) :: zita
    real(rkx) :: ratio
    ratio = zita/mo_ztop
    gzitap = (-mo_a0 - (6.0_rkx - 4.0_rkx * mo_a0) * ratio + &
                       (6.0_rkx - 3.0_rkx * mo_a0) * ratio**2)/mo_ztop
  end function gzitap

  pure real(rkx) function md_fmz(zita,geopot)
    implicit none
    real(rkx) , intent(in) :: zita , geopot
    md_fmz = md_fmz_h(zita,geopot*regrav)
  end function md_fmz

  ! Factor used to transform the vertical derivatives in zeta
  pure real(rkx) function md_fmz_h(zita,orog)
    implicit none
    real(rkx) , intent(in) :: zita , orog
    ! Equation 9
    md_fmz_h = 1.0_rkx/(gzitap(zita)*orog + &
                md_zfz()/md_hzita()*exp(zita/md_hzita()))
  end function md_fmz_h

  ! Elevation above orography as function of zita
  pure real(rkx) function md_zeta(zita,geopot)
    implicit none
    real(rkx) , intent(in) :: zita , geopot
    md_zeta = md_zeta_h(zita,geopot*regrav)
  end function md_zeta

  ! Elevation above orography as function of zita
  pure real(rkx) function md_zeta_h(zita,orog)
    implicit none
    real(rkx) , intent(in) :: zita , orog
    ! Equation 7 with removal of orography and check for negatives
    md_zeta_h = max((orog*gzita(zita) + &
                    md_zfz()*(exp(zita/md_hzita())-1.0_rkx))-orog, 0.0_rkx)
  end function md_zeta_h

  subroutine zh3d(nx1,nx2,ny1,ny2,nz,f,zeta,tvirt,sigmah,ps,imet)
    implicit none
    integer(ik4) , intent(in) :: nx1 , nx2 , ny1 , ny2 , nz , imet
    real(rkx) , dimension(:,:,:) , pointer , intent(inout) :: f
    real(rkx) , dimension(:,:,:) , pointer , intent(in) :: zeta
    real(rkx) , dimension(:,:,:) , pointer , intent(in) :: tvirt
    real(rkx) , dimension(:) , pointer , intent(in) :: sigmah
    real(rkx) , dimension(:,:) , pointer , intent(in) :: ps
    real(rkx) , dimension(nz) :: psigma , pz
    real(rkx) , dimension(nz) :: fz
    integer(ik4) :: i , j , k , kk , ik
    real(rkx) :: iw1 , iw2
    if ( imet == 1 ) then
      do j = ny1 , ny2
        do i = nx1 , nx2
          psigma = ps(i,j) * sigmah
          pz = ps(i,j)*exp(-egrav*zeta(i,j,:)/rgas/tvirt(i,j,:))
          do k = 1 , nz
            if ( pz(k) < psigma(1) ) then
              fz(k) = f(i,j,1)
            else if ( pz(k) > psigma(nz) ) then
              fz(k) = f(i,j,nz)
            else
              ! Find requested pressure level
              ik = 1
              do kk = 2 , nz
                if ( pz(k) < psigma(kk) ) then
                  ik = kk
                  exit
                end if
              end do
              iw1 = log(pz(k)/psigma(ik-1))/log(psigma(ik)/psigma(ik-1))
              iw2 = 1.0_rkx - iw1
              fz(k) = iw1 * f(i,j,ik) + iw2 * f(i,j,ik-1)
            end if
          end do
          f(i,j,:) = fz
        end do
      end do
    else
      do j = ny1 , ny2
        do i = nx1 , nx2
          psigma = ps(i,j) * sigmah
          pz = ps(i,j)*exp(-egrav*zeta(i,j,:)/rgas/tvirt(i,j,:))
          do k = 1 , nz
            if ( pz(k) < psigma(1) ) then
              fz(k) = f(i,j,1)
            else if ( pz(k) > psigma(nz) ) then
              fz(k) = f(i,j,nz)
            else
              ! Find requested pressure level
              ik = 1
              do kk = 2 , nz
                if ( pz(k) < psigma(kk) ) then
                  ik = kk
                  exit
                end if
              end do
              iw1 = (pz(k)/psigma(ik-1))/(psigma(ik)/psigma(ik-1))
              iw2 = 1.0_rkx - iw1
              fz(k) = iw1 * f(i,j,ik) + iw2 * f(i,j,ik-1)
            end if
          end do
          f(i,j,:) = fz
        end do
      end do
    end if
  end subroutine zh3d

  subroutine zh4d(nx1,nx2,ny1,ny2,nz,nn,f,zeta,tvirt,sigmah,ps,imet)
    implicit none
    integer(ik4) , intent(in) :: nx1 , nx2 , ny1 , ny2 , nz , nn , imet
    real(rkx) , dimension(:,:,:,:) , pointer , intent(inout) :: f
    real(rkx) , dimension(:,:,:) , pointer , intent(in) :: zeta
    real(rkx) , dimension(:,:,:) , pointer , intent(in) :: tvirt
    real(rkx) , dimension(:) , pointer , intent(in) :: sigmah
    real(rkx) , dimension(:,:) , pointer , intent(in) :: ps
    real(rkx) , dimension(nz) :: psigma , pz
    real(rkx) , dimension(nz) :: fz
    integer(ik4) :: i , j , k , n , kk , ik
    real(rkx) :: iw1 , iw2
    if ( imet == 1 ) then
      do n = 1 , nn
        do j = ny1 , ny2
          do i = nx1 , nx2
            psigma = ps(i,j) * sigmah
            pz = ps(i,j)*exp(-egrav*zeta(i,j,:)/rgas/tvirt(i,j,:))
            do k = 1 , nz
              if ( pz(k) < psigma(1) ) then
                fz(k) = f(i,j,1,n)
              else if ( pz(k) > psigma(nz) ) then
                fz(k) = f(i,j,nz,n)
              else
                ! Find requested pressure level
                ik = 1
                do kk = 2 , nz
                  if ( pz(k) < psigma(kk) ) then
                    ik = kk
                    exit
                  end if
                end do
                iw1 = log(pz(k)/psigma(ik-1))/log(psigma(ik)/psigma(ik-1))
                iw2 = 1.0_rkx - iw1
                fz(k) = iw1 * f(i,j,ik,n) + iw2 * f(i,j,ik-1,n)
              end if
            end do
            f(i,j,:,n) = fz
          end do
        end do
      end do
    else
      do n = 1 , nn
        do j = ny1 , ny2
          do i = nx1 , nx2
            psigma = ps(i,j) * sigmah
            pz = ps(i,j)*exp(-egrav*zeta(i,j,:)/rgas/tvirt(i,j,:))
            do k = 1 , nz
              if ( pz(k) < psigma(1) ) then
                fz(k) = f(i,j,1,n)
              else if ( pz(k) > psigma(nz) ) then
                fz(k) = f(i,j,nz,n)
              else
                ! Find requested pressure level
                ik = 1
                do kk = 2 , nz
                  if ( pz(k) < psigma(kk) ) then
                    ik = kk
                    exit
                  end if
                end do
                iw1 = (pz(k)/psigma(ik-1))/(psigma(ik)/psigma(ik-1))
                iw2 = 1.0_rkx - iw1
                fz(k) = iw1 * f(i,j,ik,n) + iw2 * f(i,j,ik-1,n)
              end if
            end do
            f(i,j,:,n) = fz
          end do
        end do
      end do
    end if
  end subroutine zh4d

end module mod_zita

! vim: tabstop=8 expandtab shiftwidth=2 softtabstop=2
