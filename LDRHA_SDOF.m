function [u,ut,utt,f] = LDRHA_SDOF(k,m,dt,xgtt,ksi,AlgID,u0,ut0,rinf)
%
% Linear Dynamic Response History Analysis (FLDRHA) of a SDOF system
%
% [U,UT,UTT,F] = LDRHA_SDOF(K,M,DT,XGTT,KSI,ALGID,U0,UT0,RINF)
%
% Description
%     Linear direct time integration of second order differential
%     equation of motion of dynamic response of linear elastic Single DOF
%     systems. The General Single Step Single Solve (GSSSS) family of
%     algorithms published by X.Zhou & K.K.Tamma (2004) is employed for
%     direct time integration of the general linear dynamic response
%     structural Single Degree of Freedom (SDOF) dynamic problem. The
%     optimal numerical dissipation and dispersion zero order displacement
%     zero order velocity algorithm designed according to the above journal
%     article, is used in this routine. This algorithm encompasses the
%     scope of Linear Multi-Step (LMS) methods and is limited by the
%     Dahlquist barrier theorem (Dahlquist,1963).
%     The force - displacement - velocity relation of the SDOF structure is
%     linear. For the time integration of the equations of motion the
%     signal processing function FILTER is used which is much faster than a
%     loop over the time increments. However, this function is applicable
%     only for time steps of equal size DT. If this is not the case,
%     resampling can be used to reduce the excitation time history into a
%     time history with equal time steps, using the function RESAMPLE, as
%     follows:
%         fs = 100; % Sample rate
%         p=1; % upsampling factor
%         q=1; % downsampling factor
%         [xgtt_new,time_new] = resample(xgtt_old,time_old,fs,p,q);
%
% Input parameters
%     K [double(1 x 1)]: stiffness of the SDOF system.
%     M [double(1 x 1)]: mass of the SDOF system.
%     DT [double(1 x 1)]: uniform time step of acceleration time history
%         XGTT
%     XGTT [double(:nstep x 2)]: column vector of the acceleration history
%         of the excitation imposed at the base. nstep is the number of
%         time steps of the dynamic response.
%     KSI [double(1 x 1)]: ratio of critical damping of the SDOF system
%     ALGID [char(1 x :inf)]: algorithm to be used for the time
%         integration. It can be one of the following strings for superior
%         optimally designed algorithms:
%             'generalized a-method': The generalized a-method (Chung &
%             Hulbert, 1993)
%             'HHT a-method': The Hilber-Hughes-Taylor method (Hilber,
%             Hughes & Taylor, 1977)
%             'WBZ': The Wood�Bossak�Zienkiewicz method (Wood, Bossak &
%             Zienkiewicz, 1980)
%             'U0-V0-Opt': Optimal numerical dissipation and dispersion
%             zero order displacement zero order velocity algorithm
%             'U0-V0-CA': Continuous acceleration (zero spurious root at
%             the low frequency limit) zero order displacement zero order
%             velocity algorithm
%             'U0-V0-DA': Discontinuous acceleration (zero spurious root at
%             the high frequency limit) zero order displacement zero order
%             velocity algorithm
%             'U0-V1-Opt': Optimal numerical dissipation and dispersion
%             zero order displacement first order velocity algorithm
%             'U0-V1-CA': Continuous acceleration (zero spurious root at
%             the low frequency limit) zero order displacement first order
%             velocity algorithm
%             'U0-V1-DA': Discontinuous acceleration (zero spurious root at
%             the high frequency limit) zero order displacement first order
%             velocity algorithm
%             'U1-V0-Opt': Optimal numerical dissipation and dispersion
%             first order displacement zero order velocity algorithm
%             'U1-V0-CA': Continuous acceleration (zero spurious root at
%             the low frequency limit) first order displacement zero order
%             velocity algorithm
%             'U1-V0-DA': Discontinuous acceleration (zero spurious root at
%             the high frequency limit) first order displacement zero order
%             velocity algorithm
%             'Newmark ACA': Newmark Average Constant Acceleration method
%             'Newmark LA': Newmark Linear Acceleration method
%             'Newmark BA': Newmark Backward Acceleration method
%             'Fox-Goodwin': Fox-Goodwin formula
%     U0 [double(1 x 1)]: initial displacement of the SDOF system
%     UT0 [double(1 x 1)]: initial velocity of the SDOF system
%     RINF [double(1 x 1)]: minimum absolute value of the eigenvalues of
%         the amplification matrix. For the amplification matrix see
%         eq.(61) in Zhou & Tamma (2004).
%
% Output parameters
%     U [double(:nstep x 1)]: time-history of displacement
%     UT [double(:nstep x 1)]: time-history of velocity
%     UTT [double(:nstep x 1)]: time-history of acceleration
%
%__________________________________________________________________________
% Copyright (c) 2015-2021
%     George Papazafeiropoulos
%     Major, Infrastructure Engineer, Hellenic Air Force
%     Civil Engineer, M.Sc., Ph.D. candidate, NTUA
%     Email: gpapazafeiropoulos@yahoo.gr
% _________________________________________________________________________

