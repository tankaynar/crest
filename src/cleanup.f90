!================================================================================!
! This file is part of crest.
!
! Copyright (C) 2018-2020 Philipp Pracht
!
! crest is free software: you can redistribute it and/or modify it under
! the terms of the GNU Lesser General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! crest is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU Lesser General Public License for more details.
!
! You should have received a copy of the GNU Lesser General Public License
! along with crest.  If not, see <https://www.gnu.org/licenses/>.
!================================================================================!

!CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
!C
!C All subroutines related to removing stuff
!C
!C  system calls are the easiest way to remove files, although they introduce
!C  an additional dependence on the operating system.
!C  But since there are no simple kernel alternatives to do the same thing
!C  I will keep them for now.
!C
!CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

!-------------------------------------------------------------------------
! Basic subroutine for removing files or directories
!-------------------------------------------------------------------------
subroutine rmrf(dataname)
  use iomod, only: remove_tree
  implicit none
  character(len=*) :: dataname
  character(len=len_trim(dataname)) :: one
  integer :: start,space
  !> callers pass several names separated by spaces, as "rm -rf" takes them
  start = 1
  do while (start <= len_trim(dataname))
    space = index(dataname(start:),' ')
    if (space == 0) space = len_trim(dataname(start:))+1
    one = dataname(start:start+space-2)
    if (len_trim(one) > 0) call remove_tree(trim(one))
    start = start+space
  end do
  return
end subroutine rmrf
!-------------------------------------------------------------------------
! Rename a file, replacing "to" if it exists, as POSIX rename() does.
! Windows' rename() refuses an existing target, and CREST relies on
! overwriting (it touches an output file, then renames the result onto it).
!-------------------------------------------------------------------------
subroutine rename_file(from,to)
  implicit none
  character(len=*) :: from,to
  logical :: have_from,have_to
  integer :: ich,io
  if (trim(from) == trim(to)) return
  inquire (file=trim(from),exist=have_from)
  inquire (file=trim(to),exist=have_to)
  if (have_from.and.have_to) then
    open (newunit=ich,file=trim(to),iostat=io)
    if (io == 0) close (ich,status='delete')
  end if
  call rename(trim(from),trim(to))
