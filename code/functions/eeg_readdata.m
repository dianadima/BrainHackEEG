function [data] = eeg_readdata(hdrfile, eegfile)
%read and preprocess EEG data from action perception experiment
%trials are read based on stimulus onset, realigned to photodiode onsets,
%and epoched into -0.2 to 1 segments
%data is high-pass filtered at 0.1 Hz and re-referenced to average of mastoids
%D.C. Dima (diana.c.dima@gmail.com) Feb 2020

toi = [-0.2 1]; %duration of epoch of interest

%define trials and realign to photodiode onset
cfg = [];
cfg.headerfile = hdrfile;
cfg.datafile   = eegfile;
cfg.trialdef.eventtype = 'Stimulus';
cfg.trialdef.eventvalue = 'S  1';    %align trials to video onset
cfg.trialdef.prestim = abs(toi(1));
cfg.trialdef.poststim = 1.5;         %read in larger epochs to help with alignment to photodiode triggers
cfg = ft_definetrial(cfg);  
data = ft_preprocessing(cfg);
data = eeg_alignphoto(data, toi);    %realign trials to photodiode and cut into epochs of interest

cfg = [];
cfg.toilim = toi;
data = ft_redefinetrial(cfg,data);

%preprocess data
cfg = [];      
cfg.channel = {'all', '-Photodiode'}; %remove photodiode channel
data = ft_preprocessing(cfg,data);





end

