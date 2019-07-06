% GPS˫���߶�λ���˳���
% ʱ�ӡ�Ƶ�ʷ�������׼ȷGPSʱ�����ж�λ������

clear
clc

%% ��ʱ��ʼ
tic

%% ������־�ļ�
fclose('all'); %�ر�֮ǰ�򿪵������ļ�
logID_A = fopen('logA.txt', 'w'); %������־�ļ���ʱ��˳�����־��
logID_B = fopen('logB.txt', 'w');

%% �ļ�·��
file_path_A = '.\data\7_2\data_20190702_111609_ch1.dat';
file_path_B = [file_path_A(1:(end-5)),'2.dat'];
plot_gnss_file(file_path_A); %��ʾǰ0.1s����
plot_gnss_file(file_path_B);
sample_offset = 0*4e6; %����ǰ���ٸ�������

%% ����ʱ��
msToProcess = 60*1000; %������ʱ��
sampleFreq = 4e6; %���ջ�����Ƶ��

%% �ο�λ��
p0 = [45.730952, 126.624970, 212]; %2A¥��

%% ���ݻ���
buffBlkNum = 40;                     %�������ݻ����������Ҫ��֤����ʱ�洢ǡ�ô�ͷ��ʼ��
buffBlkSize = 4000;                  %һ����Ĳ���������1ms��
buffSize = buffBlkSize * buffBlkNum; %�������ݻ����С
buff_A = zeros(2,buffSize);          %�������ݻ��棬��һ��I���ڶ���Q
buff_B = zeros(2,buffSize);
buffBlkPoint = 0;                    %���ݸ����ڼ���棬��0��ʼ
buffHead = 0;                        %�������ݵ���ţ�buffBlkSize�ı���

%% ��ȡ�ļ�ʱ��
tf = sscanf(file_path_A((end-22):(end-8)), '%4d%02d%02d_%02d%02d%02d')'; %�����ļ���ʼ����ʱ�䣨����ʱ�����飩
[tw, ts] = gps_time(tf); %tw��GPS������ts��GPS��������
ta = [ts,0,0] + sample2dt(sample_offset, sampleFreq); %��ʼ�����ջ�ʱ�䣬[s,ms,us]
ta = time_carry(round(ta,2)); %ȡ��

%% ���������ȡ��ǰ���ܼ��������ǣ�*��
% svList = [2;6;12];
svList = gps_constellation(tf, p0);
svN = length(svList);

%% Ϊÿ�ſ��ܼ��������Ƿ������ͨ��
channels_A = repmat(GPS_L1_CA_channel_struct(), svN,1);
channels_B = repmat(GPS_L1_CA_channel_struct(), svN,1);
for k=1:svN
    channels_A(k).PRN = svList(k);
    channels_A(k).state = 0; %״̬δ����
    channels_B(k).PRN = svList(k);
    channels_B(k).state = 0; %״̬δ����
end

%% Ԥ������
ephemeris_file = ['./ephemeris/',file_path_A((end-22):(end-8)),'.mat'];
if exist(ephemeris_file, 'file')
    load(ephemeris_file); %�������ڣ����������ļ�������������Ϊephemeris������Ϊ�У���������������Ϊion
else
    ephemeris = NaN(26,32); %���������ڣ����ÿյ�����
    ion = NaN(1,8); %�յĵ�������
end
for k=1:svN
    PRN = svList(k);
    channels_A(k).ephemeris = ephemeris(:,PRN); %Ϊͨ����������ֵ
    channels_B(k).ephemeris = ephemeris(:,PRN);
    if ~isnan(ephemeris(1,PRN)) %�������ĳ�����ǵ���������ӡ��־
        fprintf(logID_A, '%2d: Load ephemeris.\r\n', PRN);
        fprintf(logID_B, '%2d: Load ephemeris.\r\n', PRN);
    end
end

%% �������ٽ���洢�ռ�
% ������msToProcess�У�ÿ����һ�����һ�ν�������ɾ���������
trackResults_A = repmat(trackResult_struct(msToProcess), svN,1);
trackResults_B = repmat(trackResult_struct(msToProcess), svN,1);
for k=1:svN
    trackResults_A(k).PRN = svList(k);
    trackResults_B(k).PRN = svList(k);
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
output_dphase = NaN(msToProcess/dtpos,svN); %��λ��
no = 1; %ָ��ǰ�洢��

