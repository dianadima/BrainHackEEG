% EEG data analysis script
% dataset: participant #6 from https://osf.io/hrmxn/ (Dima et al. 2021)
% action video stimuli

%% first: set paths

addpath(genpath(pwd))

dpath = '/cifs/teaching/share/datasets/BrainhackEEG-data'; 
eegfile = fullfile(dpath,'06','vid0006.eeg');    %file with EEG data
hdrfile = fullfile(dpath,'06','vid0006.vhdr');   %header file associated with EEG data
trlfile = fullfile(dpath,'p06_trials.mat');      %binary file with trial information (order of videos)

%% make sure fieldtrip is working
addpath('/cifs/teaching/share/software/fieldtrip')
ft_defaults

%% read and segment EEG data

%segment data into trials [-0.2 to 1 s around stimulus onset]
rawdata = eeg_readdata(hdrfile,eegfile);

%% baseline correction and high-pass filtering
cfg = []; %Fieldtrip uses cfg structures containing different parameters
cfg.demean = 'yes';                   %demean data
cfg.baselinewindow = [-0.2 0];        %use pre-trigger period for baselining
cfg.detrend = 'no';                

%apply high-pass filter
cfg.hpfilter = 'yes';                 %high-pass filter before artefact rejection to remove slow drifts
cfg.hpfreq = 0.1;                     %use a low threshold to avoid distorting temporal dynamics
cfg.hpfiltord = 3;                    %a lower filter order ensures filter stability

rawdata = ft_preprocessing(cfg,rawdata);

%% visualize data using databrowser
cfg = [];
cfg.continuous = 'no';
cfg.preproc.demean = 'no';
cfg.viewmode = 'vertical';
ft_databrowser(cfg, rawdata);

input('Press ENTER to continue ')
close

%% remove muscle artefacts based on an automatic thresholding procedure
cfg_art = []; %create a configuration to store artefact definitions
cfg_art.artfctdef.muscle.channel = 'EEG';
cfg_art.artfctdef.muscle.continuous = 'no';
cfg_art.artfctdef.muscle.cutoff = 15;         %z-score cutoff
cfg_art.artfctdef.muscle.bpfilter = 'yes';
cfg_art.artfctdef.muscle.bpfreq = [110 140];  %high freq filtering to detect muscle artefacts
cfg_art.artfctdef.muscle.bpfiltord = 8;       %filter order
cfg_art.artfctdef.muscle.hilbert = 'yes';
cfg_art.artfctdef.muscle.boxcar = 0.2;
cfg_art.artfctdef.muscle.artpadding = 0.1;    %pad the detected artefacts by 100 ms
cfg_art.artfctdef.muscle.interactive = 'no'; 

cfg_art = ft_artifact_muscle(cfg_art, rawdata);
cfg_art.artfctdef.reject = 'nan'; %reject trials by replacing them with NaNs
data = ft_rejectartifact(cfg_art, rawdata);

%save indices of trials with muscle artefacts
badtrl_msc = eeg_badtrialidx(cfg_art.artfctdef.muscle.artifact,rawdata);

%% reject high-variance trials/channels interactively
cfg = [];
cfg.method = 'summary'; %visualize outlier channels & trials and reject them interactively
cfg.keeptrial = 'nan';
data = ft_rejectvisual(cfg, data);

chan = data.label; %make a note of the channels we are keeping

%save indices of trials with too-high variance
badtrl_var = eeg_badtrialidx(data.cfg.artfctdef.summary.artifact,rawdata);

%% reject the trials containing artefacts

%this creates a vector telling us which are the bad trials
badtrial_idx = false(1720,1);
badtrial_idx(unique([badtrl_var; badtrl_msc])) = 1;

cfg = [];
cfg.trials = find(~badtrial_idx);
cfg.channel = chan;
data_clean = ft_preprocessing(cfg,rawdata);

%% run ICA to remove eye movement artefacts

