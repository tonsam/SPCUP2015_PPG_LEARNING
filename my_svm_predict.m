function [mse, corr_coeff, aae, target_label, out_label] = my_svm_predict(model, predict_file, output_file, indexes, use_lastpredict, lastpredict_num, past_acc_end, acc_num, peak_win_num)
% my_svm_predict calls libsvm to predict the input data.
%
% usage: 
%   [mse, corr_coeff] = my_svm_predict(model_file, predict_file, output_file, indexes)
% input: 
%   model_file    the .model file created by my_svm_predict
%   predict_file  new file name, stores formatted libsvm-format data
%   output_file   new file name, stores the output of svm-predict
%   indexes       the indexes vector to be predicted, e.g. [1:5], [12]
%   lastpredict_num  how many labels of past windows should be the features
%   past_acc_end  index of the last window whose acc is considered to the
%                 current window.--->[... 3 2 1 0(curr)]
%   acc_num       how many windows whose acc is considered, until
%                 past_acc_end
% output:
%   mse           mean-square error
%   corr_coeff    the square of correlation coeffient(corr^2)
%   aae           average absolute error
%   target_label  m*1 matrix of the target labels(ground truths)
%   out_label     m*1 matrix of the output labels

    if (nargin < 3)
        indexes = 1:12;
    end

    extract_features;
    save_groundtruths;
    load('features.mat');
    load('ground_truths.mat');
    load_rawdata;
    acc_features = extract_acc_features(0);
    
    f = fopen(predict_file, 'w+');
    lastlabels(1:lastpredict_num) = 72; % normal heart rate
    target_label = [];
    out_label = [];
    for i = indexes 
        
        % iteration init
        win = 1;
        sig_part = get_sig_part(rawdata{i}(2:6, :), win);
        while size(sig_part, 2) == 1000
            
            % for the first several windows or the windows which are
            % motionless, we get the peaks of them
            if win <= peak_win_num || is_motionless(sig_part(3:5, :))
                if win <= peak_win_num
                    %head = 1;
                    % for ssa test
                    head = ((win - 1) * 250 + 1) - 1000;
                    if (head < 1); head = 1; end;
                    tail = win * 250 + 750;
                else
                    head = ((win - 1) * 250 + 1) - 1000;
                    if (head < 1); head = 1; end;
                    tail = win * 250 + 750;
                end
                len = tail - head + 1;
                peak_num = 3;


                % (1) get fft peaks
                peaks{1} = get_peaks(abs(fft(rawdata{i}(2, head:tail), [], 2)), peak_num, 0.3) * 125/len * 60;
                peaks{2} = get_peaks(abs(fft(rawdata{i}(3, head:tail), [], 2)), peak_num, 0.3) * 125/len * 60;
                peaks_best{1} = lastlabels(1);
                peaks_best{2} = lastlabels(1);
                for p = 1:2
                    for j = 1:peak_num
                        if 50 < peaks{p}(j) && 180 > peaks{p}(j)
                            peaks_best{p} = peaks{p}(j);
                            break;
                        end
                    end
                end
                out_label_win1 = (peaks_best{1} + peaks_best{2}) / 2;
                
                
                % (2) learning
                % for every window, we get a set of features for ONE label
                feature(1,:,:) = fft_feature_fly(sig_part, lastlabels(1));

                if use_lastpredict
                    [labe_gt, inst] = features_to_svm_data(f, feature, ground_truth{i}(win), [1:2 8], 0, lastpredict_num, lastlabels, acc_features{i}, past_acc_end, acc_num, win);
                else
                    [labe_gt, inst] = features_to_svm_data(f, feature, ground_truth{i}(win), [1:2 8], 0, lastpredict_num, lastlabels, acc_features{i}, past_acc_end, acc_num, win);
                end
                [out_label_win2, ~, ~] = svmpredict(labe_gt, inst, model, '-q');
                
                % output the mean value from peak and prediction
                out_label_win = (out_label_win1 + out_label_win2) / 2;
            else
                % for every window, we get a set of features for ONE label
                feature(1,:,:) = fft_feature_fly(sig_part, lastlabels(1));

                if use_lastpredict
                    [labe_gt, inst] = features_to_svm_data(f, feature, ground_truth{i}(win), [1:2 8], 0, lastpredict_num, lastlabels, acc_features{i}, past_acc_end, acc_num, win);
                else
                    [labe_gt, inst] = features_to_svm_data(f, feature, ground_truth{i}(win), [1:2 8], 0, lastpredict_num, lastlabels, acc_features{i}, past_acc_end, acc_num, win);
                end
                [out_label_win, ~, ~] = svmpredict(labe_gt, inst, model, '-q');
            end
            % tracking
            out_label_win = track(out_label_win, lastlabels(1));
            
            lastlabels = circshift(lastlabels, [2, 1]); % dim:2 shift:1(to the right)
            lastlabels(1) = out_label_win;
            out_label = [out_label; out_label_win];
            target_label = [target_label; ground_truth{i}(win)];
            
            % to the next iteration
            win = win + 1;
            sig_part = get_sig_part(rawdata{i}(2:6, :), win);
        end
    end
    fclose(f);

    [mse, corr_coeff, aae] = my_calc_results(target_label, out_label);
    fprintf(1, 'predict : mse %f , corr %f , aae %f\n', mse, corr_coeff, aae);
end


function sig_part = get_sig_part(sig, win)
    window_diff_sec = 2;
    window_size = 1000;
    fps = 125;
    window_sec = 8;
    if size(sig, 2) >= win * 250 + 750
        sig_part(:,:) = sig(:,window_diff_sec*fps*(win-1)+1:window_diff_sec*fps*(win-1)+window_size);%for 2PPG, 3 accel channels
    else
        sig_part = [];
    end
end


function out_label_win = track(curr_label, last_label)
    if curr_label - last_label > 10
        out_label_win = last_label + 10;
    elseif curr_label - last_label < -10
        out_label_win = last_label - 10;
    else
        out_label_win = curr_label;
    end
end
