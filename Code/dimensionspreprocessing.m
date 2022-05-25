
location = "C:/Users/alexc/OneDrive/Documents/Taiwan Classes/Second Semester/Brain Computer Interfaces/BCI Presentation and Project/SSVEP Projects/Wearable SSVEP BCI Database/Dataset/";
folder = "Raw_Datasets/";

matFiles = dir(location + folder +"*.mat") ;
N = length(matFiles); 
eeg_data = {};

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
%%
for a = 1:N
    data = eeg_data{1,a};
    % STARTS HERE:
    %order of data = (channel, points, electrode dry/wet, blocks, targets)
    
    subjects = data(:,125:625,:); % 125 is for 0.5 s , 625 is for 2.5 s
    new_subject = {};
    
    for i = 1:240
        new_subject = [new_subject,subjects(:,:,i)];
    end
    
    tic
    FFTpower = [];
    N = 240; % Total number of concatenated data points (all blocks, electrodes, and targets)
    Channels = 8; % 8 Channels in total
    raw_data = [];
    
    for j = 1:Channels
        for i = 1:N %or N in here 
            %This is to get the raw data in a 2-d array, if needed:
            raw_data(i+(N*(j-1)),:) = new_subject{1,i}(j,:);
        end
    end
    toc
    
    % New tests for FIR and then FFT:
    
    srate = 250;
    lowcutoff = 15;
    filtorder = 3*fix(srate/lowcutoff); %48th order
    
    s = struct('data', raw_data(:,:), 'srate', 250, 'trials', 1, 'event', 1, "epoch", []);
    [sub1_data] = pop_eegfilt(s,9,15,filtorder,0,0); %FIR
    %[sub1_data] = pop_eegfilt(sub1_data,9,10,filtorder,0,1); %FFT from pop_eegfilt
    
    %plot(sub1_data.data')
    
    trials = 240; % 240 trials
    for c = 1:8 %8 Channels in total
        for i = 1: trials
            [PB, freqs, times] = timefreq2004(sub1_data.data(i+(trials*(c-1)),:)', 250, 'wavelet', 0,...
            'freqs', [1 30], 'winsize', 256);
            PB = 10 * log10(PB .* conj(PB));
            %idx = (times>500 & times<2000);
            fft_fir(i+(trials*(c-1)),:) = mean(PB(:,:), 2); % The one we need
        end
    end
    
    save(location+"FFTs_from_matlab/cleaned_S00" + a +".mat",'fft_fir');
end
%%
for i = 1:120
plot(freqs,fft_fir(i,:));
hold on;
end
