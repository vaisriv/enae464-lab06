% vanl_flux.m
%
function [fluxp,fluxn] = vanl_flux(gamma,area,rho,u,p,e)

    m=length(rho);
    gamm1 = gamma-1;
	speed = sqrt(gamma*p./rho);
	amach = u./speed;
	alam1 = u;
	alam2 = u+speed;
	alam3 = u-speed;
	for j=1:m
	 if(u(j) < speed(j))
	  alam1(j) = 0.25*speed(j)*(amach(j)+1)^2*(1-(amach(j)-1)^2/(gamma+1));
	  alam2(j) = 0.25*speed(j)*(amach(j)+1)^2*(3-amach(j)+gamm1*(amach(j)-1)^2/(gamma+1));
	  alam3(j) = 0.5*speed(j)/(gamma+1)*(amach(j)+1)^2*(amach(j)-1)*...
	                        (1+0.5*gamm1*amach(j));
	 end
	end
	fac = rho*0.5/gamma.*area;
	fluxp(1,:) = fac.*( 2.*gamm1*alam1+alam2+alam3 );
	fluxp(2,:) = fac.*( 2.*gamm1*u.*alam1+alam2.*(u+speed)+alam3.*(u-speed) );
	fluxp(3,:) = fac.*( gamm1*u.^2.*alam1+0.5*alam2.*(u+speed).^2+0.5*alam3.*(u-speed).^2 + ...
	                0.5*(3-gamma)/gamm1*(alam2+alam3).*speed.^2 );
	fluxn(1,:) = rho.*u.*area-fluxp(1,:);
	fluxn(2,:) = (rho.*u.^2+p).*area-fluxp(2,:);
	fluxn(3,:) = (e+p).*u.*area-fluxp(3,:);
end

