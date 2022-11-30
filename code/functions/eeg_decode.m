function [d] = eeg_decode(data)
% pairwise video decoding
% trials are averaged within folds (k-fold CV) and randomly assigned to folds using specified number of permutations

%get data into right format
[datamatrix, condid] = eeg_preparerdm(data,0); %use 0 to keep all observations for decoding

%decode
dec = fl_decodesvm(datamatrix,condid, 'method', 'pairwise','numpermutation',10, 'kfold',2);

d = dec.d';  


end