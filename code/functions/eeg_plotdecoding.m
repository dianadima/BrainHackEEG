function [] = eeg_plotdecoding(d,data)

figure
hold on

time = data.time{1};

errbar_upper = mean(d,1) + std(d,1)/sqrt(size(d,1));
errbar_lower = mean(d,1) - std(d,1)/sqrt(size(d,1));

try
    patch([time fliplr(time)], [errbar_upper fliplr(errbar_lower)], [0.8 0.8 0.8], 'EdgeColor', 'none')
catch
end

plot(data.time{1},mean(d,1),'Color','k','LineWidth',1.5)

xlim([-0.2 1])
%ylim([40 70])
set(gca,'FontSize',18)
ylabel('Decoding accuracy (%)')
xlabel('Time (s)')