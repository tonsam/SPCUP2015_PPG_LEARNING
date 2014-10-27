predictfname = input('predict result file(output of prediction:');
inputfname = input('data file(svm data file for prediction:):');
ft = fopen(inputfname, 'r');
fp = fopen(predictfname, 'r');

%str = fileread('tang_predict_54');
%disp(str);

wint = [];
winp = [];


line = fgetl(ft);
while ischar(line)
    reres = regexp(line, '^[0-9.]*', 'match');
    wint = [wint str2num(char(reres(1)))];
    line = fgetl(ft);
end

line = fgetl(fp);
while ischar(line)
    reres = regexp(line, '^[0-9.]*', 'match');
    winp = [winp str2num(char(reres(1)))];
    line = fgetl(fp);
end

x = linspace(0, 100, size(wint,2));
plot(x, wint, x, winp);

