using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows.Input;
using VaultGuard360.Services;

namespace VaultGuard360.ViewModels
{
    public class MainViewModel : INotifyPropertyChanged
    {
        private object _currentView;
        private string _activeTab = "Dashboard";
        private bool _isNotificationFlyoutOpen = false;
        private bool _isUsbFlyoutOpen = false;
        private bool _isShieldFlyoutOpen = false;
        private bool _isHeuristicFlyoutOpen = false;
        private bool _isRealTimeProtected = true;

        public DashboardViewModel DashboardVM { get; } = new DashboardViewModel();
        public ScanViewModel ScanVM { get; } = new ScanViewModel();
        public VaultViewModel VaultVM { get; } = new VaultViewModel();
        public SettingsViewModel SettingsVM { get; } = new SettingsViewModel();

        public NotificationService NotificationService => NotificationService.Instance;

        public object CurrentView
        {
            get => _currentView;
            set { _currentView = value; OnPropertyChanged(); }
        }

        public string ActiveTab
        {
            get => _activeTab;
            set { _activeTab = value; OnPropertyChanged(); }
        }

        public bool IsNotificationFlyoutOpen
        {
            get => _isNotificationFlyoutOpen;
            set { _isNotificationFlyoutOpen = value; OnPropertyChanged(); }
        }

        public bool IsUsbFlyoutOpen
        {
            get => _isUsbFlyoutOpen;
            set { _isUsbFlyoutOpen = value; OnPropertyChanged(); }
        }

        public bool IsShieldFlyoutOpen
        {
            get => _isShieldFlyoutOpen;
            set { _isShieldFlyoutOpen = value; OnPropertyChanged(); }
        }

        public bool IsHeuristicFlyoutOpen
        {
            get => _isHeuristicFlyoutOpen;
            set { _isHeuristicFlyoutOpen = value; OnPropertyChanged(); }
        }

        public bool IsRealTimeProtected
        {
            get => _isRealTimeProtected;
            set { _isRealTimeProtected = value; OnPropertyChanged(); }
        }

        public MainViewModel()
        {
            _currentView = DashboardVM;
            
            UsbWatcherService.Instance.OnUsbDriveDetected += (drive) => {
                NotificationService.Instance.AddNotification("USB Mass Storage Inserted", $"Drive {drive} detected. Auto-Vaccine scanning...", false);
            };

            UsbWatcherService.Instance.OnUsbVaccinated += (msg, isSuccess) => {
                NotificationService.Instance.AddNotification("USB Vaccine Protocol", msg, !isSuccess);
            };
        }

        public void Navigate(string tabName)
        {
            ActiveTab = tabName;
            CloseFlyouts();
            CurrentView = tabName switch
            {
                "ScanCenter" => ScanVM,
                "VaultManager" => VaultVM,
                "Settings" => SettingsVM,
                _ => DashboardVM
            };
        }

        public void ToggleNotifications()
        {
            bool nextState = !IsNotificationFlyoutOpen;
            CloseFlyouts();
            IsNotificationFlyoutOpen = nextState;
        }

        public void ToggleUsbStatus()
        {
            bool nextState = !IsUsbFlyoutOpen;
            CloseFlyouts();
            IsUsbFlyoutOpen = nextState;
            if (nextState)
            {
                UsbWatcherService.Instance.SimulateUsbDriveInsertion("D:\\");
            }
        }

        public void ToggleShieldStatus()
        {
            bool nextState = !IsShieldFlyoutOpen;
            CloseFlyouts();
            IsShieldFlyoutOpen = nextState;
        }

        public void ToggleHeuristicStatus()
        {
            bool nextState = !IsHeuristicFlyoutOpen;
            CloseFlyouts();
            IsHeuristicFlyoutOpen = nextState;
        }

        public void ToggleRealTimeProtection()
        {
            IsRealTimeProtected = !IsRealTimeProtected;
            NotificationService.Instance.AddNotification("Real-Time Guard", IsRealTimeProtected ? "Real-Time Protection Engine ENFORCED" : "Warning: Real-Time Protection PAUSED", !IsRealTimeProtected);
        }

        public void CloseFlyouts()
        {
            IsNotificationFlyoutOpen = false;
            IsUsbFlyoutOpen = false;
            IsShieldFlyoutOpen = false;
            IsHeuristicFlyoutOpen = false;
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        }
    }
}
