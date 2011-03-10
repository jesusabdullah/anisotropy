% COMSOL Multiphysics Model M-file
% Generated by COMSOL 3.5a (COMSOL 3.5.0.608, $Date: 2009/05/11 07:38:49 $)

function answer=solver(kxy,kz,fem,theta,params)
    %solver(kxy,kz,mesh,params)
    %uses comsol to pump out a solution using a given mesh-mat and a k-matrix in comsol format.

    fprintf(['solving for kxy=' num2str(kxy) ' and kz=' num2str(kz) '...\n']);
    % Application mode 1
    clear appl
    appl.mode.class = 'GeneralHeat';
    appl.module = 'HT';
    appl.shape = {'shlag(1,''J'')','shlag(2,''T'')'};
    appl.sshape = 2;
    appl.assignsuffix = '_htgh';
    clear bnd
    bnd.type = {'q0','cont'};
    bnd.shape = 1;
    bnd.ind = [1,1,1,1,2,2,2,2,2,1,1,1,1,2];
    appl.bnd = bnd;
    clear equ
    equ.sdtype = 'gls';
    % densities
    equ.rho = {params.density_snow,params.density_needle};
    equ.init = 0;
    equ.shape = 2;
    % Heat capacities
    equ.C = {params.cp_snow,params.cp_needle};
    % Wattage
    equ.Q = {0,params.q_needle/pi/(params.rneedle)^2};
    % Heat conductivities
    arr = [cos(theta*pi/180), 0, sin(theta*pi/180); 0, 1, 0; -sin(theta*pi/180), 0, cos(theta*pi/180)]; %rotation matrix
    equ.k = {symmetric_tocell(arr*diag([kxy,kxy,kz])*(arr')),params.k_needle};
    equ.ind = [1,2];
    appl.equ = equ;
    fem.appl{1} = appl;
    fem.frame = {'ref'};
    fem.border = 1;
    fem.outform = 'general';
    clear units;
    units.basesystem = 'SI';
    fem.units = units;

    % Coupling variable elements
    clear elemcpl
    % Integration coupling variables
    clear elem
    elem.elem = 'elcplscalar';
    elem.g = {'1'};
    src = cell(1,1);
    clear bnd
    bnd.expr = {{'T',{}},{'1',{}}};
    bnd.ipoints = {{'4',{}},{'4',{}}};
    bnd.frame = {{'ref',{}},{'ref',{}}};
    bnd.ind = {{'1','2','3','4','10','11','12','13'},{'5','6','7','8','9', ...
      '14'}};
    src{1} = {{},{},bnd,{}};
    elem.src = src;
    geomdim = cell(1,1);
    geomdim{1} = {};
    elem.geomdim = geomdim;
    elem.var = {'int_T','area'};
    elem.global = {'1','2'};
    elemcpl{1} = elem;
    fem.elemcpl = elemcpl;

    % ODE Settings
    clear ode
    clear units;
    units.basesystem = 'SI';
    ode.units = units;
    fem.ode=ode;

    % Multiphysics
    fem=multiphysics(fem);

    % Generate GMG mesh cases
    fem=meshcaseadd(fem,'mgauto','anyshape');

    % Extend mesh
    fem.xmesh=meshextend(fem);

    % Solve problem
    fem.sol=femtime(fem, ...
                    'solcomp',{'T'}, ...
                    'outcomp',{'T'}, ...
                    'blocksize','auto', ...
                    'tlist', params.time, ...
                    'estrat',1, ...
                    'tout','tlist', ...
                    'linsolver','gmres', ...
                    'itrestart',100, ...
                    'prefuntype','right', ...
                    'prefun','gmg', ...
                    'prepar',{'presmooth','ssor','presmoothpar',{'iter',3,'relax',0.8},'postsmooth','ssor','postsmoothpar',{'iter',3,'relax',0.8},'csolver','pardiso'}, ...
                    'stopcond','0.06-int_T/area', ...
                    'mcase',[0 1]);

    % Save current fem structure for restart purposes
    fem0=fem;

    % Plot solution
    %{
    postplot(fem, ...
             'slicedata',{'T','cont','internal','unit','K'}, ...
             'slicexspacing',5, ...
             'sliceyspacing',0, ...
             'slicezspacing',0, ...
             'slicemap','Rainbow', ...
             'solnum','end', ...
             'title','Time=100    Slice: Temperature [K]', ...
             'grid','on', ...
             'campos',[-2.636014311828346,-3.4353207343472505,2.4999999999999996], ...
             'camtarget',[0,0,0], ...
             'camup',[0,0,1], ...
             'camva',41.213465344831754);
    %}

    % Integrate
    T_thermistor=postint(fem,'T', ...
               'unit','K', ...
               'recover','off', ...
               'dl',8, ...
               'edim',0, ...
               'solnum','all');

    % Integrate
    T_surf_avg=postint(fem,'T', ...
               'unit','', ...
               'recover','off', ...
               'dl',[1,2,3,4,10,11,12,13], ...
               'edim',2, ...
               'solnum','end');

    answer={[fem.sol.tlist; T_thermistor],T_surf_avg};
    angles = params.angles(2:length(params.angles));
    %fprintf([ '''' kxy '; ' kz '; ' theta '; ' fem.sol.tlist '; ' T_thermistor '; ' T_surf_avg ''' >> results.txt' ]);
    %system([ '''' kxy '; ' kz '; ' theta '; ' fem.sol.tlist '; ' T_thermistor '; ' T_surf_avg ''' >> results.txt' ]);

    %flsave(['fem-' num2str(theta) '-' num2str(kxy) '-' num2str(kz) '.mph']);

    save('angles.m', 'angles');
end
