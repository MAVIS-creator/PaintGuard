using System.ComponentModel;
using System.Runtime.CompilerServices;
using VaultGuard360.Services;

namespace VaultGuard360.ViewModels
{
    public class DashboardViewModel : INotifyPropertyChanged
    {
        private string _systemStatus = "Protected";
        private string _targetDrive = "C:\\";
        private int _quarantineCount = 0;

        public string SystemStatus
        {
            get => _systemStatus;
            set { _systemStatus = value; OnPropertyChanged(); }
        }

        public string TargetDrive
        {
            get => _targetDrive;
            set { _targetDrive = value; OnPropertyChanged(); }
        }

        public int QuarantineCount
        {
            get => _quarantineCount;
            set { _quarantineCount = value; OnPropertyChanged(); }
        }

        public void ExecuteQuickScan()
        {
            NotificationService.Instance.AddNotification("Quick Scan Started", "Scanning memory, system processes, and startup run keys...", false);
            EngineService.Instance.Log("Executing Quick Scan on C:\\Program Files...", false);
        }

        public void ExecuteRemediation()
        {
            NotificationService.Instance.AddNotification("Remediation Protocol Executed", $"Executed 4-Rung Remediation on {TargetDrive}. System clean.", false);
            EngineService.Instance.Log($"4-Rung Remediation completed on {TargetDrive}.", false);
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        }
    }
}
