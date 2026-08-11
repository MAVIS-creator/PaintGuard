using System.Windows;
using System.Windows.Media;
using VaultGuard360.Setup.Services;

namespace VaultGuard360.Setup
{
    public partial class InstallerWindow : Window
    {
        public InstallerWindow()
        {
            InitializeComponent();

            InstallerEngineService.Instance.OnProgressChanged += (percent, msg) => {
                Dispatcher.Invoke(() => {
                    MainProgressBar.Value = percent;
                    PercentText.Text = $"{percent}%";
                    StatusMessageText.Text = msg;
                });
            };

            InstallerEngineService.Instance.OnStepStatusUpdated += (stepId, isDone) => {
                Dispatcher.Invoke(() => {
                    UpdateStepStatus(stepId, isDone);
                });
            };

            InstallerEngineService.Instance.OnInstallationCompleted += (isSuccess, errorMsg) => {
                Dispatcher.Invoke(() => {
                    if (isSuccess)
                    {
                        InstallingTitleText.Text = "Installation Complete!";
                        StatusMessageText.Text = "System immunized. VaultGuard 360 Security Suite is ready.";
                        LaunchButton.Visibility = Visibility.Visible;
                    }
                    else
                    {
                        InstallingTitleText.Text = "Installation Failed";
                        StatusMessageText.Text = $"Error: {errorMsg}";
                    }
                });
            };
        }

        private void CloseButton_Click(object sender, RoutedEventArgs e)
        {
            Close();
        }

        private async void InstallNow_Click(object sender, RoutedEventArgs e)
        {
            InstallerEngineService.Instance.DefaultInstallPath = InstallPathBox.Text;
            InstallerEngineService.Instance.CreateDesktopShortcut = DesktopShortcutCheck.IsChecked == true;
            InstallerEngineService.Instance.CreateStartMenuShortcut = StartMenuShortcutCheck.IsChecked == true;
            InstallerEngineService.Instance.AutoStartOnBoot = AutoStartCheck.IsChecked == true;

            WelcomeView.Visibility = Visibility.Collapsed;
            ProgressView.Visibility = Visibility.Visible;

            await InstallerEngineService.Instance.StartInstallationAsync();
        }

        private void UpdateStepStatus(string stepId, bool isDone)
        {
            Brush greenBrush = (Brush)FindResource("BrushSecondary");
            switch (stepId)
            {
                case "Step1":
                    Step1Badge.Text = "✓";
                    Step1Badge.Foreground = greenBrush;
                    Step1Status.Text = "SUCCESS";
                    Step1Status.Foreground = greenBrush;
                    break;
                case "Step2":
                    Step2Badge.Text = "✓";
                    Step2Badge.Foreground = greenBrush;
                    Step2Status.Text = "SUCCESS";
                    Step2Status.Foreground = greenBrush;
                    break;
                case "Step3":
                    Step3Badge.Text = "✓";
                    Step3Badge.Foreground = greenBrush;
                    Step3Status.Text = "SUCCESS";
                    Step3Status.Foreground = greenBrush;
                    break;
                case "Step4":
                    Step4Badge.Text = "✓";
                    Step4Badge.Foreground = greenBrush;
                    Step4Status.Text = "SUCCESS";
                    Step4Status.Foreground = greenBrush;
                    break;
                case "Step5":
                    Step5Badge.Text = "✓";
                    Step5Badge.Foreground = greenBrush;
                    Step5Status.Text = "SUCCESS";
                    Step5Status.Foreground = greenBrush;
                    break;
            }
        }

        private void LaunchButton_Click(object sender, RoutedEventArgs e)
        {
            InstallerEngineService.Instance.LaunchApplication();
            Close();
        }
    }
}
