% To Run the FFT function (timefreq2004) we need to have previously ran
% timefreq2004.m file.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Download the data from the original .mat files from
% http://bci.med.tsinghua.edu.cn/download.html, [Wearable SSVEP BCI Dataset]
% into a single folder and then extract that data into "eeg_data" variable.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

location = "C:/Users/alexc/OneDrive/Documents/Taiwan Classes/Second Semester/Brain Computer Interfaces/BCI Presentation and Project/SSVEP Projects/Wearable SSVEP BCI Database/Dataset/";
folder = "Raw_Datasets/";

matFiles = dir(location + folder +"*.mat") ;
N = length(matFiles); 
eeg_data = {};


N = 10; % momentarily only get these amount of files


for i = 1:N
   if(i<10)
     load(location + folder +'S00'+i+'.mat')
   elseif(i<100)
     load(location + folder +'S0'+i+'.mat') % 10 to 99
   else
     load(location + folder +'S'+i+'.mat') % 100 to 102
   end
   eeg_data = [eeg_data, data];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Looping through the 102 eeg_data files generated from the 102
% subjects (or N subjects depending on how many files we want), and get the
% FIR and FFT for each files and generate a resulting .mat file that can be
% use for Machine Learning Classfication.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

all_subjects_fir_ff = {};

for a = 1:N
    %Selecting just the file we want through the index on "a":
    data = eeg_data{1,a};
    
    %Since the order of data is = (channel, points, electrode dry/wet, blocks, targets)
    %when we splice it like data(:,a:b,:), we are selecting ALL the
    %channels (8), all the data points from a to b (up to 710 data points),
    %and all the 3 order flatten dimensions into a single 1. So we are
    %getting all the [Electrode dry/wet, Blocks, Targets] into a single
    %dimension of data.

    % From the original readme.pdf file: 
    % 
    % "The data length of 2.84 seconds (i.e. 2.84??250 = 710 time points) include 0.5 s before 
    %  stimulus onset, 2 s for stimulation, 0.14 s visual latency, and 0.2 s after stimulus offset. 
    %  To keep all original information, the data epochs were directly
    %  extracted". 

    % The first 0.5 s are not necessary, so we select from 0.5s to 2.84s:
    % For 0.5s , starting_second = 125
    % For 2.84 seconds, ending_second = 710

    starting_data_point = 125;
    ending_data_point = 710;

    %Reducing 5 dimensions into 3:

    data_3d = data(:,starting_data_point:ending_data_point,:); 
   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Getting an array of all the EEG trials from all the N files we selected
    %before, selecting now only 3 values, Channels and Data Points, and the
    %other 3 dimensions previously flattened into one. To do this get all 
    % 240 trials collected from before 
    % (12 targets x 10 blocks x 2 types of electrodes) that 
    % are nested in the third dimension of data_2d(:,:,x):
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    eeg_trials = {};
    for i = 1:240
        % 240 EEG trials for 1 subject:
        eeg_trials = [eeg_trials,data_3d(:,:,i)];
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Getting an array of all the raw data from all the trials we selected
    %before. Each row is an independent trial with the 
    %(starting_data_point:ending_data_point) from a specific channel. 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    N = 240; % Total number of trials (all blocks, electrodes, and targets)
    Channels = 8; % 8 Channels in total
    raw_data = [];
    
    for j = 1:Channels
        for i = 1:N %or N in here 
            %This is to get the raw data in a 2-d array, if needed:
            %Every 240 rows is 240 trials for 1 channel. So the length of
            % raw_data is 240 trials x 8 channels = 1920 rows.
            raw_data(i+(N*(j-1)),:) = eeg_trials{1,i}(j,:);
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Performing FIR:
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    srate = 250;
    lowcutoff = 15;
    filtorder = 3*fix(srate/lowcutoff); %48th order
    FIR = 1 ; % 1 for FIR, 0 for FFT. FFT not working that well?
    
    s = struct('data', raw_data(:,:), 'srate', 250, 'trials', 1, 'event', 1, "epoch", []);
    [sub1_data] = pop_eegfilt(s,9,15,filtorder,0,FIR); %FIR.

%     signal = sub1_data.data(i,:);
%     signal=signal-mean(signal); 

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Previous FFT (not working that well?):
    %     trials = 240; % 240 trials
    %     for c = 1:8 %8 Channels in total
    %         for i = 1: trials
    %             [PB, freqs, times] = timefreq2004(sub1_data.data(i+(trials*(c-1)),:)', 250, 'wavelet', 0,...
    %             'freqs', [1 30], 'winsize', 256);
    %             PB = 10 * log10(PB .* conj(PB));
    %             %idx = (times>500 & times<2000);
    %             fft_fir(i+(trials*(c-1)),:) = mean(PB(:,:), 2); % The one we need
    %         end
    %     end

    % for i = 1:10
    % plot(freqs,fft_fir(i,:));
    % hold on;
    % end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Performing FFT:
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %Signal info:
    Fs = 250; % sampling frequency
    seconds = (ending_data_point - starting_data_point)/Fs; % to get the amount of seconds if we want to plot;
    Ts = 1/Fs; % time step or sampling period
    dt = 0:Ts:seconds;

    all_fft = {};  % FFTs for 1920 trials (240 trials x 8 channels) for 1 subject
    all_xfft = {}; % XFFT, so the index in the x axis

    trials = 240; % 240 trials
    for c = 1:8 %8 Channels in total
        for i = 1: trials
        
        % Helps to take away the DC mean component 0 Hz:
        signal = sub1_data.data(i+(trials*(c-1)),:);
        signal=signal-mean(signal);
        %signal = detrend(signal,'constant');
        
        %%FFT:

        nfft = length(signal); % length of time domain signal
        nfft2 = 2^nextpow2(nfft); % length of the signal in power 2
        ff = fft(signal,nfft2);
        fff = ff(1:nfft2/2); % to avoid the mirrored signal
        %fff = fff/max(fff); %  normalize the amplitude
        xfft = Fs*(0:nfft2/2-1)/nfft2;
        
        all_fft = [all_fft, abs(fff)];
        all_xfft = [all_xfft,xfft];
        end
    end

   % Doesn't really save the FFT of all subjects correctly? (Not really
   % needed anyways, since each subject is saved in a separate .mat file.)
   all_subjects_fir_ff = [all_subjects_fir_ff,all_fft]; % Just in case, but not really needed.

   destination_folder = "New_FFTs_matlab"; %for some testing while i don't use the whole .mat original files (just a subset)
   %destination_folder = "FFTs_from_matlab"; my final folder

   if(i<10)
     save(location+destination_folder+"/cleaned_S00" + a +".mat",'all_fft');
   elseif(i<100)
     save(location+destination_folder+"/cleaned_S0" + a +".mat",'all_fft');
   else
     save(location+destination_folder+"/cleaned_S" + a +".mat",'all_fft');
   end
end

%%
for i = 1:12
index = i; %index of FFT to plot, 1 to 1920. (for 1 subject). If you want to plot of multiple
% subjects and not the last one in memory, use all_subjects_fir_ff{1,i}{(1,index}.
fft_to_plot = all_fft{1,index};
signal = sub1_data.data(index,:);

subplot(2,1,1);
plot(dt,signal,'b');
xlabel('Time [s]');
ylabel('Amplitude (V)');
title('Time Domain Signal');
hold on;

subplot(2,1,2);
plot(xfft,fft_to_plot,'b');
%xlim([0 50]);
%ylim([0 1]);
xlabel('Frequency [Hz]');
ylabel('Normalized Amplitude');
title('Frequency Domain Signal');
hold on;

end

