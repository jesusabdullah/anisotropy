angles = [5 10 15];
save('angles.mat', 'angles');
kxy = [0.3];
kz = [0.1, 0.5];
%ks = linspace(0.2,0.4,4);
worker(kxy, kz);