%% Integration constants
% Set integration constants
if all(size(AlgID)==[1,14])
    % define integration constants explicitly
    w1=AlgID(1);
    w2=AlgID(2);
    w3=AlgID(3);
    W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
    % W2=(1/3+w1/4+w2/5+w3/6)/(1+w1/2+w2/3+w3/4); % definition
    % W3=(1/4+w1/5+w2/6+w3/7)/(1+w1/2+w2/3+w3/4); % definition
    W1L1=AlgID(4);
    W2L2=AlgID(5);
    W3L3=AlgID(6);
    W1L4=AlgID(7);
    W2L5=AlgID(8);
    W1L6=AlgID(9);
    l1=AlgID(10);
    l2=AlgID(11);
    l3=AlgID(12);
    l4=AlgID(13);
    l5=AlgID(14);
else
    switch AlgID
        case 'U0-V0-Opt'
            % zero-order displacement & velocity overshooting behavior and
            % optimal numerical dissipation and dispersion
            % rinf must belong to [0 1]
            if rinf<0
                rinf=0;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 0');
            end
            if rinf>1
                rinf=1; % mid-point rule a-form algorithm
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1');
            end
            w1=-15*(1-2*rinf)/(1-4*rinf); % suggested
            w2=15*(3-4*rinf)/(1-4*rinf); % suggested
            w3=-35*(1-rinf)/(1-4*rinf); % suggested
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=1/(1+rinf);
            W2L2=1/2/(1+rinf);
            W3L3=1/2/(1+rinf)^2;
            W1L4=1/(1+rinf);
            W2L5=1/(1+rinf)^2; % suggested
            W1L6=(3-rinf)/2/(1+rinf);
            l1=1;
            l2=1/2;
            l3=1/2/(1+rinf);
            l4=1;
            l5=1/(1+rinf);
        case 'U0-V0-CA'
            % zero-order displacement & velocity overshooting behavior and
            % continuous acceleration
            % rinf must belong to [1/3 1]
            if rinf<1/3
                rinf=1/3;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1/3');
            end
            if rinf>1
                rinf=1; % Newmark average acceleration a-form algorithm
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1');
            end
            w1=-15*(1-5*rinf)/(3-7*rinf); % suggested
            w2=15*(1-13*rinf)/(3-7*rinf); % suggested
            w3=140*rinf/(3-7*rinf); % suggested
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=(1+3*rinf)/2/(1+rinf);
            W2L2=(1+3*rinf)/4/(1+rinf);
            W3L3=(1+3*rinf)/4/(1+rinf)^2;
            W1L4=(1+3*rinf)/2/(1+rinf);
            W2L5=(1+3*rinf)/2/(1+rinf)^2; % suggested
            W1L6=1;
            l1=1;
            l2=1/2;
            l3=1/2/(1+rinf);
            l4=1;
            l5=1/(1+rinf);
        case 'U0-V0-DA'
            % zero-order displacement & velocity overshooting behavior and
            % discontinuous acceleration
            % rinf must belong to [0 1]
            if rinf<0
                rinf=0;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 0');
            end
            if rinf>1
                rinf=1; % Newmark average acceleration a-form algorithm
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1');
            end
            w1=-15; % suggested
            w2=45; % suggested
            w3=-35; % suggested
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=1;
            W2L2=1/2;
            W3L3=1/2/(1+rinf);
            W1L4=1;
            W2L5=1/(1+rinf); % suggested
            W1L6=(3+rinf)/2/(1+rinf);
            l1=1;
            l2=1/2;
            l3=1/2/(1+rinf);
            l4=1;
            l5=1/(1+rinf);
        case 'U0-V1-Opt'
            % zero-order displacement & first-order velocity overshooting
            % behavior and optimal numerical dissipation and dispersion
            % This is the generalized a-method (Chung & Hulbert, 1993)
            % rinf must belong to [0 1]
            if rinf<0
                rinf=0;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 0');
            end
            if rinf>1
                rinf=1;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1');
            end
            w1=-15*(1-2*rinf)/(1-4*rinf);
            w2=15*(3-4*rinf)/(1-4*rinf);
            w3=-35*(1-rinf)/(1-4*rinf);
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=1/(1+rinf);
            W2L2=1/2/(1+rinf);
            W3L3=1/(1+rinf)^3;
            W1L4=1/(1+rinf);
            W2L5=(3-rinf)/2/(1+rinf)^2;
            W1L6=(2-rinf)/(1+rinf);
            l1=1;
            l2=1/2;
            l3=1/(1+rinf)^2;
            l4=1;
            l5=(3-rinf)/2/(1+rinf);
        case 'generalized a-method'
            % zero-order displacement & first-order velocity overshooting
            % behavior and optimal numerical dissipation and dispersion
            % This is the generalized a-method (Chung & Hulbert, 1993)
            % rinf must belong to [0 1]
            if rinf<0
                rinf=0;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 0');
            end
            if rinf>1
                rinf=1;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1');
            end
            w1=-15*(1-2*rinf)/(1-4*rinf);
            w2=15*(3-4*rinf)/(1-4*rinf);
            w3=-35*(1-rinf)/(1-4*rinf);
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=1/(1+rinf);
            W2L2=1/2/(1+rinf);
            W3L3=1/(1+rinf)^3;
            W1L4=1/(1+rinf);
            W2L5=(3-rinf)/2/(1+rinf)^2;
            W1L6=(2-rinf)/(1+rinf);
            l1=1;
            l2=1/2;
            l3=1/(1+rinf)^2;
            l4=1;
            l5=(3-rinf)/2/(1+rinf);
        case 'U0-V1-CA'
            % zero-order displacement & first-order velocity overshooting
            % behavior and continuous acceleration
            % This is the Hilber-Hughes-Taylor method (Hilber, Hughes &
            % Taylor, 1977)
            % rinf must belong to [1/2 1]
            if rinf<1/2
                rinf=1/2;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1/2');
            end
            if rinf>1
                rinf=1;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1');
            end
            w1=-15*(1-2*rinf)/(2-3*rinf);
            w2=15*(2-5*rinf)/(2-3*rinf);
            w3=-35*(1-3*rinf)/2/(2-3*rinf);
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=2*rinf/(1+rinf);
            W2L2=rinf/(1+rinf);
            W3L3=2*rinf/(1+rinf)^3;
            W1L4=2*rinf/(1+rinf);
            W2L5=rinf*(3-rinf)/(1+rinf)^2;
            W1L6=1;
            l1=1;
            l2=1/2;
            l3=1/(1+rinf)^2;
            l4=1;
            l5=(3-rinf)/2/(1+rinf);
        case 'HHT a-method'
            % zero-order displacement & first-order velocity overshooting
            % behavior and continuous acceleration
            % This is the Hilber-Hughes-Taylor method (Hilber, Hughes &
            % Taylor, 1977)
            % rinf must belong to [1/2 1]
            if rinf<1/2
                rinf=1/2;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1/2');
            end
            if rinf>1
                rinf=1;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1');
            end
            w1=-15*(1-2*rinf)/(2-3*rinf);
            w2=15*(2-5*rinf)/(2-3*rinf);
            w3=-35*(1-3*rinf)/2/(2-3*rinf);
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=2*rinf/(1+rinf);
            W2L2=rinf/(1+rinf);
            W3L3=2*rinf/(1+rinf)^3;
            W1L4=2*rinf/(1+rinf);
            W2L5=rinf*(3-rinf)/(1+rinf)^2;
            W1L6=1;
            l1=1;
            l2=1/2;
            l3=1/(1+rinf)^2;
            l4=1;
            l5=(3-rinf)/2/(1+rinf);
        case 'U0-V1-DA'
            % zero-order displacement & first-order velocity overshooting
            % behavior and discontinuous acceleration
            % This is the Wood�Bossak�Zienkiewicz method (Wood, Bossak &
            % Zienkiewicz, 1980)
            % rinf must belong to [0 1]
            if rinf<0
                rinf=0;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 0');
            end
            if rinf>1
                rinf=1;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1');
            end
            w1=-15;
            w2=45;
            w3=-35;
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=1;
            W2L2=1/2;
            W3L3=1/(1+rinf)^2;
            W1L4=1;
            W2L5=(3-rinf)/2/(1+rinf);
            W1L6=2/(1+rinf);
            l1=1;
            l2=1/2;
            l3=1/(1+rinf)^2;
            l4=1;
            l5=(3-rinf)/2/(1+rinf);
        case 'WBZ'
            % zero-order displacement & first-order velocity overshooting
            % behavior and discontinuous acceleration
            % This is the Wood�Bossak�Zienkiewicz method (Wood, Bossak &
            % Zienkiewicz, 1980)
            % rinf must belong to [0 1]
            if rinf<0
                rinf=0;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 0');
            end
            if rinf>1
                rinf=1;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1');
            end
            w1=-15;
            w2=45;
            w3=-35;
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=1;
            W2L2=1/2;
            W3L3=1/(1+rinf)^2;
            W1L4=1;
            W2L5=(3-rinf)/2/(1+rinf);
            W1L6=2/(1+rinf);
            l1=1;
            l2=1/2;
            l3=1/(1+rinf)^2;
            l4=1;
            l5=(3-rinf)/2/(1+rinf);
        case 'U1-V0-Opt'
            % first-order displacement & zero-order velocity overshooting
            % behavior and optimal numerical dissipation and dispersion
            % rinf must belong to [0 1]
            if rinf<0
                rinf=0;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 0');
            end
            if rinf>1
                rinf=1; % mid-point rule a-form algorithm
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1');
            end
            w1=-30*(3-8*rinf+6*rinf^2)/(9-22*rinf+19*rinf^2);
            w2=15*(25-74*rinf+53*rinf^2)/2/(9-22*rinf+19*rinf^2);
            w3=-35*(3-10*rinf+7*rinf^2)/(9-22*rinf+19*rinf^2);
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=(3-rinf)/2/(1+rinf);
            W2L2=1/(1+rinf)^2;
            W3L3=1/(1+rinf)^3;
            W1L4=(3-rinf)/2/(1+rinf);
            W2L5=2/(1+rinf)^3;
            W1L6=(2-rinf)/(1+rinf);
            l1=1;
            l2=1/2;
            l3=1/2/(1+rinf);
            l4=1;
            l5=1/(1+rinf);
        case 'U1-V0-CA'
            % first-order displacement & zero-order velocity overshooting
            % behavior and continuous acceleration
            % rinf must belong to [1/2 1]
            if rinf<1/2
                rinf=1/2;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1/2');
            end
            if rinf>1
                rinf=1; % Newmark average acceleration a-form algorithm
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1');
            end
            w1=-60*(2-8*rinf+7*rinf^2)/(11-48*rinf+41*rinf^2);
            w2=15*(37-140*rinf+127*rinf^2)/2/(11-48*rinf+41*rinf^2);
            w3=-35*(5-18*rinf+17*rinf^2)/(11-48*rinf+41*rinf^2);
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=(1+3*rinf)/2/(1+rinf);
            W2L2=2*rinf/(1+rinf)^2;
            W3L3=2*rinf/(1+rinf)^3;
            W1L4=(1+3*rinf)/2/(1+rinf);
            W2L5=4*rinf/(1+rinf)^3;
            W1L6=1;
            l1=1;
            l2=1/2;
            l3=1/2/(1+rinf);
            l4=1;
            l5=1/(1+rinf);
        case 'U1-V0-DA'
            % first-order displacement & zero-order velocity overshooting behavior
            % and discontinuous acceleration
            % This is the Newmark average acceleration a-form algorithm
            % rinf must belong to [0 1]
            if rinf<0
                rinf=0;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 0');
            end
            if rinf>1
                rinf=1;
                warning('Minimum absolute eigenvalue of amplification matrix is set to 1');
            end
            w1=-30*(3-4*rinf)/(9-11*rinf);
            w2=15*(25-37*rinf)/2/(9-11*rinf);
            w3=-35*(3-5*rinf)/(9-11*rinf);
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=(3+rinf)/2/(1+rinf);
            W2L2=1/(1+rinf);
            W3L3=1/(1+rinf)^2;
            W1L4=(3+rinf)/2/(1+rinf);
            W2L5=2/(1+rinf)^2;
            W1L6=2/(1+rinf);
            l1=1;
            l2=1/2;
            l3=1/(1+rinf)^2;
            l4=1;
            l5=(3-rinf)/2/(1+rinf);
        case 'Newmark ACA'
            % Newmark Average Constant Acceleration method
            w1=-15;
            w2=45;
            w3=-35;
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            % W2=(1/3+w1/4+w2/5+w3/6)/(1+w1/2+w2/3+w3/4); % definition
            % W3=(1/4+w1/5+w2/6+w3/7)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=1;
            W2L2=0.25;
            W3L3=0.25;
            W1L4=0.5;
            W2L5=0.5;
            W1L6=1;
            l1=1;
            l2=0.5;
            l3=0.25;
            l4=1;
            l5=0.5;
        case 'Newmark LA'
            % Newmark Linear Acceleration method
            w1=-15;
            w2=45;
            w3=-35;
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            % W2=(1/3+w1/4+w2/5+w3/6)/(1+w1/2+w2/3+w3/4); % definition
            % W3=(1/4+w1/5+w2/6+w3/7)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=1;
            W2L2=1/6;
            W3L3=1/6;
            W1L4=0.5;
            W2L5=0.5;
            W1L6=1;
            l1=1;
            l2=0.5;
            l3=1/6;
            l4=1;
            l5=0.5;
        case 'Newmark BA'
            % Newmark Backward Acceleration method
            w1=-15;
            w2=45;
            w3=-35;
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            % W2=(1/3+w1/4+w2/5+w3/6)/(1+w1/2+w2/3+w3/4); % definition
            % W3=(1/4+w1/5+w2/6+w3/7)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=1;
            W2L2=0.5;
            W3L3=0.5;
            W1L4=0.5;
            W2L5=0.5;
            W1L6=1;
            l1=1;
            l2=0.5;
            l3=0.5;
            l4=1;
            l5=0.5;
        case 'Fox-Goodwin'
            % Fox-Goodwin formula
            w1=-15;
            w2=45;
            w3=-35;
            W1=(1/2+w1/3+w2/4+w3/5)/(1+w1/2+w2/3+w3/4); % definition
            % W2=(1/3+w1/4+w2/5+w3/6)/(1+w1/2+w2/3+w3/4); % definition
            % W3=(1/4+w1/5+w2/6+w3/7)/(1+w1/2+w2/3+w3/4); % definition
            W1L1=1;
            W2L2=1/12;
            W3L3=1/12;
            W1L4=0.5;
            W2L5=0.5;
            W1L6=1;
            l1=1;
            l2=0.5;
            l3=1/12;
            l4=1;
            l5=0.5;
        otherwise
            error('No appropriate algorithm specified.');
    end
