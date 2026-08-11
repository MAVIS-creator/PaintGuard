using System;
using System.IO;

namespace VaultGuard360.Services
{
    public class UsbWatcherService
    {
        private static UsbWatcherService? _instance;
        public static UsbWatcherService Instance => _instance ??= new UsbWatcherService();

        public event Action<string>? OnUsbDriveDetected;
        public event Action<string, bool>? OnUsbVaccinated;

        public bool IsAutoVaccineEnabled { get; set; } = true;
        public bool IsAutoRunHardened { get; set; } = true;

        public void SimulateUsbDriveInsertion(string driveLetter = "D:\\")
        {
            OnUsbDriveDetected?.Invoke(driveLetter);
            
            if (IsAutoVaccineEnabled)
            {
                DeployVaccineToDrive(driveLetter);
            }
        }

        public void DeployVaccineToDrive(string drivePath)
        {
            try
            {
                string targetPath = Path.Combine(drivePath, "autorun.inf");
                if (Directory.Exists(targetPath) || File.Exists(targetPath))
                {
                    OnUsbVaccinated?.Invoke($"Vaccine already active on {drivePath}", true);
                    return;
                }

                Directory.CreateDirectory(targetPath);
                DirectoryInfo di = new DirectoryInfo(targetPath);
                di.Attributes = FileAttributes.ReadOnly | FileAttributes.Hidden | FileAttributes.System;
                
                OnUsbVaccinated?.Invoke($"Successfully deployed dummy autorun.inf vaccine trap to {drivePath}", true);
            }
            catch (Exception ex)
            {
                OnUsbVaccinated?.Invoke($"Vaccine Deployment Warning on {drivePath}: {ex.Message}", false);
            }
        }
    }
}
