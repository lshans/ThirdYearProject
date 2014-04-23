%%
%******************************************************************
function [TL] = ExtractCPSegments(Imgf, Mask) %#ok<*FNDEF>
%******************************************************************

RONH = size(Imgf,1)*9.85/100;
MaxVW = ceil(RONH*22.86/100);

TramThresh=0.00999; %0.15; %4*0.0125;  %  0.001
outerW=ceil(MaxVW/2);
innerW=0;
outerL=ceil(MaxVW);
innerL=outerL;

%Get tramline results
% Tramline - high level routine to perform tramline detection of blood vessels,
% returning a tram-line image.

% Tramline filter with given widths and length
TLOResponse = TramlineSingle( Imgf, outerW, outerL, innerW, innerL );
%figure; imshow(TLOResponse);

%this approch give the best results when the threshold equal 0.0045
TL = (TLOResponse > TramThresh) & Mask;

clear TLOResponse

% clean up a bit, remove a border region
% remove small spurs, thin: to clean up odd pixels after spur removal
TL = CleanupTramline(TL, Mask, floor(outerL*2/4));
% figure; imshow(TL);

return

%%
%******************************************************************
function TL = CleanupTramline(TL, Mask, outerL )

% clean up a bit 'fill'
SE = strel('disk', 3 );

%removes from segments that have fewer than P pixels
%TL = bwareaopen(TL, round(4*outerL));
%figure; imshow(TL);

TL = bwmorph( TL, 'thin', Inf ); % thin, to clean up odd pixels after spur removal
%figure; imshow(TL);

%removes from segments that have fewer than P pixels
TL = bwareaopen(TL, round(0.5*outerL));
%figure; imshow(TL);

TL = imclose( TL, SE ); % Performs morphological closing (dilation followed by erosion).
TL = bwmorph( TL, 'fill' ,Inf); %Fills isolated interior pixels (individual 0s that are surrounded by 1s)
TL = bwmorph( TL, 'thin', Inf ); % thin
%figure; imshow(TL);

%removes from segments that have fewer than P pixels
TL = bwareaopen(TL, outerL);
%figure; imshow(TL);

TL = TL & imerode(Mask,strel('disk', 10 ));

return

%%
%*********************************************************
function Result = EvaluateAlongSegmentsGroundTruth( SM, GTL, Mask) %#ok<*DEFNU>
% Evaluate along segment map performance against a ground-truth image
%for tramline and similar algorithms
% TP : True Positive; Correct Foreground
% VNL : Vascular Network "by length" Located
% FPM : False Positive Measurmed by "excess vessel length"
%*********************************************************

% Produce a skeletonized ground truth
GTs = bwmorph( GTL, 'thin', Inf );
%figure; imshow(GTs);

% Count number of pixels from the vessel map that are in the ground truth.
GTD = imdilate(GTL,strel('disk',3));
%figure; imshow(GTD);

% Count pixels in the ground truth
noPxlGT = sum( GTs(:) ); % = TP + FN

% Produce a skeletonized ground truth
SMs = bwmorph( SM, 'thin', Inf );
%figure; imshow(SMs);

% Count pixels in the Segment map
noPxlSM = sum( SMs(:) ); % = TP + FP

if ~isempty(Mask)
    TP = Mask & SMs & GTD;
else
    TP = SMs & GTD;
end
noTP = sum(TP(:));
noFN = noPxlGT - noTP;
noFP = noPxlSM - noTP;
s=size(SM);
noTN = s(1)*s(2)-noTP-noFP-noFN;

TPFP = noTP+noFP; %positiveResponse (TP+FP)
TPFN = noTP+noFN; %positiveReference (TP+FN)
FPTN = noFP+noTN; %negativeReference (FP+TN)
TPTN = noTP+noTN; %Correct (TP+TN)
Total = noTP+noTN+noFP+noFN;


Sensitivity = noTP/TPFN;
Specificity = noTN/FPTN;
Precision = noTP/TPFP;
Accuracy = TPTN/Total;

referenceLikelihood = TPFN/Total;
responseLikelihood =  TPFP/Total;
randomAccuracy = referenceLikelihood * responseLikelihood + (1 - referenceLikelihood) * (1 - responseLikelihood);
kappa = (Accuracy-randomAccuracy)/(1-randomAccuracy); %(p - e) / (1 - e)

Result = [Sensitivity Specificity Accuracy Precision kappa];
return