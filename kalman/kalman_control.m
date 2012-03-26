% -------------------------------------------------------------------------
% Modelo fisico
% -------------------------------------------------------------------------
% d(x)/dt     = vqx*cos(phi)*cos(theta)+vqy*(cos(theta)*sin(phi)*sin(psi)-cos(phi)*sin(theta))+vqz*(sin(psi)*sin(theta)+cos(psi)*cos(theta)*sin(phi))
% d(y)/dt     = vqx*cos(phi)*sin(theta)+vqy*(sin(theta)*sin(phi)*sin(psi)+cos(psi)*cos(theta))+vqz*(cos(psi)*sin(theta)*sin(phi)-cos(theta)*sin(psi))
% d(z)/dt     = -vqx*sin(phi)+vqy*cos(phi)*sin(psi)+vqz*cos(psi)*cos(psi)
% d(psi)/dt   = wqx+wqz*tan(fi)*cos(psi)+wqy*tan(fi)*sin(psi);
% d(phi)/dt   = wqy*cos(psi)-wqz*sin(psi);
% d(theta)/dt = wqz*cos(psi)/cos(fi)+wqy*sin(psi)/cos(fi);
% d(vqx)/dt   = vqy*wqz-vqz*wqy+g*sin(phi)
% d(vqy)/dt   = vqz*wqx-vqx*wqz-g*cos(phi)*sin(psi)
% d(vqz)/dt   = vqx*wqy-vqy*wqx-g*cos(phi)*cos(psi)+1/M*(TM(1)+TM(2)+TM(3)+TM(4))
% d(wqx)/dt   = ( wqy*wqz*(Iyy-Izz)+wqy*Izzm*(w1-w2+w3-w4)+L*(T2-T4) )/Ixx;
% d(wqy)/dt   = ( wqx*wqz*(Izz-Ixx)+wqx*Izzm*(w1-w2+w3-w4)+L*(T3-T1) )/Iyy;
% d(wqz)/dt   = ( -Izzm*(dw1-dw2+dw3-dw4)+Q1-Q2+Q3-Q4 )/Izz;
% 
% -------------------------------------------------------------------------
% Estado
% -------------------------------------------------------------------------
% x = [x y z psi phi tehta vqx vqy vqz wqx wqy wqz]
% 
% -------------------------------------------------------------------------
% Kalman
% -------------------------------------------------------------------------
% A partir de los datos del gyro se hace un Kalman para la estimación de la
% velocidad angular en las 3 direcciones. A partir de los datos del
% magnetometro, convertidos a angulos de euler en mong_conv se estiman los
% angulos con el mismo filtro de kalman.
% A su vez con los datos de los acelerometros y los otros estados estimados
% se hallan las velocidades referenciadas al quad (vq) y por ultimo se
% incluye la estimacion de la posicion absoluta del quad, utilizando
% unicamente el modelo fisico. No se realiza correcion con ningun sensor a
% los estados x, y, z (posicion absoluta)
% -------------------------------------------------------------------------

close all
clear all
clc

%% Observaciones y constantes

% [acrud,wcrud,mcrud,tcrud,bcrud]=mong_read('/gyro/logs/zv3y00',0);
% [acrud,wcrud,mcrud,tcrud,bcrud]=mong_read('tests/mongoose/magnetometro/data_horizontal/x00z00',0);

% [acrud,wcrud,mcrud,tcrud,bcrud,~,~,T]=mong_read('log-zparriba4',0);
% [acrud,wcrud,mcrud,tcrud,bcrud,~,~,T]=mong_read('../../../Escritorio/imu_raw.log',0,1);

file = 'tests/main/logs/vuelo_2_03_25/imu_raw.log';
[acrud,wcrud,mcrud,tcrud,bcrud,~,~,T]=mong_read(file,0,1);

% [acrud,wcrud,mcrud,tcrud,bcrud,~,~,T]=mong_read('imu_raw_8.log',0,1);

% [acrud,wcrud,mcrud,tcrud,bcrud,~,~,T]=mong_read('./src/build/main/imu_raw.log',0,1);
[a,w,euler] = mong_conv(acrud,wcrud,mcrud,0);
b=altitud(bcrud);

% Test contra c
% Usar datos que recibe uquad_kalman() para verificar comportamiento acorde
% al codigo.
% xhat = load('./src/build/main/kalman_in.log');
% a = xhat(:,5:7);
% w = xhat(:,8:10);
% euler = xhat(:,11:13);
% b = xhat(:,end);
% T = xhat(:,1)/1e6;