end subroutine rename_file
!-------------------------------------------------------------------------
! Basic subroutine for removing files or directories (with wild card ending)
!-------------------------------------------------------------------------
subroutine rmrfw(dataname)
  implicit none
  character(len=*) :: dataname
  call rmrf(trim(dataname)//'*')
  return
end subroutine rmrfw

!CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
!C Specific cleanup routines for different parts of the CREST code
!CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

subroutine custom_cleanup(env)
   use crest_data
   use iomod
   implicit none
   type(systemdata) :: env
   integer :: i
   if(.not.env%keepModef)then
    call rmrfw('METADYN')
    call rmrfw('NORMMD')
    call rmrf('MRMSD')
    call rmrf('TRIALMD')
    call rmrf('TRIALOPT')
    call rmrf('MDFILES')
    call rmrf('OPTIM')
    call rmrf('PROP')
    call rmrfw('.cre_')
    call rmrf('cregen_*.tmp')
    call rmrf('MDFILES')
    if(allocated(env%calc%calcs))then
    if(.not.any(env%calc%calcs(:)%pr))then
      call rmrfw('calculation.level.')
    endif
    endif
   endif
   call rmrf('.CHRG .UHF')
   call rmrf('.history.xyz')
end subroutine custom_cleanup


!-------------------------------------------------------------------------
! General cleanup function. Wipes most files that may be written by crest
!-------------------------------------------------------------------------
subroutine V2cleanup(restartopt)
  use iomod
  use crest_data
  implicit none
  logical :: restartopt
  character(len=12),parameter :: pipe = ' 2>/dev/null'

  call rmrf('.tmpxtbmodef hessian .xtboptok')
  call rmrf('xtbrestart xtbmdok')
  if (.not.restartopt) then
    call rmrfw('METADYN')
    call rmrfw('NORMMD')
    call rmrf('MRMSD')
    call rmrf('TRIALMD')
    call rmrf('MDFILES')
    call rmrf('OPTIM')
    call rmrf('PROP')
    call rmrf('crest_best.xyz')
    call rmrf(conformerfile)
    call rmrfw(crefile)
    call rmrfw('.cre_')
    call rmrf('cregen_*.tmp')
  else
    call rmrfw('NORMMD')
    call rename_file(crefile//'_0.xyz','.tmp_full.xyz')
    call rmrfw(crefile)
    call rename_file('.tmp_full.xyz',crefile//'_0.xyz')
  end if
  return
end subroutine V2cleanup

!-------------------------------------------------------------------------
! Cleanup function for MTD and MD dirs (confscript2_misc.f90)
!-------------------------------------------------------------------------
subroutine cleanMTD
  implicit none
  call rmrfw('METADYN')
  call rmrfw('NORM')
  call rmrfw('STATICMTD')
  call rmrf('MRMSD')
  call rmrf('TRIALMD')
  call rmrf('MDFILES')
  return
end subroutine cleanMTD

!------------------------------------------------------------------------
! last bit of file removing and renaming (confscript2_misc.f90)
!------------------------------------------------------------------------
subroutine V2terminating
  use iomod
  use utilities
  use crest_data
  implicit none
  character(len=256) :: inpnam,outnam
  call remove('scoord.1')
  call catdel('cregen.out.tmp') !print to screen
  call checkname_xyz(crefile,inpnam,outnam)
  call rename_file(inpnam,"crest_rotamers.xyz")
  call rmrfw('crest_rotamers_')
  call rmrfw('crest_smtd_')
  return
end subroutine V2terminating

!------------------------------------------------------------------------
! clean Dir between iterations (confscript2_misc.f90)
!------------------------------------------------------------------------
subroutine clean_V2i
  use iomod
  use crest_data
  implicit none
  call rmrfw('METADYN')
  call rmrfw('NORM')
  call rmrfw('STATICMTD')
  call rmrfw('MDFILES')
  call rmrfw(crefile)
  return
end subroutine clean_V2i

!-----------------------------------------------------------------------
! Remove all crest_conformers and crest_rotamers files (confscript2_misc.f90)
!-----------------------------------------------------------------------
subroutine rmcres()
  use crest_data
  implicit none
  call rmrfw(crefile)
  call rmrf(conformerfile)
  return
end subroutine rmcres

!-----------------------------------------------------------------------
! Remove the OPTIM dir and scoord files (confscript2_misc.f90)
!-----------------------------------------------------------------------
subroutine rmoptim()
  implicit none
  call rmrf('OPTIM')
  call rmrfw('scoord.')
  return
end subroutine rmoptim

!-----------------------------------------------------------------------
! Cleanup options for SCREEN mode (confscript3.f90)
!-----------------------------------------------------------------------
subroutine screen_cleanup
  use crest_data
  implicit none
  call rmrf('OPTIM')
  call rmrf('scoord.1')
  call rmrf(conformerfile)
  call rmrfw(crefile)
  return
end subroutine screen_cleanup

!-----------------------------------------------------------------------
! Cleanup routine for xtb files
!-----------------------------------------------------------------------
subroutine xtbclean
  implicit none
  call rmrf('xtbrestart xtbtopo.mol xtbopt.log xtbopt.xyz')
  call rmrf('charges wbo')
  call rmrf('gfnff_topo gfnff_adjacency gfnff_topo')
  return
end subroutine xtbclean

!-----------------------------------------------------------------------
! Cleanup routine for protonation tool (protonate.f90)
!-----------------------------------------------------------------------
subroutine protclean
  implicit none
  call rmrf('xtblmoinfo coordprot.0 lmocent.coord')
  call rmrf('protonate_*.xyz xtbscreen.xyz protonated.xyz')
  return
end subroutine protclean

!-----------------------------------------------------------------------
! Cleanup routine for deprotonation tool (deprotonate.f90)
!-----------------------------------------------------------------------
subroutine deprotclean
  implicit none
  call rmrf('xtblmoinfo coordprot.0 lmocent.coord')
  call rmrf('deprotonate_*.xyz xtbscreen.xyz')
  return
end subroutine deprotclean

!-----------------------------------------------------------------------
! Cleanup routine for tautomerization (tautomerize.f90)
!-----------------------------------------------------------------------
subroutine tautclean
  implicit none
  call rmrf('xtblmoinfo coordprot.0 lmocent.coord')
  call rmrf('protonate_*.xyz deprotonate_*.xyz')
  call rmrf('tautomerize_*.xyz tautomers.xyz xtbscreen.xyz')
  return
end subroutine tautclean
subroutine tautclean2
  implicit none
  call rmrf('xtblmoinfo coordprot.0 lmocent.coord')
  call rmrf('protonate_*.xyz deprotonate_*.xyz')
  call rmrf('protonated.xyz deprotonated.xyz xtbscreen.xyz')
  return
end subroutine tautclean2

!-----------------------------------------------------------------------
! Cleanup routine for MF-MD-GC (confscript1.f90)
!-----------------------------------------------------------------------
subroutine clean
  use crest_data
  implicit none
  call rmrfw('MODEF')
  call rmrfw('NORMMD')
  call rmrfw('TMPCONF')
  call rmrfw(crefile)
  return
end subroutine clean

!-----------------------------------------------------------------------
! change the dir and then remove mos and dh (dft_propcalc.f90)
!-----------------------------------------------------------------------
subroutine cleanDFT(TMPCONF)
  use iomod, only: command
  implicit none
  integer :: TMPCONF
  character(len=:),allocatable :: str
  character(len=:),allocatable :: pipe
  character(len=10) :: nmmr
  integer :: i,io
  do i = 1,TMPCONF
    write (nmmr,'(i0)') i
    call rmrf('TMPCONF'//trim(nmmr)//'/mos')
    call rmrf('TMPCONF'//trim(nmmr)//'/dh')
  end do
  return
end subroutine cleanDFT

