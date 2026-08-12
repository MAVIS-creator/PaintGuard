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

        private VaultViewModel? VM => DataContext as VaultViewModel;

        private async void CreateSnapshot_Click(object sender, RoutedEventArgs e)
        {
            if (VM != null)
            {
                await VM.CreateSystemBaselineSnapshotAsync();
            }
        }

        private async void RunExpiroRemediation_Click(object sender, RoutedEventArgs e)
        {
            if (VM != null)
            {
                await VM.RunExpiroRemediationAsync();
            }
        }

        private void SyncVault_Click(object sender, RoutedEventArgs e)
        {
            VM?.SyncVaults();
        }
    }
}
