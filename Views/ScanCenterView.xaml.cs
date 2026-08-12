using System.Windows;
using System.Windows.Controls;
using VaultGuard360.ViewModels;

namespace VaultGuard360.Views
{
    public partial class ScanCenterView : UserControl
    {
        public ScanCenterView()
        {
            InitializeComponent();
        }

        private ScanViewModel? VM => DataContext as ScanViewModel;

        private void SetPathC_Click(object sender, RoutedEventArgs e)
        {
            if (VM != null) VM.ScanPath = "C:\\";
        }

        private void SetPathD_Click(object sender, RoutedEventArgs e)
        {
            if (VM != null) VM.ScanPath = "D:\\";
        }

        private async void StartScan_Click(object sender, RoutedEventArgs e)
        {
            if (VM != null)
            {
                await VM.ExecuteUnifiedLifecycleScanAsync();
            }
        }
    }
}