% w(:,1) = w(:,1)-mean(w(1:50,1));
% w(:,2) = w(:,2)-mean(w(1:50,2));
% w(:,3) = w(:,3)-mean(w(1:50,3));

% fs = 30;                % Frecuencia en Hz
% T  = 1/fs;              % Periodo de muestreo en segundos
% T  = ones(length(a))*1/30;
N  = size(a,1);         % Cantidad de muestras de las observaciones
Ns = 12;                % N states: cantidad de variables de estado
z  = [euler a w b];     % Observaciones
% z  = z+0*randn(N,Ns);   % Agregado de ruido

%% Constantes

Ixx  = 2.32e-2;         % Tensor de inercia del quad - según x
Iyy  = 2.32e-2;         % Tensor de inercia del quad - según y
Izz  = 4.37e-2;         % Tensor de inercia del quad - según z
Izzm = 1.54e-5;         % Tensor de inercia de los motores - segun z
L    = 0.29;            % Largo en metros del los brazos del quad
M    = 1.541;           % Masa del Quad en kg
g    = 9.81;            % Aceleracion gravitatoria

%% Kalman
     
f = @(x,y,z,psi,phi,theta,vqx,vqy,vqz,wqx,wqy,wqz,w,dw,TM,D,T) [ ...    
    x     + T *(vqx*cos(phi)*cos(theta)+vqy*(cos(theta)*sin(phi)*sin(psi)-cos(phi)*sin(theta))+vqz*(sin(psi)*sin(theta)+cos(psi)*cos(theta)*sin(phi)) ) ;
    y     + T *(vqx*cos(phi)*sin(theta)+vqy*(sin(theta)*sin(phi)*sin(psi)+cos(psi)*cos(theta))+vqz*(cos(psi)*sin(theta)*sin(phi)-cos(theta)*sin(psi)) ) ;
    z     + T *(-vqx*sin(phi)+vqy*cos(phi)*sin(psi)+vqz*cos(psi)*cos(psi));
    ...
    psi   + T*( wqx+wqz*tan(phi)*cos(psi)+wqy*tan(phi)*sin(psi));
    phi   + T*( wqy*cos(psi)-wqz*sin(psi));
    theta + T*( wqz*cos(psi)/cos(phi)+wqy*sin(psi)/cos(phi));
    ...
    vqx   + T*( vqy*wqz-vqz*wqy+g*sin(phi));
    vqy   + T*( vqz*wqx-vqx*wqz-g*cos(phi)*sin(psi));
    vqz   + T*( vqx*wqy-vqy*wqx-g*cos(phi)*cos(psi)+1/M*(TM(1)+TM(2)+TM(3)+TM(4)));
    ...   
    wqx   + T*( wqy*wqz*(Iyy-Izz)+wqy*Izzm*(w(1)-w(2)+w(3)-w(4))+L*(TM(2)-TM(4)) )/Ixx ;
    wqy   + T*( wqx*wqz*(Izz-Ixx)+wqx*Izzm*(w(1)-w(2)+w(3)-w(4))+L*(TM(3)-TM(1)) )/Iyy;
    wqz   + T*( -Izzm*(dw(1)-dw(2)+dw(3)-dw(4))+D(1)-D(2)+D(3)-D(4) )/Izz ...
    ];

h = @(z,psi,phi,theta,vqx,vqy,vqz,wqx,wqy,wqz,TM) [ ... 
    psi ; 
    phi ; 
    theta ; 
    0;
    0;
    1/M*(TM(1)+TM(2)+TM(3)+TM(4));
    wqx ; 
    wqy ; 
    wqz ;
    z ...
    ];

