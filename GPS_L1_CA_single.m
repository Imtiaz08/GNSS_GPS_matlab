% ����˫����ǰ������45s�����ߣ��������Ƿ���ȷ��������Ԥ������
% ��������ȷ�ᵼ����ķ���ʱ�䲻��ȷ��Ӱ�춨λ
% ��*�ĳ���ο��Ե�������
% ʱ�ӡ�Ƶ�ʷ�������׼ȷGPSʱ�����ж�λ
% ����һ��һֱ�ɼ������ǣ��õ���������������ע�͵���ͼָ��

clear
clc

%% ��ʱ��ʼ
% 4������10s���ݺ�ʱԼ16s
tic

%% ������־�ļ�
fclose('all'); %�ر�֮ǰ�򿪵������ļ�
logID = fopen('log.txt', 'w'); %������־�ļ���ʱ��˳�����־��

%% �ļ�·��
file_path = '.\data\7_5\data_20190705_164525_ch1.dat';
plot_gnss_file(file_path); %��ʾǰ0.1s����
sample_offset = 0*4e6; %����ǰ���ٸ�������

%% ����ʱ��
msToProcess = 40*1000; %������ʱ��
sampleFreq = 4e6; %���ջ�����Ƶ��

%% �ο�λ��
p0 = [45.730952, 126.624970, 212]; %2A¥��

%% ���ݻ���
buffBlkNum = 40;                     %�������ݻ����������Ҫ��֤����ʱ�洢ǡ�ô�ͷ��ʼ��
buffBlkSize = 4000;                  %һ����Ĳ���������1ms��
buffSize = buffBlkSize * buffBlkNum; %�������ݻ����С
buff = zeros(2,buffSize);            %�������ݻ��棬��һ��I���ڶ���Q
buffBlkPoint = 0;                    %���ݸ����ڼ���棬��0��ʼ
buffHead = 0;                        %�������ݵ���ţ�buffBlkSize�ı���

%% ��ȡ�ļ�ʱ��
tf = sscanf(file_path((end-22):(end-8)), '%4d%02d%02d_%02d%02d%02d')'; %�����ļ���ʼ����ʱ�䣨����ʱ�����飩
[tw, ts] = gps_time(tf); %tw��GPS������ts��GPS��������
ta = [ts,0,0] + sample2dt(sample_offset, sampleFreq); %��ʼ�����ջ�ʱ�䣬[s,ms,us]
ta = time_carry(round(ta,2)); %ȡ��

%% ���������ȡ��ǰ���ܼ��������ǣ�*��
% svList = [6;12;17;19];
% svList = 2;
svList = gps_constellation(tf, p0);
svN = length(svList);

%% Ϊÿ�ſ��ܼ��������Ƿ������ͨ��
channels = repmat(GPS_L1_CA_channel_struct(), svN,1); %ֻ�����˳���������Ϣ��Ϊ��
for k=1:svN
    channels(k).PRN = svList(k); %ÿ��ͨ�������Ǻ�
    channels(k).state = 0; %״̬δ����
end

%% Ԥ������
ephemeris_file = ['./ephemeris/',file_path((end-22):(end-8)),'.mat'];
if exist(ephemeris_file, 'file')
    load(ephemeris_file); %�������ڣ����������ļ�������������Ϊephemeris������Ϊ�У���������������Ϊion
else
    ephemeris = NaN(26,32); %���������ڣ����ÿյ�����
    ion = NaN(1,8); %�յĵ�������
end
for k=1:svN
    PRN = svList(k);
    channels(k).ephemeris = ephemeris(:,PRN); %Ϊͨ����������ֵ
    if ~isnan(ephemeris(1,PRN)) %�������ĳ�����ǵ���������ӡ��־
        fprintf(logID, '%2d: Load ephemeris.\r\n', PRN); %�᷵���ֽ���
    end
end

%% �������ٽ���洢�ռ�
% ������msToProcess�У�ÿ����һ�����һ�ν�������ɾ���������
trackResults = repmat(trackResult_struct(msToProcess), svN,1);
for k=1:svN
    trackResults(k).PRN = svList(k);
end

%% ���ջ�״̬
receiverState = 0; %���ջ�״̬��0��ʾδ��ʼ����ʱ�仹���ԣ�1��ʾʱ���Ѿ�У��
deltaFreq = 0; %ʱ�Ӳ���Ϊ�ٷֱȣ������1e-9������1500e6Hz�Ĳ����1.5Hz
dtpos = 10; %��λʱ������ms
tp = [ta(1),0,0]; %tpΪ�´ζ�λʱ��
tp(2) = (floor(ta(2)/dtpos)+1) * dtpos; %�ӵ��¸���Ŀ��ʱ��
tp = time_carry(tp); %��λ

