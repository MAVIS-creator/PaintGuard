using System.Windows;
using System.Windows.Controls;
using VaultGuard360.ViewModels;

namespace VaultGuard360.Views
{
    public partial class DashboardView : UserControl
    {
        public DashboardView()
        {
            InitializeComponent();
        }

        private void QuickScan_Click(object sender, RoutedEventArgs e)
        {
            if (DataContext is DashboardViewModel vm)
            {
                vm.ExecuteQuickScan();
            }
        }

        private void Remediate_Click(object sender, RoutedEventArgs e)
        {
            if (DataContext is DashboardViewModel vm)
            {
                vm.ExecuteRemediation();
            }
        }
    }
}
