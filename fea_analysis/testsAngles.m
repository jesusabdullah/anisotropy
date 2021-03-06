    load angles;
    angles
    [kxy,kz] = meshgrid(0.3,0.5);

    %flreport('off');

    % Some parameters we won't want to iterate through
    % WARNING: q_needle was 635500 in my last run! ;__;(t>0
    params=struct('rsnow', 0.4, ...
                  'rneedle', 0.00025, ...
                  'lneedle', 0.1, ...
                  'density_snow', 200, ...
                  'density_needle', 8000, ...
                  'cp_snow', 2050, ...
                  'cp_needle', 460, ...
                  'q_needle', 0.5, ...
                  'k_needle', 160, ...
                  'time', [logspace(0.1,1,15) logspace(1,3,15)], ...
                  'angles', angles);

    saveroot=['./solutions-' date '/'];

    mesh = mesher(0,params);
    for angle=angles,
        try
            solutions = arrayfun(@(x,y) solver(x,y,mesh,angle,params), kxy,kz, 'UniformOutput', false);
            save solutions
            fprintf('Fitting solutions...\n');

            solutions = {cellfun(@(tsd) {fitter(tsd{1}(1,:),tsd{1}(2,:), 0.999, params), tsd{1}, tsd{2}}, solutions, 'UniformOutput', false)};
            fprintf('Omigosh, a solution set is actually done!');
            system('echo "A solution just finished on" `hostname` | mutt -s "A solution got did!" josh.holbrook@gmail.com');
        catch exception
            disp(['/!\ Shit broke /!\: ' exception.message ]);
            system(['echo "Shit broke on" `hostname` | mutt -s "Hey man your shit''s broke!--' exception.message '" josh.holbrook@gmail.com']);
        end
        %solutions
        mkdir(saveroot);
        save([saveroot 'solution-' num2str(angle)],'solutions','angle','params');
    end

    % Emails me when everything's done
    system('echo "You should check out your results on" `hostname` | mutt -s "Hey man your shit''s done!" josh.holbrook@gmail.com');
    system('touch down');