F = @(psi,phi,theta,vqx,vqy,vqz,wqx,wqy,wqz,w,T) ...
	[ ... 
    1, 0, 0,                          T*(vqz*(cos(psi)*sin(theta) - cos(theta)*sin(phi)*sin(psi)) + vqy*cos(psi)*cos(theta)*sin(phi)), T*(vqy*(sin(phi)*sin(theta) + cos(phi)*cos(theta)*sin(psi)) - vqx*cos(theta)*sin(phi) + vqz*cos(phi)*cos(psi)*cos(theta)), -T*(vqy*(cos(phi)*cos(theta) + sin(phi)*sin(psi)*sin(theta)) - vqz*(cos(theta)*sin(psi) - cos(psi)*sin(phi)*sin(theta)) + vqx*cos(phi)*sin(theta)), T*cos(phi)*cos(theta), -T*(cos(phi)*sin(theta) - cos(theta)*sin(phi)*sin(psi)),  T*(sin(psi)*sin(theta) + cos(psi)*cos(theta)*sin(phi)),                                                       0,                                                            0,                        0 ;
    0, 1, 0, -T*(vqy*(cos(theta)*sin(psi) - cos(psi)*sin(phi)*sin(theta)) + vqz*(cos(psi)*cos(theta) + sin(phi)*sin(psi)*sin(theta))),                         T*(vqz*cos(phi)*cos(psi)*sin(theta) - vqx*sin(phi)*sin(theta) + vqy*cos(phi)*sin(psi)*sin(theta)),  T*(vqz*(sin(psi)*sin(theta) + cos(psi)*cos(theta)*sin(phi)) - vqy*(cos(psi)*sin(theta) - cos(theta)*sin(phi)*sin(psi)) + vqx*cos(phi)*cos(theta)), T*cos(phi)*sin(theta),  T*(cos(psi)*cos(theta) + sin(phi)*sin(psi)*sin(theta)), -T*(cos(theta)*sin(psi) - cos(psi)*sin(phi)*sin(theta)),                                                       0,                                                            0,                        0 ;    0, 0, 1,                                                                      T*(vqy*cos(phi)*cos(psi) - 2*vqz*cos(psi)*sin(psi)),                                                                                 -T*(vqx*cos(phi) + vqy*sin(phi)*sin(psi)),                                                                                                                                                  0,           -T*sin(phi),                                     T*cos(phi)*sin(psi),                                            T*cos(psi)^2,                                                       0,                                                            0,                        0 ;
    0, 0, 0,                                                                    T*(wqy*cos(psi)*tan(phi) - wqz*sin(psi)*tan(phi)) + 1,                                                         T*(wqz*cos(psi)*(tan(phi)^2 + 1) + wqy*sin(psi)*(tan(phi)^2 + 1)),                                                                                                                                                  0,                     0,                                                       0,                                                       0,                                                       T,                                          T*sin(psi)*tan(phi),      T*cos(psi)*tan(phi) ;
    0, 0, 0,                                                                                         -T*(wqz*cos(psi) + wqy*sin(psi)),                                                                                                                         1,                                                                                                                                                  0,                     0,                                                       0,                                                       0,                                                       0,                                                   T*cos(psi),              -T*sin(psi) ;
    0, 0, 0,                                                                    T*((wqy*cos(psi))/cos(phi) - (wqz*sin(psi))/cos(phi)),                                               T*((wqz*cos(psi)*sin(phi))/cos(phi)^2 + (wqy*sin(phi)*sin(psi))/cos(phi)^2),                                                                                                                                                  1,                     0,                                                       0,                                                       0,                                                       0,                                        (T*sin(psi))/cos(phi),    (T*cos(psi))/cos(phi) ;
    0, 0, 0,                                                                                                                        0,                                                                                                              T*g*cos(phi),                                                                                                                                                  0,                     1,                                                   T*wqz,                                                  -T*wqy,                                                       0,                                                       -T*vqz,                    T*vqy ;
    0, 0, 0,                                                                                                   -T*g*cos(phi)*cos(psi),                                                                                                     T*g*sin(phi)*sin(psi),                                                                                                                                                  0,                -T*wqz,                                                       1,                                                   T*wqx,                                                   T*vqz,                                                            0,                   -T*vqx ;
    0, 0, 0,                                                                                                    T*g*cos(phi)*sin(psi),                                                                                                     T*g*cos(psi)*sin(phi),                                                                                                                                                  0,                 T*wqy,                                                  -T*wqx,                                                       1,                                                  -T*vqy,                                                        T*vqx,                        0 ;
    0, 0, 0,                                                                                                                        0,                                                                                                                         0,                                                                                                                                                  0,                     0,                                                       0,                                                       0,                                                       1, (T*(wqz*(Iyy - Izz) + Izzm*(w(1) - w(2) + w(3) - w(4))))/Ixx,  (T*wqy*(Iyy - Izz))/Ixx ;
    0, 0, 0,                                                                                                                        0,                                                                                                                         0,                                                                                                                                                  0,                     0,                                                       0,                                                       0, -(T*(wqz*(Ixx - Izz) - Izzm*(w(1)-w(2)+w(3)-w(4))))/Iyy,                                                            1, -(T*wqx*(Ixx - Izz))/Iyy ;
    0, 0, 0,                                                                                                                        0,                                                                                                                         0,                                                                                                                                                  0,                     0,                                                       0,                                                       0,                                                       0,                                                            0,                        1 ...
    ]; 
 
