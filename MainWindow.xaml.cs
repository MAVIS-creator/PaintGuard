using System.Windows;
using VaultGuard360.ViewModels;

namespace VaultGuard360
{
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
        }

        private MainViewModel? VM => DataContext as MainViewModel;

        private void NavDashboard_Click(object sender, RoutedEventArgs e) => VM?.Navigate("Dashboard");
        private void NavScanCenter_Click(object sender, RoutedEventArgs e) => VM?.Navigate("ScanCenter");
        private void NavVaultManager_Click(object sender, RoutedEventArgs e) => VM?.Navigate("VaultManager");
        private void NavSettings_Click(object sender, RoutedEventArgs e) => VM?.Navigate("Settings");

        private void ToggleNotifications_Click(object sender, RoutedEventArgs e) => VM?.ToggleNotifications();
        private void ToggleUsb_Click(object sender, RoutedEventArgs e) => VM?.ToggleUsbStatus();
        private void ToggleShield_Click(object sender, RoutedEventArgs e) => VM?.ToggleShieldStatus();
        private void ToggleHeuristic_Click(object sender, RoutedEventArgs e) => VM?.ToggleHeuristicStatus();

        private void ToggleProtection_Click(object sender, RoutedEventArgs e) => VM?.ToggleRealTimeProtection();
        private void QuickScanTop_Click(object sender, RoutedEventArgs e)
        {
            VM?.Navigate("Dashboard");
            VM?.DashboardVM.ExecuteQuickScan();
        }

        private void Header_MouseLeftButtonDown(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            if (e.LeftButton == System.Windows.Input.MouseButtonState.Pressed) DragMove();
        }
        private void MinimizeWindow_Click(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;
        private void CloseWindow_Click(object sender, RoutedEventArgs e) => Close();
    }
}
