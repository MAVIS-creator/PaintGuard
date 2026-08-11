using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text;
using VaultGuard360.Services;

namespace VaultGuard360.ViewModels
{
    public class ScanViewModel : INotifyPropertyChanged
    {
        private string _scanPath = "C:\\";
        private int _cleanCount = 142851;
        private int _suspiciousCount = 0;
        private int _infectedCount = 0;
        private bool _isDryRun = true;
        private string _logOutput = "[SYSTEM] VaultGuard 360 Deep Inspection Engine v4.2 Active.\n[READY] Waiting for scan execution...\n";

        public string ScanPath
        {
            get => _scanPath;
            set { _scanPath = value; OnPropertyChanged(); }
        }

        public int CleanCount
        {
            get => _cleanCount;
            set { _cleanCount = value; OnPropertyChanged(); }
        }

        public int SuspiciousCount
        {
            get => _suspiciousCount;
            set { _suspiciousCount = value; OnPropertyChanged(); }
        }

        public int InfectedCount
        {
            get => _infectedCount;
            set { _infectedCount = value; OnPropertyChanged(); }
        }

        public bool IsDryRun
        {
            get => _isDryRun;
            set { _isDryRun = value; OnPropertyChanged(); }
        }

        public string LogOutput
        {
            get => _logOutput;
            set { _logOutput = value; OnPropertyChanged(); }
        }

        public ScanViewModel()
        {
            EngineService.Instance.OnLogReceived += (logMsg, isErr) => {
                LogOutput += logMsg + "\n";
            };
        }

        public void StartHeuristicScan()
        {
            EngineService.Instance.Log($"Starting Heuristic Scan on {ScanPath} (DryRun: {IsDryRun})...", false);
            NotificationService.Instance.AddNotification("Scan Execution", $"Scanning {ScanPath} with heuristic rules...", false);
            CleanCount += 450;
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        }
    }
}