H = @() ...
    [ ...
    0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0
    0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0
    0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
    0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ];

% Q = sigma_w^2*eye(Ns);  % 10*eye(Ns)
% Q = 100*eye(Ns);
% Valores

% uquad_kalman.c en git en 9f421f090debbb63725be9413fe659b98d043cd7
% Q = diag(.1*[100 100 100 100 100 100 100 100 100 100 100 100]);
% R = diag(100*[10 10 10 10 10 10 100 100 100 100]);
% Configuracion mas estable (salta menos, aunque igual diverge)
% Q = diag(.0001*[100 100 100 100 100 100 100 100 100 100 100 100]);
% R = diag(1000*[10 10 10 10 10 10 10 10 10 10]);

Q = diag(1*[100 100 100 1 1 1 10 10 10 1 1 1]);
R = diag(1000*[.001 .001 .001 10 10 10 10 10 10 10]);

P = 1*eye(Ns);
x_hat=zeros(N,Ns);

% K = load('Kotra4.mat');K = K.K;
K = load('K.mat');K = K.K;
w_hover = 334.28;
sp_x = zeros(7,1);
sp_w = ones(4,1)*w_hover;
w_control = zeros(4,N);
x_hat_partial = zeros(7,N);

% psi_init   = z(1,1);
% phi_init   = z(1,2);
% theta_init = z(1,3);
% wqx_init   = z(1,7);
% wqy_init   = z(1,8);
% wqz_init   = z(1,9);
% vqx_init   = 0;%-(TM(1,1)*wqx_init + TM(1,2)*wqx_init + TM(1,3)*wqx_init + TM(1,4)*wqx_init - M*z(1,4)*wqx_init - M*z(1,5)*wqy_init - M*z(1,6)*wqx_init + M*g*wqx_init*sin(phi_init) - M*g*wqx_init*cos(phi_init)*cos(psi_init) - M*g*wqy_init*cos(phi_init)*sin(psi_init))/(M*wqy_init*(wqx_init - wqz_init));
% vqy_init   = 0;%-(TM(1,1)*wqz_init + TM(1,2)*wqz_init + TM(1,3)*wqz_init + TM(1,4)*wqz_init - M*z(1,4)*wqx_init - M*z(1,5)*wqy_init - M*z(1,6)*wqz_init + M*g*wqx_init*sin(phi_init) - M*g*wqz_init*cos(phi_init)*cos(psi_init) - M*g*wqy_init*cos(phi_init)*sin(psi_init))/(M*wqz_init*(wqx_init - wqz_init));
% vqz_init   = 0;%-(TM(1,1)*wqz_init + TM(1,2)*wqz_init + TM(1,3)*wqz_init + TM(1,4)*wqz_init - M*z(1,4)*wqz_init - M*z(1,5)*wqy_init - M*z(1,6)*wqz_init + M*g*wqz_init*sin(phi_init) - M*g*wqz_init*cos(phi_init)*cos(psi_init) - M*g*wqy_init*cos(phi_init)*sin(psi_init))/(M*wqy_init*(wqx_init - wqz_init));
% xinit = T(1) *(vqx_init*cos(phi_init)*cos(theta_init)+vqy_init*(cos(theta_init)*sin(phi_init)*sin(psi_init)-cos(phi_init)*sin(theta_init))+vqz_init*(sin(psi_init)*sin(theta_init)+cos(psi_init)*cos(theta_init)*sin(phi_init)) );
% yinit = T(1) *(vqx_init*cos(phi_init)*sin(theta_init)+vqy_init*(sin(theta_init)*sin(phi_init)*sin(psi_init)+cos(psi_init)*cos(theta_init))+vqz_init*(cos(psi_init)*sin(theta_init)*sin(phi_init)-cos(theta_init)*sin(psi_init)) );
% % zinit = T(1) *(-vqx_init*sin(phi_init)+vqy_init*cos(phi_init)*sin(psi_init)+vqz_init*cos(psi_init)*cos(psi_init));
% zinit = b(1);
% x_hat(1,:)=[ xinit yinit zinit psi_init phi_init theta_init vqx_init vqy_init vqz_init wqy_init wqx_init wqz_init];
% clear psi_init; clear phi_init; clear theta_init; clear wqx_init; clear wqy_init; clear wqz_init; clear vqx_init; clear vqy_init; clear vqz_init; clear xinit; clear yinit; clear zinit;

w_max = 387.0; % Como MOT_MAX_W de mot_control.h
w_min = 109.0; % Como MOT_IDLE_W de mot_control.h

for i=2:N
    w = w_control(:,i-1);
