using System.Windows;
using System.Windows.Controls;
using VaultGuard360.ViewModels;

namespace VaultGuard360.Views
{
    public partial class VaultManagerView : UserControl
    {
        public VaultManagerView()
        {
            InitializeComponent();
        }

        private void SyncVault_Click(object sender, RoutedEventArgs e)
        {
            if (DataContext is VaultViewModel vm) vm.SyncVaults();
        }
    }
}
