using System.Windows;
using System.Windows.Controls;
using VaultGuard360.ViewModels;

namespace VaultGuard360.Views
{
    public partial class SecuritySettingsView : UserControl
    {
        public SecuritySettingsView()
        {
            InitializeComponent();
        }

        private SettingsViewModel? VM => DataContext as SettingsViewModel;

        private async void SendSupport_Click(object sender, RoutedEventArgs e)
        {
            if (VM != null)
            {
                await VM.SendSupportMessageAsync();
            }
        }
    }
}