%% �������ջ�����洢�ռ�
% ����msToProcess/dtpos�У����ջ���ʼ����ÿdtpos ms���һ�Σ����ɾ���������
output_ta = zeros(msToProcess/dtpos,1); %ʱ�䣬ms
output_pos = zeros(msToProcess/dtpos,8); %��λ��[λ�á��ٶȡ��Ӳ��Ƶ��]
output_sv = zeros(svN,8,msToProcess/dtpos); %������Ϣ��[λ�á�α�ࡢ�ٶȡ�α����]
output_df = zeros(msToProcess/dtpos,1); %�����õ���Ƶ��˲������Ƶ�
no = 1; %ָ��ǰ�洢��

%% ���ļ�������������
fileID = fopen(file_path, 'r');
fseek(fileID, round(sample_offset*4), 'bof'); %��ȡ�����ܳ����ļ�ָ���Ʋ���ȥ
if int64(ftell(fileID))~=int64(sample_offset*4)
    error('Sample offset error!');
end
f = waitbar(0, ['0s/',num2str(msToProcess/1000),'s']);

%% �źŴ���
for t=1:msToProcess %�����ϵ�ʱ�䣬�Բ�����������
    % ���½�����
    if mod(t,1000)==0 %1s����
        waitbar(t/msToProcess, f, [num2str(t/1000),'s/',num2str(msToProcess/1000),'s']);
    end
    
    % �����ݣ�ÿ10s������1.2s��
    buff(:,buffBlkPoint*buffBlkSize+(1:buffBlkSize)) = double(fread(fileID, [2,buffBlkSize], 'int16')); %ȡ���ݣ������������������
    buffBlkPoint = buffBlkPoint + 1;
    buffHead = buffBlkPoint * buffBlkSize;
    if buffBlkPoint==buffBlkNum
        buffBlkPoint = 0; %�����ͷ��ʼ
    end
    
	%% ���½��ջ�ʱ��
    % ��ǰ���һ�������Ľ��ջ�ʱ��
    sampleFreq_real = sampleFreq * (1+deltaFreq); %��ʵ�Ĳ���Ƶ��
    ta = time_carry(ta + sample2dt(buffBlkSize, sampleFreq_real));
    
    %% ����
    % ÿ1s�Ĳ���������һ��
    if mod(t,1000)==0
        for k=1:svN %�������п��ܼ���������
            if channels(k).state==0 %���ͨ��δ��������Լ���
                [acqResult, peakRatio] = GPS_L1_CA_acq_one(svList(k), buff(:,(end-2*8000+1):end)); %2ms���ݲ���
                if ~isempty(acqResult) %�ɹ�����
                    channels(k) = GPS_L1_CA_channel_init(channels(k), acqResult, t*buffBlkSize, sampleFreq); %����ͨ��
                    fprintf(logID, '%2d: Acquired at %ds, peakRatio=%.2f\r\n', svList(k), t/1000, peakRatio); %��ӡ������־
                end
            end
        end
    end
    
    %% ����
    for k=1:svN %��k��ͨ��
        if channels(k).state~=0 %���ͨ��������и���
            while 1
                % �ж��Ƿ��������ĸ�������
                if mod(buffHead-channels(k).trackDataHead,buffSize)>(buffSize/2)
                    break
                end
                % ����ٽ����ͨ��������
                n = trackResults(k).n;
                trackResults(k).dataIndex(n,:)    = channels(k).dataIndex;
                trackResults(k).ts0(n,:)          = channels(k).ts0;
                trackResults(k).remCodePhase(n,:) = channels(k).remCodePhase;
                trackResults(k).codeFreq(n,:)     = channels(k).codeFreq;
                trackResults(k).remCarrPhase(n,:) = channels(k).remCarrPhase;
                trackResults(k).carrFreq(n,:)     = channels(k).carrFreq;
                % ��������
                trackDataHead = channels(k).trackDataHead;
                trackDataTail = channels(k).trackDataTail;
                if trackDataHead>trackDataTail
                    [channels(k), I_Q, disc, bitStartFlag] = ...
                        GPS_L1_CA_track(channels(k), sampleFreq_real, buffSize, buff(:,trackDataTail:trackDataHead), logID); %����Ƶ���е���Ӱ��
                else
                    [channels(k), I_Q, disc, bitStartFlag] = ...
                        GPS_L1_CA_track(channels(k), sampleFreq_real, buffSize, [buff(:,trackDataTail:end),buff(:,1:trackDataHead)], logID);
                end
                % ����ٽ�������ٽ����
                trackResults(k).I_Q(n,:)          = I_Q;
                trackResults(k).disc(n,:)         = disc;
                trackResults(k).bitStartFlag(n,:) = bitStartFlag;
                trackResults(k).CN0(n,:)          = channels(k).CN0;
                trackResults(k).carrAcc(n,:)      = channels(k).carrAcc;
                trackResults(k).Px(n,:)           = sqrt(diag(channels(k).Px)')*3;
                trackResults(k).n                 = n + 1;
            end
        end
    end
    
    %% ���Ŀ��ʱ���Ƿ񵽴�
    dtp = (ta(1)-tp(1)) + (ta(2)-tp(2))/1e3 + (ta(3)-tp(3))/1e6; %��ǰ����ʱ���붨λʱ��֮�>=0ʱ��ʾ��ǰ����ʱ���Ѿ�����򳬹���λʱ��
    
    %% ��λ
    if dtp>=0
        %--------����������Ϣ
        sv = NaN(svN,8);
        for k=1:svN
            if channels(k).state==2 %�������ͨ��״̬���Ը��ٵ���ͨ������������Ϣ��[λ�á�α�ࡢ�ٶȡ�α����]
                dn = mod(buffHead-channels(k).trackDataTail+1, buffSize) - 1; %trackDataTailǡ�ó�ǰbuffHeadһ��ʱ��dn=-1
                dtc = dn / sampleFreq_real; %��ǰ����ʱ������ٵ��ʱ���
                carrFreq = channels(k).carrFreq + 1575.42e6*deltaFreq; %��������ز�Ƶ��
                codeFreq = (carrFreq/1575.42e6+1)*1.023e6; %ͨ���ز�Ƶ�ʼ������Ƶ��
                codePhase = channels(k).remCodePhase + (dtc-dtp)*codeFreq; %��λ������λ
                ts0 = [floor(channels(k).ts0/1e3), mod(channels(k).ts0,1e3), 0] + [0, floor(codePhase/1023), mod(codePhase/1023,1)*1e3]; %��λ����뷢��ʱ��
                [sv(k,:),~] = sv_ecef(channels(k).ephemeris, tp, ts0); %����������������[λ�á�α�ࡢ�ٶ�]
                sv(k,8) = -carrFreq/1575.42e6*299792458;%�ز�Ƶ��ת��Ϊ�ٶ�
            end
        end
        %--------��λ
        sv_visible = sv(~isnan(sv(:,1)),:); %��ȡ�ɼ�����
        pos = pos_solve(sv_visible); %��λ���������4�����Ƿ���8��NaN
        %--------����ʼ��
        if receiverState==0
            if ~isnan(pos(7)) %�ӲΪNaN
                if abs(pos(7))>0.1e-3 %�Ӳ����0.1ms���������ջ�ʱ��
                    ta = ta - sec2smu(pos(7)); %ʱ������
                    ta = time_carry(ta);
                    tp(1) = ta(1); %�����´ζ�λʱ��
                    tp(2) = (floor(ta(2)/dtpos)+1) * dtpos;
                    tp = time_carry(tp);
                else %�Ӳ�С��0.1ms����ʼ������
                    receiverState = 1;
                end
            end
        end
        %--------���ջ�����ɳ�ʼ��
        if receiverState==1
            %--------ʱ�ӷ�������
            if ~isnan(pos(7)) %�ӲΪNaN
                % Ҫ��֤��Ƶ����������Ƶ��Ҫ���ڻ�·����
                deltaFreq = deltaFreq + 10*pos(8)*dtpos/1000; %��Ƶ���ۼ�
                ta = ta - 10*sec2smu(pos(7))*dtpos/1000; %ʱ�����������Բ��ý�λ�����´θ���ʱ��λ��
            end
            %--------�洢���
            output_ta(no) = tp(1)*1000 + tp(2); %ʱ�����ms
            output_pos(no,:) = pos;
            output_sv(:,:,no) = sv;
            output_df(no) = deltaFreq;
            no = no + 1;
        end
    end
    
    %% �����´�Ŀ��ʱ��
    if dtp>=0
        tp = time_carry(tp + [0,dtpos,0]);
    end
    
end

%% �ر��ļ����رս�����
fclose(fileID);
fclose(logID);
close(f);

%% ɾ���հ�����
for k=1:svN
    trackResults(k) = trackResult_clean(trackResults(k));
end
output_ta(no:end) = [];
output_pos(no:end,:) = [];
output_sv(:,:,no:end) = [];
output_df(no:end) = [];

%% ��ӡͨ����־��*��
clc
print_log('log.txt', svList);

%% ��������
% ÿ�������궼�ᱣ�棬���������Զ����
for k=1:svN
    PRN = channels(k).PRN;
    if ~isnan(channels(k).ephemeris(1)) && isnan(ephemeris(1,PRN)) %ͨ���������������������ļ���û��
        ephemeris(:,PRN) = channels(k).ephemeris; %��������
    end
end
save(ephemeris_file, 'ephemeris', 'ion');

%% ��ͼ��*��
for k=1:svN
    if trackResults(k).n==1 %����û���ٵ�ͨ��
        continue
    end
    
    % ����������
    screenSize = get(0,'ScreenSize'); %��ȡ��Ļ�ߴ�
    if screenSize(3)==1920 %������Ļ�ߴ����û�ͼ��Χ
        figure('Position', [390, 280, 1140, 670]);
    elseif screenSize(3)==1368
        figure('Position', [114, 100, 1140, 670]);
    else
        error('Screen size error!')
    end
    ax1 = axes('Position', [0.08, 0.4, 0.38, 0.53]);
    hold(ax1,'on');
    axis(ax1, 'equal');
    title(['PRN = ',num2str(svList(k))])
    ax2 = axes('Position', [0.53, 0.7 , 0.42, 0.25]);
    hold(ax2,'on');
    ax3 = axes('Position', [0.53, 0.38, 0.42, 0.25]);
    hold(ax3,'on');
    grid(ax3,'on');
    ax4 = axes('Position', [0.53, 0.06, 0.42, 0.25]);
    hold(ax4,'on');
    grid(ax4,'on');
    ax5 = axes('Position', [0.05, 0.06, 0.42, 0.25]);
    hold(ax5,'on');
    grid(ax5,'on');
    
    % ��ͼ
    plot(ax1, trackResults(k).I_Q(1001:end,1),trackResults(k).I_Q(1001:end,4), 'LineStyle','none', 'Marker','.') %I/Qͼ
    plot(ax2, trackResults(k).dataIndex/sampleFreq, trackResults(k).I_Q(:,1)) %I_Pͼ
    index = find(trackResults(k).CN0~=0);
    plot(ax3, trackResults(k).dataIndex(index)/sampleFreq, trackResults(k).CN0(index), 'LineWidth',2) %����ȣ�ֻ����Ϊ0��
    plot(ax4, trackResults(k).dataIndex/sampleFreq, trackResults(k).carrFreq, 'LineWidth',1.5) %�ز�Ƶ��
    plot(ax5, trackResults(k).dataIndex/sampleFreq, trackResults(k).carrAcc) %���߷�����ٶ�
    
%     index = find(trackResults(k).bitStartFlag==double('H')); %Ѱ��֡ͷ�׶Σ���ɫ��
%     plot(ax2, trackResults(k).dataIndex(index)/sampleFreq, trackResults(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','m')
%     index = find(trackResults(k).bitStartFlag==double('C')); %У��֡ͷ�׶Σ���ɫ��
%     plot(ax2, trackResults(k).dataIndex(index)/sampleFreq, trackResults(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','b')
%     index = find(trackResults(k).bitStartFlag==double('E')); %���������׶Σ���ɫ��
%     plot(ax2, trackResults(k).dataIndex(index)/sampleFreq, trackResults(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','r')

    % ����������
    set(ax2, 'XLim',[0,msToProcess/1000])
    set(ax3, 'XLim',[0,msToProcess/1000])
    set(ax3, 'YLim',[30,60]) %�������ʾ��Χ��Ϊ�˺ÿ�
    set(ax4, 'XLim',[0,msToProcess/1000])
    set(ax5, 'XLim',[0,msToProcess/1000])
end

clearvars k screenSize ax1 ax2 ax3 ax4 ax5 index

%% ���������*��
clearvars -except sampleFreq msToProcess ...
                  p0 tf svList svN ...
                  channels trackResults ...
                  output_ta output_pos output_sv output_df ...
                  ion
              
save result_single.mat

%% ��ʱ����
toc