%     w = 334.28*ones(4,1);
% En uquad_kalman() NO se usa esto, se usar dw == 0.
%     if ((i-2)<=0)
%         dw = zeros(4,1);
%     else
%         dw = w_control(:,i-1)-w_control(:,i-2);
% %     end
    dw = zeros(4,1); 
    TM = 3.5296e-5*w.^2-4.9293e-4*w;   % Fuerzas ejercidas por los motores en N. Cada columna corresponde a 1 motor.
    D  = 3.4734e-6*w.^2-1.3205e-4*w;   % Torque de Drag ejercido por los motores en N*m. Cada columna corresponde a cada motor
    Tk=T(i-1);
    
    % Prediction
    x_   = f(x_hat(i-1,1),x_hat(i-1,2),x_hat(i-1,3),x_hat(i-1,4),x_hat(i-1,5),x_hat(i-1,6),x_hat(i-1,7),x_hat(i-1,8),x_hat(i-1,9),x_hat(i-1,10),x_hat(i-1,11),x_hat(i-1,12),w,dw,TM,D,Tk);
    Fk_1 = F(x_hat(i-1,4),x_hat(i-1,5),x_hat(i-1,6),x_hat(i-1,7),x_hat(i-1,8),x_hat(i-1,9),x_hat(i-1,10),x_hat(i-1,11),x_hat(i-1,12),w,Tk);
    P_   = Fk_1 * P * Fk_1'+ Q; 
    
    % Update
    yk         = z(i,:)' - h(x_(3),x_(4),x_(5),x_(6),x_(7),x_(8),x_(9),x_(10),x_(11),x_(12),TM);
    Hk         = H();
    Sk         = Hk*P_*Hk' + R;
    Kk         = P_*Hk'*Sk^-1;
    x_hat(i,:) = x_ + Kk*yk;
    P          = (eye(Ns)-Kk*Hk)*P_;

    % Control
    x_hat_partial(:,i) = [x_hat(i,3);x_hat(i,4);x_hat(i,5);x_hat(i,9);x_hat(i,10);x_hat(i,11);x_hat(i,12)];
    w_control(:,i) = sp_w + K*(sp_x - x_hat_partial(:,i));
    for j=1:4
      if(w_control(j,i) < w_min)
        w_control(j,i) = w_min;
      end
      if (w_control(j,i) > w_max)
        w_control(j,i) = w_max;
      end
    end
end


%% Plots
% 
figure()

subplot(221)
    plot([x_hat(1:end,1)],'b')
    hold on; grid
    plot([x_hat(1:end,2)],'r')
    plot(b,'k')
    plot([x_hat(1:end,3)],'g')
    legend('x','y','z')
    hold off    

subplot(222)
    plot(z(:,1)*180/pi,'k')
    hold on; grid
    plot(z(:,2)*180/pi,'k')
    plot(z(:,3)*180/pi,'k')
    plot([x_hat(1:end,4)]*180/pi,'b')
    plot([x_hat(1:end,5)]*180/pi,'r')
    plot([x_hat(1:end,6)]*180/pi,'g')
    legend('\psi','\phi','\theta','\psi','\phi','\theta')
    hold off    
    
subplot(223)
    plot([x_hat(1:end,7)],'b')
    hold on; grid
    plot([x_hat(1:end,8)],'r')
    plot([x_hat(1:end,9)],'g')
    legend('v_{qx}','v_{qy}','v_{qz}')
    hold off

subplot(224)
    plot(z(:,7),'k')
    hold on; grid
    plot(z(:,8),'k')
    plot(z(:,9),'k')    
    plot([x_hat(1:end,10)],'b')
    plot([x_hat(1:end,11)],'r')
    plot([x_hat(1:end,12)],'g')
    legend('w_x','w_y','w_z','w_x','w_y','w_z')
    hold off
    
% figure()
% subplot(211)
%     plot(z(:,1)-[x_hat(1:end,4)],'b')
%     hold on; grid
%     plot(z(:,2)-[x_hat(1:end,5)],'r')
%     plot(z(:,3)-[x_hat(1:end,6)],'g')    
%     legend('\psi','\phi','\theta')
%     title('Errores en angulos')
%     hold off
% subplot(212)
%     plot(z(:,7)-[x_hat(1:end,10)],'b')
%     hold on; grid
%     plot(z(:,8)-[x_hat(1:end,11)],'r')
%     plot(z(:,9)-[x_hat(1:end,12)],'g')    
%     legend('w_x','w_y','w_z')
%     title('Errores en velocidades angulares')
%     hold off