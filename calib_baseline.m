function calib_baseline()
% �궨����/����̬

%% ��������
svList = evalin('base', 'svList');
svN = evalin('base', 'svN');
output_pos = evalin('base', 'output_pos');
output_sv = evalin('base', 'output_sv');
output_dphase = evalin('base', 'output_dphase');

%% ����
bl = 1.32; %���»��߳���
br = 0.02; %���߳��ȷ�Χ
n = size(output_pos,1); %������ٸ���
lamda = 299792458 / 1575.42e6; %����

circ_limit = 1000;
circ_half = circ_limit/2;

mode = 0; %0Ϊ�궨���ߣ�1Ϊ����̬

%% �������
BLs = NaN(n,3); %���߲����������һ�к���ǣ��ڶ��и����ǣ������л��߳���
pdb = NaN(n,svN); %���ݻ��������λ�������λ�
pdm = NaN(n,svN); %ʵ�����λ������ܣ�ʵ����λ�

%% �������ʸ����ȫ������ģ����������
if mode==0
    for k=1:n
        %----���ջ�λ��
        p0 = output_pos(k,1:3); %γ����
        Cen = dcmecef2ned(p0(1), p0(2));
        rp = lla2ecef(p0); %ecef���꣬������
        %----����ϵ������ָ�����ߵĵ�λʸ��
        rs = output_sv(:,1:3,k); %��������
        rsp = ones(svN,1)*rp - rs;
        rho = sum(rsp.*rsp, 2).^0.5; %������
        rspu = rsp ./ (rho*[1,1,1]);
        A = rspu * Cen';
        %----��λ��
        p = output_dphase(k,:)'; %��������ͨ���������λ��
        p = mod(p,1); %ȡС������
        %----�ų��߶Ƚ�̫�͵�����
        % p(asind(A(:,3))<20) = NaN;
        %----ɾ��û����λ�����
        Ac = A(~isnan(p),:);
        pc = p(~isnan(p));
        %----�������ʸ��
        if length(pc)>=5
            Rx = IAR_nonbaseline(Ac, pc, lamda, bl+[-br,br]);
            L = norm(Rx); %���߳���
            psi = atan2d(Rx(2),Rx(1)); %���ߺ����
            theta = -asind(Rx(3)/L); %���߸�����
            % �洢���
            BLs(k,:) = [psi,theta,L];
            pdb(k,:) = (A*Rx / lamda)';
            pdm(k,:) = p' + round(pdb(k,:)-p');
        end
    end
end
    
%% �������ʸ������¼����ģ���ȣ�
if mode==1
    N = NaN(svN,1); %����ͨ������λ������ͨ���������λ���ȥ���ֵΪ��ʵ��λ��
    for k=1:n
        %----���ջ�λ��
        p0 = output_pos(k,1:3); %γ����
        Cen = dcmecef2ned(p0(1), p0(2));
        rp = lla2ecef(p0); %ecef���꣬������
        %----����ϵ������ָ�����ߵĵ�λʸ��
        rs = output_sv(:,1:3,k); %��������
        rsp = ones(svN,1)*rp - rs;
        rho = sum(rsp.*rsp, 2).^0.5; %������
        rspu = rsp ./ (rho*[1,1,1]);
        A = rspu * Cen';
        %----��λ��
        p0 = output_dphase(k,:)'; %��������ͨ���������λ��
        %----�������ʸ��
        if sum(~isnan(p0-N))<4 %��������λ������С��4�����ܶ���
            if sum(~isnan(p0))>=5 %�������λ���������ڵ���5�����Խ�������ģ��������
                p = mod(p0,1); %ȡС������
                Ac = A(~isnan(p),:); %ɾ��û����λ�����
                pc = p(~isnan(p));
                Rx = IAR_nonbaseline(Ac, pc, lamda, bl+[-br,br]);
                N = round(p0-A*Rx/lamda); %��������ͨ������λ�������
            else
                continue
            end
        else %��������λ���������ڵ���4������ֱ�Ӷ���
            p = mod(p0-N + circ_half, circ_limit) - circ_half; %���������λ��
            Ac = A(~isnan(p),:); %ɾ��û����λ�����
            pc = p(~isnan(p));
            ele = asind(Ac(:,3));
            [~,i1] = max(ele);
            ele(i1) = [];
            W = diag(sind(ele))^2; %Ȩֵ
            Ac = Ac - ones(size(Ac,1),1)*Ac(i1,:);
            Ac(i1,:) = [];
            pc = pc - pc(i1);
            pc(i1) = [];
            Rx = (Ac'*W*Ac) \ (Ac'*W*pc*lamda); %��Ȩ��С����
            N = round(p0-A*Rx/lamda); %��������ͨ������λ�������²���ͨ����Ӧ��ֵ�ᱻֱ�Ӽ��㣬�ж�ͨ����ֵ�ᱻ����
        end
        %----�洢���
        L = norm(Rx); %���߳���
        psi = atan2d(Rx(2),Rx(1)); %���ߺ����
        theta = -asind(Rx(3)/L); %���߸�����
        BLs(k,:) = [psi,theta,L];
        pdb(k,:) = (A*Rx / lamda)';
        pdm(k,:) = (mod(p0-N + circ_half, circ_limit) - circ_half)';
    end
end

%% �������
assignin('base', 'BLs', BLs)
assignin('base', 'pdb', pdb)
assignin('base', 'pdm', pdm)

%% �����߱궨���
figure
subplot(3,1,1)
plot(BLs(:,1))
grid on
title('�����')
subplot(3,1,2)
plot(BLs(:,2))
grid on
title('������')
subplot(3,1,3)
plot(BLs(:,3))
grid on
title('���߳���')
if exist('br','var')
    set(gca,'Ylim',[bl-br,bl+br])
end

%% ����λ��
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
                  0,     0,     0];

figure
hold on
grid on
legend_str = [];
for k=1:svN
    if sum(~isnan(pdm(:,k)))~=0
        plot(pdm(:,k), 'Color',colorTable(k,:)) %ʵ�ߣ�ʵ����λ��
        legend_str = [legend_str; string(num2str(svList(k)))];
    end
end
for k=1:svN
    if sum(~isnan(pdm(:,k)))~=0
        plot(pdb(:,k), 'Color',colorTable(k,:), 'LineStyle','--') %���ߣ����������λ��
    end
end
legend(legend_str)
title('ʵ����λ���������λ��')

%% ��ʵ����λ���������λ��֮������һ��ֱ���ϣ�
% ��������·��ͬ��ɵ�
pdd = pdm - pdb;
figure
hold on
grid on
for k=1:svN
    if sum(~isnan(pdd(:,k)))~=0
        plot(pdd(:,k), 'Color',colorTable(k,:))
    end
end
legend(legend_str)
set(gca,'Ylim',[-0.5,0.5])
title('ʵ����λ�� - ������λ��')

end