%% ���ļ�������������
% �ļ�A
fileID_A = fopen(file_path_A, 'r');
fseek(fileID_A, round(sample_offset*4), 'bof');
if int64(ftell(fileID_A))~=int64(sample_offset*4)
    error('Sample offset error!');
end
% �ļ�B
fileID_B = fopen(file_path_B, 'r');
fseek(fileID_B, round(sample_offset*4), 'bof');
if int64(ftell(fileID_B))~=int64(sample_offset*4)
    error('Sample offset error!');
end
% ������
f = waitbar(0, ['0s/',num2str(msToProcess/1000),'s']);

%% �źŴ���
for t=1:msToProcess
    % ���½�����
    if mod(t,1000)==0 %1s����
        waitbar(t/msToProcess, f, [num2str(t/1000),'s/',num2str(msToProcess/1000),'s']);
    end
    
    % ������
    buff_A(:,buffBlkPoint*buffBlkSize+(1:buffBlkSize)) = double(fread(fileID_A, [2,buffBlkSize], 'int16')); %����A
    buff_B(:,buffBlkPoint*buffBlkSize+(1:buffBlkSize)) = double(fread(fileID_B, [2,buffBlkSize], 'int16')); %����B
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
            %====����A
            if channels_A(k).state==0 %���ͨ��δ��������Լ���
                [acqResult, peakRatio] = GPS_L1_CA_acq_one(svList(k), buff_A(:,(end-2*8000+1):end)); %2ms���ݲ���
                if ~isempty(acqResult) %�ɹ�����
                    channels_A(k) = GPS_L1_CA_channel_init(channels_A(k), acqResult, t*buffBlkSize, sampleFreq); %����ͨ��
                    fprintf(logID_A, '%2d: Acquired at %ds, peakRatio=%.2f\r\n', svList(k), t/1000, peakRatio); %��ӡ������־
                end
            end
            %====����B
            if channels_B(k).state==0 %���ͨ��δ��������Լ���
                [acqResult, peakRatio] = GPS_L1_CA_acq_one(svList(k), buff_B(:,(end-2*8000+1):end)); %2ms���ݲ���
                if ~isempty(acqResult) %�ɹ�����
                    channels_B(k) = GPS_L1_CA_channel_init(channels_B(k), acqResult, t*buffBlkSize, sampleFreq); %����ͨ��
                    fprintf(logID_B, '%2d: Acquired at %ds, peakRatio=%.2f\r\n', svList(k), t/1000, peakRatio); %��ӡ������־
                end
            end
        end
    end
    
    %% ����
    for k=1:svN
        %====����A
        if channels_A(k).state~=0 %���ͨ��������и���
            while 1
                % �ж��Ƿ��������ĸ�������
                if mod(buffHead-channels_A(k).trackDataHead,buffSize)>(buffSize/2)
                    break
                end
                % ����ٽ����ͨ��������
                n = trackResults_A(k).n;
                trackResults_A(k).dataIndex(n,:)    = channels_A(k).dataIndex;
                trackResults_A(k).ts0(n,:)          = channels_A(k).ts0;
                trackResults_A(k).remCodePhase(n,:) = channels_A(k).remCodePhase;
                trackResults_A(k).codeFreq(n,:)     = channels_A(k).codeFreq;
                trackResults_A(k).remCarrPhase(n,:) = channels_A(k).remCarrPhase;
                trackResults_A(k).carrFreq(n,:)     = channels_A(k).carrFreq;
                % ��������
                trackDataHead = channels_A(k).trackDataHead;
                trackDataTail = channels_A(k).trackDataTail;
                if trackDataHead>trackDataTail
                    [channels_A(k), I_Q, disc, bitStartFlag] = ...
                        GPS_L1_CA_track(channels_A(k), sampleFreq_real, buffSize, buff_A(:,trackDataTail:trackDataHead), logID_A);
                else
                    [channels_A(k), I_Q, disc, bitStartFlag] = ...
                        GPS_L1_CA_track(channels_A(k), sampleFreq_real, buffSize, [buff_A(:,trackDataTail:end),buff_A(:,1:trackDataHead)], logID_A);
                end
                % ����ٽ�������ٽ����
                trackResults_A(k).I_Q(n,:)          = I_Q;
                trackResults_A(k).disc(n,:)         = disc;
                trackResults_A(k).bitStartFlag(n,:) = bitStartFlag;
                trackResults_A(k).CN0(n,:)          = channels_A(k).CN0;
                trackResults_A(k).carrAcc(n,:)      = channels_A(k).carrAcc;
                trackResults_A(k).Px(n,:)           = sqrt(diag(channels_A(k).Px)')*3;
                trackResults_A(k).n                 = n + 1;
            end
        end
        %====����B
        if channels_B(k).state~=0 %���ͨ��������и���
            while 1
                % �ж��Ƿ��������ĸ�������
                if mod(buffHead-channels_B(k).trackDataHead,buffSize)>(buffSize/2)
                    break
                end
                % ����ٽ����ͨ��������
                n = trackResults_B(k).n;
                trackResults_B(k).dataIndex(n,:)    = channels_B(k).dataIndex;
                trackResults_B(k).ts0(n,:)          = channels_B(k).ts0;
                trackResults_B(k).remCodePhase(n,:) = channels_B(k).remCodePhase;
                trackResults_B(k).codeFreq(n,:)     = channels_B(k).codeFreq;
                trackResults_B(k).remCarrPhase(n,:) = channels_B(k).remCarrPhase;
                trackResults_B(k).carrFreq(n,:)     = channels_B(k).carrFreq;
                % ��������
                trackDataHead = channels_B(k).trackDataHead;
                trackDataTail = channels_B(k).trackDataTail;
                if trackDataHead>trackDataTail
                    [channels_B(k), I_Q, disc, bitStartFlag] = ...
                        GPS_L1_CA_track(channels_B(k), sampleFreq_real, buffSize, buff_B(:,trackDataTail:trackDataHead), logID_B);
                else
                    [channels_B(k), I_Q, disc, bitStartFlag] = ...
                        GPS_L1_CA_track(channels_B(k), sampleFreq_real, buffSize, [buff_B(:,trackDataTail:end),buff_B(:,1:trackDataHead)], logID_B);
                end
                % ����ٽ�������ٽ����
                trackResults_B(k).I_Q(n,:)          = I_Q;
                trackResults_B(k).disc(n,:)         = disc;
                trackResults_B(k).bitStartFlag(n,:) = bitStartFlag;
                trackResults_B(k).CN0(n,:)          = channels_B(k).CN0;
                trackResults_B(k).carrAcc(n,:)      = channels_B(k).carrAcc;
                trackResults_B(k).Px(n,:)           = sqrt(diag(channels_B(k).Px)')*3;
                trackResults_B(k).n                 = n + 1;
            end
        end
    end
    
    %% ���Ŀ��ʱ���Ƿ񵽴�
    dtp = (ta(1)-tp(1)) + (ta(2)-tp(2))/1e3 + (ta(3)-tp(3))/1e6; %��ǰ����ʱ���붨λʱ��֮�>=0ʱ��ʾ��ǰ����ʱ���Ѿ�����򳬹���λʱ��
    
    %% ��λ
    % ֻʹ��A����
    if dtp>=0
        %--------����������Ϣ
        sv = NaN(svN,8);
        for k=1:svN
            if channels_A(k).state==2 %�������ͨ��״̬���Ը��ٵ���ͨ������������Ϣ��[λ�á�α�ࡢ�ٶȡ�α����]
                dn = mod(buffHead-channels_A(k).trackDataTail+1, buffSize) - 1; %trackDataTailǡ�ó�ǰbuffHeadһ��ʱ��dn=-1
                dtc = dn / sampleFreq_real; %��ǰ����ʱ������ٵ��ʱ���
                carrFreq = channels_A(k).carrFreq + 1575.42e6*deltaFreq; %��������ز�Ƶ��
                codeFreq = (carrFreq/1575.42e6+1)*1.023e6; %ͨ���ز�Ƶ�ʼ������Ƶ��
                codePhase = channels_A(k).remCodePhase + (dtc-dtp)*codeFreq; %��λ������λ
                ts0 = [floor(channels_A(k).ts0/1e3), mod(channels_A(k).ts0,1e3), 0] + [0, floor(codePhase/1023), mod(codePhase/1023,1)*1e3]; %��λ����뷢��ʱ��
                [sv(k,:),~] = sv_ecef(channels_A(k).ephemeris, tp, ts0); %����������������[λ�á�α�ࡢ�ٶ�]
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
                deltaFreq = deltaFreq + 10*pos(8)*dtpos/1000; %��Ƶ���ۼ�
                ta = ta - 10*sec2smu(pos(7))*dtpos/1000; %ʱ�����������Բ��ý�λ�����´θ���ʱ��λ��
            end
            %--------�洢���
            output_ta(no) = tp(1)*1000 + tp(2); %ʱ�����ms
            output_pos(no,:) = pos;
            output_sv(:,:,no) = sv;
            output_df(no) = deltaFreq;
            % no = no + 1;
        end
    end
    
    %% ������λ��
    % A��λ - B��λ
    if dtp>=0 && receiverState==1
        for k=1:svN
            if channels_A(k).state==2 && channels_B(k).state==2 %�������߶����ٵ��ÿ�����
                % ����A
                dn = mod(buffHead-channels_A(k).trackDataTail+1, buffSize) - 1;
                dtc = dn / sampleFreq_real;
                dt = dtc - dtp;
                phase_A = channels_A(k).remCarrPhase + channels_A(k).carrFreq*dt + 0.5*channels_A(k).carrAcc*dt^2; %�ز���λ
                % ����B
                dn = mod(buffHead-channels_B(k).trackDataTail+1, buffSize) - 1;
                dtc = dn / sampleFreq_real;
                dt = dtc - dtp;
                phase_B = channels_B(k).remCarrPhase + channels_B(k).carrFreq*dt + 0.5*channels_B(k).carrAcc*dt^2; %�ز���λ
                % ��λ��
                if channels_A(k).inverseFlag*channels_B(k).inverseFlag==1 %����������λ��ת��ͬ
                    output_dphase(no,k) = mod((channels_A(k).carrCirc+phase_A)-(channels_B(k).carrCirc+phase_B)    +500,1000) - 500;
                else %����������λ��ת��ͬ
                    output_dphase(no,k) = mod((channels_A(k).carrCirc+phase_A)-(channels_B(k).carrCirc+phase_B)+0.5+500,1000) - 500;
                end
            end
        end
        no = no + 1;
    end
    
    %% �����´�Ŀ��ʱ��
    if dtp>=0
        tp = time_carry(tp + [0,dtpos,0]);
    end
    
end

%% �ر��ļ����رս�����
fclose(fileID_A);
fclose(fileID_B);
fclose(logID_A);
fclose(logID_B);
close(f);

%% ɾ���հ�����
for k=1:svN
    trackResults_A(k) = trackResult_clean(trackResults_A(k));
    trackResults_B(k) = trackResult_clean(trackResults_B(k));
end
output_ta(no:end) = [];
output_pos(no:end,:) = [];
output_sv(:,:,no:end) = [];
output_df(no:end) = [];
output_dphase(no:end,:) = [];

%% ��ӡͨ����־��*��
clc
disp('<--------antenna A-------->')
print_log('logA.txt', svList);
disp('<--------antenna B-------->')
print_log('logB.txt', svList);

%% ��������
% ÿ�������궼�ᱣ�棬���������Զ����
for k=1:svN
    PRN = channels_A(k).PRN;
    if isnan(ephemeris(1,PRN)) %�����ļ���û��
        if ~isnan(channels_A(k).ephemeris(1))
            ephemeris(:,PRN) = channels_A(k).ephemeris; %��������
        elseif ~isnan(channels_B(k).ephemeris(1))
            ephemeris(:,PRN) = channels_B(k).ephemeris; %��������
        end
    end
end
save(ephemeris_file, 'ephemeris', 'ion');

%% ��ͼ��*��
for k=1:svN
    if trackResults_A(k).n==1 && trackResults_B(k).n==1 %����û���ٵ�ͨ��
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
    ax4 = axes('Position', [0.53, 0.06, 0.42, 0.25]);
    hold(ax4,'on');
    grid(ax4,'on');
    ax5 = axes('Position', [0.05, 0.06, 0.42, 0.25]);
    hold(ax5,'on');
    grid(ax5,'on');
    
    % ��ͼ
    plot(ax1, trackResults_A(k).I_Q(1001:end,1),trackResults_A(k).I_Q(1001:end,4), 'LineStyle','none', 'Marker','.', 'Color',[0,0.447,0.741])
    plot(ax2, trackResults_A(k).dataIndex/sampleFreq, trackResults_A(k).I_Q(:,1), 'Color',[0,0.447,0.741])
    
%     index = find(trackResults_A(k).bitStartFlag==double('H')); %Ѱ��֡ͷ�׶Σ���ɫ��
%     plot(ax2, trackResults_A(k).dataIndex(index)/sampleFreq, trackResults_A(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','m')
%     index = find(trackResults_A(k).bitStartFlag==double('C')); %У��֡ͷ�׶Σ���ɫ��
%     plot(ax2, trackResults_A(k).dataIndex(index)/sampleFreq, trackResults_A(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','b')
%     index = find(trackResults_A(k).bitStartFlag==double('E')); %���������׶Σ���ɫ��
%     plot(ax2, trackResults_A(k).dataIndex(index)/sampleFreq, trackResults_A(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','r')
    %---------------------------------------------------------------------%
    plot(ax1, trackResults_B(k).I_Q(1001:end,1),trackResults_B(k).I_Q(1001:end,4), 'LineStyle','none', 'Marker','.', 'Color',[0.850,0.325,0.098])
    plot(ax3, trackResults_B(k).dataIndex/sampleFreq, trackResults_B(k).I_Q(:,1), 'Color',[0.850,0.325,0.098])
    
%     index = find(trackResults_B(k).bitStartFlag==double('H')); %Ѱ��֡ͷ�׶Σ���ɫ��
%     plot(ax3, trackResults_B(k).dataIndex(index)/sampleFreq, trackResults_B(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','m')
%     index = find(trackResults_B(k).bitStartFlag==double('C')); %У��֡ͷ�׶Σ���ɫ��
%     plot(ax3, trackResults_B(k).dataIndex(index)/sampleFreq, trackResults_B(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','b')
%     index = find(trackResults_B(k).bitStartFlag==double('E')); %���������׶Σ���ɫ��
%     plot(ax3, trackResults_B(k).dataIndex(index)/sampleFreq, trackResults_B(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','r')

    plot(ax4, trackResults_A(k).dataIndex/sampleFreq, trackResults_A(k).carrFreq, 'LineWidth',1.5, 'Color',[0,0.447,0.741]) %�ز�Ƶ��
    plot(ax4, trackResults_B(k).dataIndex/sampleFreq, trackResults_B(k).carrFreq, 'LineWidth',1.5, 'Color',[0.850,0.325,0.098])
    
    plot(ax5, trackResults_A(k).dataIndex/sampleFreq, trackResults_A(k).carrAcc, 'Color',[0,0.447,0.741]) %���߷�����ٶ�
    plot(ax5, trackResults_B(k).dataIndex/sampleFreq, trackResults_B(k).carrAcc, 'Color',[0.850,0.325,0.098])
    
    % ����������
    set(ax2, 'XLim',[0,msToProcess/1000])
    set(ax3, 'XLim',[0,msToProcess/1000])

    ax2_ylim = get(ax2, 'YLim');
    ax3_ylim = get(ax3, 'YLim');
    ylim = max(abs([ax2_ylim,ax3_ylim]));
    set(ax2, 'YLim',[-ylim,ylim])
    set(ax3, 'YLim',[-ylim,ylim])
    
    set(ax4, 'XLim',[0,msToProcess/1000])
    set(ax5, 'XLim',[0,msToProcess/1000])
end

clearvars k screenSize ax1 ax2 ax3 ax4 ax5 index ax2_ylim ax3_ylim ylim

%% ����λ�*��
colorTable = [    0, 0.447, 0.741;
              0.850, 0.325, 0.098;
              0.929, 0.694, 0.125;
              0.494, 0.184, 0.556;
              0.466, 0.674, 0.188;
              0.301, 0.745, 0.933;
              0.635, 0.078, 0.184;
                  0,     0,     1;
                  1,     0,     0;
                  0,     1,     0;
                  0,     0,     0;];
figure
hold on
grid on
legend_str = [];
for k=1:svN
    if sum(~isnan(output_dphase(:,k)))~=0
        plot(output_dphase(:,k), 'LineWidth',1, 'Color',colorTable(k,:))
        eval('legend_str = [legend_str; string(num2str(svList(k)))];')
    end
end
legend(legend_str)
% set(gca,'Ylim',[0,1])
title('Phase difference')
clearvars colorTable legend_str k

%% ���������*��
clearvars -except sampleFreq msToProcess ...
                  p0 tf svList svN ...
                  channels_A trackResults_A ...
                  channels_B trackResults_B ...
                  output_ta output_pos output_sv output_df output_dphase ...
                  ion
              
save result_double.mat

%% ��ʱ����
toc