end

%% Transfer function denominator
omega=sqrt(k/m);
Omega=omega*dt;
D=W1L6+2.*W2L5.*ksi.*Omega+W3L3.*Omega.^2;
A31=-Omega.^2./D;
A32=-1./D.*(2.*ksi.*Omega+W1L1.*Omega.^2);
A33=1-1./D.*(1+2.*W1L4.*ksi.*Omega+W2L2.*Omega.^2);
A11=1+l3.*A31;
A12=l1+l3.*A32;
A13=l2-l3.*(1-A33);
A21=l5.*A31;
A22=1+l5.*A32;
A23=l4-l5.*(1-A33);
% Amplification matrix
A=[A11 A12 A13;A21 A22 A23;A31 A32 A33];
% Amplification matrix invariants
A1=A(1,1)+A(2,2)+A(3,3);
A2=A(1,1)*A(2,2)-A(1,2)*A(2,1)+A(1,1)*A(3,3)-A(1,3)*A(3,1)+A(2,2)*A(3,3)-A(2,3)*A(3,2);
A3=A(1,1)*A(2,2)*A(3,3)-A(1,1)*A(2,3)*A(3,2)-A(1,2)*A(2,1)*A(3,3)+A(1,2)*A(2,3)*A(3,1)+A(1,3)*A(2,1)*A(3,2)-A(1,3)*A(2,2)*A(3,1);
% Transfer function denominator
a=[1 -A1 A2 -A3];

