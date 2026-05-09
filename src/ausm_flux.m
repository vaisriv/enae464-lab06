% ausm_flux.m
function [fluxjp] = ausm_flux(gamma,area,rho,u,p,e)

    m=length(rho);
	speed = sqrt(gamma*p./rho);
    mach = u./speed;
% Determine split Mach and pressure
    for j=1:m
        if(abs(mach(j))<=1.)
            machp(j) = +0.25*(mach(j)+1)^2*area(j);
            machn(j) = -0.25*(mach(j)-1)^2*area(j);
%            pp(j) = +0.25*p(j)*(mach(j)+1)^2*(2-mach(j))*area(j);
%            pn(j) = +0.25*p(j)*(mach(j)-1)^2*(2+mach(j))*area(j);
            pp(j) = +0.5*p(j)*(1+mach(j))*area(j);
            pn(j) = +0.5*p(j)*(1-mach(j))*area(j);
        else
            machp(j) = 0.5*(mach(j)+abs(mach(j)))*area(j);
            machn(j) = 0.5*(mach(j)-abs(mach(j)))*area(j);
            pp(j) = 0.5*p(j)*(mach(j)+abs(mach(j)))/mach(j)*area(j);
            pn(j) = 0.5*p(j)*(mach(j)-abs(mach(j)))/mach(j)*area(j);        
        end
    end
% Convective flux at j+1/2 + pressure flux at j+1/2
    for j=1:m-1
        machjp(j) = machp(j)+machn(j+1);
        if (machjp(j)>=0.)
            fluxjp(1,j) = machjp(j)*rho(j)*speed(j);
            fluxjp(2,j) = machjp(j)*rho(j)*u(j)*speed(j);
            fluxjp(3,j) = machjp(j)*(e(j)+p(j))*speed(j);
        else
            fluxjp(1,j) = machjp(j)*rho(j+1)*speed(j+1);
            fluxjp(2,j) = machjp(j)*rho(j+1)*u(j+1)*speed(j+1);
            fluxjp(3,j) = machjp(j)*(e(j+1)+p(j+1))*speed(j+1);
        end
        fluxjp(2,j) = fluxjp(2,j) + (pp(j) + pn(j+1));
    end
end

