function output=comsol(k_cell)
    %comsol(k_cell)
    %runs a comsol model using the given k matrix in cells form

    % COMSOL Multiphysics Model M-file
    % Generated by COMSOL 3.5a (COMSOL 3.5.0.603, $Date: 2008/12/03 17:02:19 $)
    % modified by Josh Holbrook
    
    flreport('off') %Supposed to suppress the retarded window results thing.

    % Some parameters, with which we may modify our model
    % Note that some of these MIGHT BE A BAD IDEA TO CHANGE
    % Check where they come into play first!
    % note2self: int2str()
    rprobe=0.0005; %probe radius, meters
    lprobe=0.1; %probe length, meters
    snow_width=0.2; %snow CV side length, meters
    tdomain=[colon(0,0.1,1) colon(2,2,10) colon(20,10,2000)]; %times to evaluate at, in seconds iirc
  
    flclear fem

    fprintf('Geometry-ing...\n');
    
    % Geometry
    % This represents the geometry of the snow control volume.
    g1=block3(snow_width,snow_width,snow_width, ... %lengths of all sides
             'base','corner','pos', ...
             {-0.5*snow_width,-0.5*snow_width,-0.5*snow_width}, ... %beginning corner
             'axis',{'0','0','1'},'rot','0');
    % This represents the geometry of the needle probe.
    g3=cylinder3(rprobe,lprobe, ... %radius and length
                 'pos',{'0','0',0.5*snow_width}, ... %start at edge of box
                 'axis',{'0','0','-1'},'rot','0'); %Go in the -z direction
    parr={point3(0,0,0.5*snow_width-lprobe)}; %should be a point at the tip of the probe
    g4=geomcoerce('point',parr);
    parr={point3(0,0,-0.5*snow_width)}; % bottom of snow
    g5=geomcoerce('point',parr);
    parr={point3(0,0.5*snow_width,0)}; % y face of snow
    g6=geomcoerce('point',parr);
    parr={point3(-0.5*snow_width,0,0)}; % x face of snow
    g7=geomcoerce('point',parr);

    % Analyzed geometry
    clear p s
    p.objs={g4,g5,g6,g7};
    p.name={'TEMP_MEAS','BOUNDARY_1','BOUNDARY_2','BOUNDARY_3'};
    p.tags={'g4','g5','g6','g7'};

    s.objs={g1,g3};
    s.name={'SNOW','NEEDLE'};
    s.tags={'g1','g3'};

    fem.draw=struct('p',p,'s',s);
    fem.geom=geomcsg(fem);

    fprintf('Initializing mesh...\n');
    
    % Initialize mesh
    fem.mesh=meshinit(fem, ...
                      'hauto',5, ...
                      'hgradsub',[2,1.1], ...
                      'hmaxsub',[2,0.00025]);

    fprintf('Reticulating Splines...\n');
                  
    % Application mode 1
    clear appl
    appl.mode.class = 'GeneralHeat';
    appl.module = 'HT';
    appl.shape = {'shlag(1,''J'')','shlag(2,''T'')'};
    appl.assignsuffix = '_htgh';
    clear bnd
    bnd.type = {'q0','cont'};
    bnd.shape = 1;
    bnd.ind = [1,1,1,1,1,2,2,2,1,2,2,1];
    appl.bnd = bnd;
    clear equ
    equ.sdtype = 'gls';
    equ.rho = {200,8000};
    equ.init = 0;
    equ.shape = 2;
    equ.C = {2050,460};
    equ.Q = {0,6.355e5};
    equ.k = {k_cell,160}; %the important substitution happens here
    equ.ind = [1,2];
    appl.equ = equ;
    fem.appl{1} = appl;
    fem.frame = {'ref'};
    fem.border = 1;
    fem.outform = 'general';
    clear units;
    units.basesystem = 'SI';
    fem.units = units;

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

    fprintf('Solving...\n');
    
    % Solve problem
    fem.sol=femtime(fem, ...
                    'solcomp',{'T'}, ...
                    'outcomp',{'T'}, ...
                    'blocksize','auto', ...
                    'tlist',tdomain, ...
                    'estrat',1, ...
                    'tout','tlist', ...
                    'linsolver','gmres', ...
                    'itrestart',100, ...
                    'prefuntype','right', ...
                    'prefun','gmg', ...
                    'prepar',{'presmooth','ssor','presmoothpar',{'iter',3,'relax',0.8},'postsmooth','ssor','postsmoothpar',{'iter',3,'relax',0.8},'csolver','pardiso'}, ...
                    'mcase',[0 1]);

    fprintf('...done.\n');

    % Save current fem structure for restart purposes
    fem0=fem;

    fprintf('Output.\n');
    
    % The data we're interested in:
    output=[fem.sol.tlist; ...
            postint(fem,'T', 'unit','K', 'recover','off','dl',14,'edim',0,'solnum','all')];
    % Should also grab temperatures from more points around
    % edge of control volume!

    % Remove generated GMG mesh cases
    fem=meshcasedel(fem,[1]);
    
    fprintf('Returning.\n');
    return;

end