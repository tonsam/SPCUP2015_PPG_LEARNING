function [ dim , feature ] = fft_feature( GT , SIG )
%FFT_FEATURE Summary of this function goes here
%   Detailed explanation goes here
    fps = 125;
    count = size(GT,1);
    window_sec = 8;
    window_diff_sec = 2;
    window_size = window_sec*fps;%l000
    
    hr_high = 4;
    hr_low = 0.75;
    dim_high = ceil(hr_high*window_sec+1);
    dim_low = floor(hr_low*window_sec+1);
    dim = dim_high-dim_low+1;
    feature = zeros([count 5 dim]);
    
    for c = 1 : count %for all window
        fprintf('win %d ', c);
        sig_part = zeros([5 window_size]);
        sig_part(:,:) = SIG(2:6,window_diff_sec*fps*(c-1)+1:window_diff_sec*fps*(c-1)+window_size);%for 2PPG, 3 accel channels
        
        % SSA
        L = 400;
        [sig_part(1,:),~,~] = my_ssa(sig_part(1,:), sig_part(3:5, :), L, GT(c));
        [sig_part(2,:),~,~] = my_ssa(sig_part(2,:), sig_part(3:5, :), L, GT(c));
        
        %FFT
        fft_sig_part = abs(fft(sig_part,[],2));
        
        %Periodogram
%         for i = 1:5
%             fft_sig_part(i,:) = periodogram(sig_part(i, :), rectwin(window_size), window_size, fps);
%         end
        
        
        feature(c,:,:) = fft_sig_part(:,dim_low:dim_high);
        for f = 1 : 5
            mean_ = mean(feature(c, f, :));
            if mean_ ~= 0
                feature(c,f,:) = feature(c,f,:)/mean(feature(c,f,:));
            end
        end
    end
    fprintf('\n');
end