%downsample data to speed up ICA
cfg = [];
cfg.resamplefs = 150;
cfg.detrend = 'no';
data_clean_ds = ft_resampledata(cfg, data_clean);

%compute the rank of the data to constrain number of components
data_cat = cat(2,data_clean_ds.trial{:});
data_cat(isnan(data_cat)) = 0;
num_comp = rank(data_cat);

%now run ICA
cfg= [];
cfg.method = 'runica';
cfg.numcomponent = num_comp;
comp = ft_componentanalysis(cfg, data_clean_ds);

%plot components with their time-courses
cfg = [];
cfg.layout = 'acticap-64ch-standard2';
cfg.viewmode = 'component';
cfg.continuous = 'yes';
cfg.blocksize = 60;
ft_databrowser(cfg, comp);

% plot topographies for first 16 components
figure
cfg = [];
cfg.component = 1:20;
cfg.layout    = 'acticap-64ch-standard2';
cfg.comment   = 'no';
ft_topoplotIC(cfg, comp)
pause(1)

%here give the component numbers to be removed, e.g. [1 2]
comp_rmv = input('Components to be removed (use square brackets if several): ');

close all

%this projects the artefactual components out of the original data
cfg = [];
cfg.unmixing = comp.unmixing;
cfg.topolabel = comp.topolabel;
cfg.demean = 'no';
comp_orig = ft_componentanalysis(cfg,data_clean);

cfg = [];
cfg.component = comp_rmv;
cfg.demean = 'no'; %note - data is demeaned by default
data = ft_rejectcomponent(cfg, comp_orig, data_clean);

clear data_clean_ds

%% visually check the dataset quality one final time
cfg = [];
cfg.preproc.demean = 'no';
cfg.viewmode = 'vertical';
ft_databrowser(cfg, data);

input('Press ENTER to continue: ')
close

%% low-pass filter and re-reference data
cfg.lpfilter = 'yes';
cfg.lpfreq = 100;

%re-reference data
cfg.reref      = 'yes';
cfg.refchannel = 'all';
cfg.implicitref = 'Cz';
cfg.refmethod  = 'median';

data = ft_preprocessing(cfg,data);

%% resample data - speeds up analysis
cfg = [];
cfg.detrend = 'no';
cfg.resamplefs = 500;
data = ft_resampledata(cfg,data);

%this adjusts our trial list to match the cleaned data
preproc.num_channels = length(data.label);
preproc.num_badtrial = sum(badtrial_idx);
preproc.idx_badtrial = badtrial_idx;
preproc.badtrial_variance = badtrl_var;
preproc.badtrial_muscle = badtrl_msc;

data = eeg_trialselect(data,preproc,trlfile);
save('data.mat','data')

%% timelock analysis
cfg = [];
timelock = ft_timelockanalysis(cfg,data);
eeg_ploterp(timelock) %plot ERP topography & timecourse

%% decode all pairs of videos
d = eeg_decode(data);
eeg_plotdecoding(d,data)
save('decoding_accuracy.mat','d')

%% check if AlexNet features correlate with brain patterns

%%requires DeepLearning toolbox in MATLAB
%%extract features from first layer of AlexNet --> captures low-level visual responses
%features = extract_cnn_features('alexnet',fullfile(dpath,'stimuli'),'pool1');

%load already extracted features
%distances between all stimuli have been calculated resulting in an RDM
load(fullfile(dpath,'alexnet_features.mat'),'rdm')

%get time-resolved correlation between brain patterns & AlexNet features
numtime = size(d,2); %number of time points
tcorr = nan(numtime,1);
for t = 1:numtime
    tcorr(t) = corr(d(:,t),rdm);
end

figure
plot(data.time{1},tcorr,'color','k','LineWidth',1.5)
xlim([-0.2 1])
xlabel('Time (s)'); ylabel('Correlation')
set(gca,'FontSize',18)
grid on

save('correlation_conv1.mat','tcorr')



