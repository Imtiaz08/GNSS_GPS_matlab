% ����imu���������̬
% ��Ҫ��ֹһ��ʱ�䣬����У����ƫ
% �����꿴nav����

data = IMU5210_data;
% data = ADIS16448_data;

% ��ǰ��ĵ������ƫ
m = 1:4000;
data(:,2) = data(:,2) - mean(data(m,2));
data(:,3) = data(:,3) - mean(data(m,3));
data(:,4) = data(:,4) - mean(data(m,4));

n = size(data,1);
nav = zeros(n,3);

q = [1;0;0;0]; %��̬��ֵ��ȫ0

for k=1:n
    wb = data(k,2:4) /180*pi;
    q = q + 0.5*[  0,   -wb(1), -wb(2), -wb(3);
                 wb(1),    0,    wb(3), -wb(2);
                 wb(2), -wb(3),    0,    wb(1);
                 wb(3),  wb(2), -wb(1),    0]*q*0.01;
    q = quatnormalize(q')';
    
    [r1,r2,r3] = quat2angle(q');
    nav(k,:) = [r1,r2,r3] /pi*180;
end