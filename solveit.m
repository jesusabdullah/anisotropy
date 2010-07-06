% COMSOL Multiphysics Model M-file
% Generated by COMSOL 3.5a (COMSOL 3.5.0.608, $Date: 2009/05/11 07:38:49 $)

function solution_generate(meshfile,kmatrix)
    %solution_generate(meshmat,kmatrix)
    %uses comsol to pump out a solution using a given mesh-mat and a k-matrix in comsol format.

    flreport('off');

    %params
    saveroot='./';



    %It might be a good idea to take this approach.
    %flbinaryfile='solve.mphm';

    load meshfile;

    %{
    % Geometry
    clear draw
    g9=flbinary('g9','draw',flbinaryfile);
    g7=flbinary('g7','draw',flbinaryfile);
    g8=flbinary('g8','draw',flbinaryfile);
    g6=flbinary('g6','draw',flbinaryfile);
    g5=flbinary('g5','draw',flbinaryfile);
    g4=flbinary('g4','draw',flbinaryfile);
    g3=flbinary('g3','draw',flbinaryfile);
    draw.p.objs = {g9,g7,g8,g6,g5,g4,g3};
    draw.p.name = {'B_6','B_4','B_5','B_3','B_2','B_1','ORIGIN'};
    draw.p.tags = {'g9','g7','g8','g6','g5','g4','g3'};
    g2=flbinary('g2','draw',flbinaryfile);
    g1=flbinary('g1','draw',flbinaryfile);
    draw.s.objs = {g2,g1};
    draw.s.name = {'NEEDLE','SNOW'};
    draw.s.tags = {'g2','g1'};
    fem.draw = draw;
    fem.geom = geomcsg(fem);
    fem.mesh = flbinary('m1','mesh',flbinaryfile); 
    %}

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
    equ.rho = {200,8000};
    equ.init = 0;
    equ.shape = 2;
    equ.C = {2050,460};
    equ.Q = {0,635500};
    equ.k = {{0.2;0.1;0.1},160};
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
                    'tlist',[colon(0,0.1,1) colon(2,2,10) colon(20,10,100)], ...
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
    % fem0=fem;

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
               'solnum','end');

    % Integrate
    T_surf_avg=postint(fem,'T/area', ...
               'unit','', ...
               'recover','off', ...
               'dl',[1,2,3,4,10,11,12,13], ...
               'edim',2, ...
               'solnum','end');


    save([saveroot meshfile(1:size(a,2)-4) '-matrix-' cell2str(kmatrix) '-' date '.mat'], 'fem');
end