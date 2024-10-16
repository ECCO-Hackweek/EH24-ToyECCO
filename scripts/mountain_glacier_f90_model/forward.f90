module forward

implicit none
     real(8), parameter :: xend = 30
     real(8), parameter :: dx = 1
     integer, parameter :: nx = int(xend/dx)


contains

     subroutine forward_problem(xx,V)

             implicit none

             real(8), parameter :: rho = 920.0
             real(8), parameter :: g = 9.2
             real(8), parameter :: n = 3
             real(8), parameter :: A = 1e-16
             real(8), parameter :: dt = 1/12.0
             real(8), parameter :: C = 2*A/(n+2)*(rho*g)**n*(1.e3)**n
             real(8), parameter :: tend = 5000
             real(8), parameter :: bx = -0.0001
             real(8), parameter :: M0 = .004, M1 = 0.0002
             integer, parameter :: nt = int(tend/dt)
             real(8), dimension(nx+1,nt+1) :: h
             real(8), dimension(nx+1,nt+1) :: h_capital
             integer :: t,i
             real(8), dimension(nx+1) :: xarr
             real(8), dimension(nx+1) :: M
             real(8), dimension(nx+1) :: b
             real(8), dimension(nx) :: D, phi
             real(8), intent(in), dimension(nx+1) :: xx
             real(8), intent(out) :: V

             xarr = (/ ((i-1)*dx, i=1,nx+1) /)
             M = (/ (M0-(i-1)*dx*M1, i=1,nx+1) /)
             b = (/ (1.0+bx*(i-1)*dx, i=1,nx+1) /)
             M = M + xx
             h(1,:) = b(1)
             h(:,1) = b
             h(nx+1,:) = b(nx+1)
             h_capital(1,:) = h(1,:) - b(1)
             h_capital(nx+1,:) = h(nx+1,:) - b(nx+1)
             h_capital(:,1) = h(:,1) - b

             do t = 1,nt
                     D(:) = C * ((h_capital(1:nx,t)+h_capital(2:nx+1,t))/2)**(n+2) * ((h(2:nx+1,t) - h(1:nx,t))/dx)**(n-1)
                     phi(:) = -D(:)*(h(2:nx+1,t)-h(1:nx,t))/dx
                     h(2:nx,t+1) = h(2:nx,t) + M(2:nx)*dt - dt/dx * (phi(2:nx)-phi(1:nx-1))

                     where (h(:,t+1) < b)
                             h(:,t+1) = b
                     end where

                     h_capital(:,t+1) = h(:,t+1) - b

             end do

             V = 0.


             open (unit = 2, file = "results_forward_run.txt", action="write",status="replace")
             write(2,*) "         #                H                h                  b"
             write(2,*) "_______________________________________________________________________________"

             do i = 1, size(h_capital(:,nt+1))
                  V = V + h_capital(i,nt+1)*dx

                  write(2,*) i, "    ", h_capital(i,nt+1), "    ", h(i,nt+1), "    ", b(i)
             end do




     close(2)
     end subroutine forward_problem

end module forward
