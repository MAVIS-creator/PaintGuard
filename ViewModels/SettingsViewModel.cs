using System.ComponentModel;
using System.Runtime.CompilerServices;
using VaultGuard360.Services;

namespace VaultGuard360.ViewModels
{
    public class SettingsViewModel : INotifyPropertyChanged
    {
        public UsbWatcherService UsbService => UsbWatcherService.Instance;
        public EngineService EngineService => EngineService.Instance;

        public bool IsUsbVaccineEnabled
        {
            get => UsbService.IsAutoVaccineEnabled;
            set { UsbService.IsAutoVaccineEnabled = value; OnPropertyChanged(); }
        }

        public bool IsAutoRunHardened
        {
            get => UsbService.IsAutoRunHardened;
            set { UsbService.IsAutoRunHardened = value; OnPropertyChanged(); }
        }

        public string BearerToken => EngineService.Instance.BearerToken;
        public int ApiPort => EngineService.Instance.ApiPort;

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        }
    }
}
