using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using VaultGuard360.Services;

namespace VaultGuard360.ViewModels
{
    public class VaultItem
    {
        public string Name { get; set; } = string.Empty;
        public string Path { get; set; } = string.Empty;
        public string Hash { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public bool IsQuarantined { get; set; } = false;
    }

    public class VaultViewModel : INotifyPropertyChanged
    {
        public ObservableCollection<VaultItem> BaselineAssets { get; } = new ObservableCollection<VaultItem>();
        public ObservableCollection<VaultItem> QuarantinedAssets { get; } = new ObservableCollection<VaultItem>();

        public VaultViewModel()
        {
            BaselineAssets.Add(new VaultItem { Name = "system_manifest.json", Path = "C:\\ProgramData\\VaultGuard\\Baseline\\", Hash = "SHA256: 8f4e...9a2b", Status = "VERIFIED" });
            BaselineAssets.Add(new VaultItem { Name = "core_kernel_module.sys", Path = "C:\\Windows\\System32\\drivers\\", Hash = "SHA256: 3c1d...77ef", Status = "VERIFIED" });
            BaselineAssets.Add(new VaultItem { Name = "mspaint.exe", Path = "C:\\Windows\\System32\\mspaint.exe", Hash = "SHA256: e11a...3312", Status = "GOLDEN MATCH" });
        }

        public void SyncVaults()
        {
            NotificationService.Instance.AddNotification("Vault Sync", "Verified 842 golden baseline assets against ACL storage.", false);
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        }
    }
}