%% Transfer function nominator
B1=1./D.*dt^2.*l3.*W1;
B2=1./D.*dt^2.*(l3.*(1-W1)-(A22+A33).*l3.*W1+A12.*l5.*W1+A13.*W1);
B3=1./D.*dt^2.*(-(A22+A33).*l3.*(1-W1)+A12.*l5.*(1-W1)+A13.*(1-W1)+(A22.*A33-A23.*A32).*l3.*W1-(A12.*A33-A13.*A32).*l5.*W1+(A12.*A23-A13.*A22).*W1);
B4=1./D.*dt^2.*((A22.*A33-A23.*A32).*l3.*(1-W1)-(A12.*A33-A13.*A32).*l5.*(1-W1)+(A12.*A23-A13.*A22).*(1-W1));
b=[B1,B2,B3,B4];

%% form initial conditions for filter function
% equivalent external force
f=-xgtt;
% stiffness
k=omega.^2;
% damping constants
c=2.*omega.*ksi;
% initial acceleration
utt0=-f(1)-(k*u0+c*ut0);
U_1=A\[u0;dt*ut0;dt^2*utt0];
u_1=U_1(1);
U_2=A\U_1;
u_2=U_2(1);
ypast=[u0,u_1,u_2];
vinit=zeros(1,3);
vinit(3:-1:1) = filter(-a(4:-1:2),1,ypast);

%% main dynamic analysis
u=filter(b,a,f,vinit);

%% calculate velocity from the following system of equations:
% 1st: the first scalar equation of the matrix equation (60) in [1]
% 2nd: equation of motion (eq.6.12.3 in Chopra:Dynamics of Structures)
C_u=omega^2*A(1,3)*dt^2-A(1,1);
C_f=-A(1,3)*dt^2;
C_ut=A(1,2)*dt-A(1,3)*dt^2*2*ksi*omega;
L=1/D*l3*dt^2*((1-W1)*[0;f(1:end-1)]+W1*f);
ut=(u+C_u*[u0;u(1:end-1)]+C_f*[0;f(1:end-1)]-L)/C_ut;
%ut=[ut0; diff(u)/dt];

%% calculate acceleration from equation of motion
utt=-omega^2*u-2*ksi*omega*ut;

%% Elastic force
f=k*u;

end

