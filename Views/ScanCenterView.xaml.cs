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

        private void SetPathC_Click(object sender, RoutedEventArgs e)
        {
            if (DataContext is ScanViewModel vm) vm.ScanPath = "C:\\";
        }

        private void SetPathD_Click(object sender, RoutedEventArgs e)
        {
            if (DataContext is ScanViewModel vm) vm.ScanPath = "D:\\";
        }

        private void StartScan_Click(object sender, RoutedEventArgs e)
        {
            if (DataContext is ScanViewModel vm) vm.StartHeuristicScan();
        }
    }
}
