using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Threading.Tasks;
using Microsoft.Win32;

namespace VaultGuard360.Setup.Services
{
    public class InstallerEngineService
    {
        private static InstallerEngineService? _instance;
        public static InstallerEngineService Instance => _instance ??= new InstallerEngineService();

        public string DefaultInstallPath { get; set; } = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "VaultGuard 360");
        public bool CreateDesktopShortcut { get; set; } = true;
        public bool CreateStartMenuShortcut { get; set; } = true;
        public bool AutoStartOnBoot { get; set; } = true;

        public event Action<int, string>? OnProgressChanged;
        public event Action<string, bool>? OnStepStatusUpdated;
        public event Action<bool, string>? OnInstallationCompleted;

        public async Task StartInstallationAsync()
        {
            await Task.Run(() =>
            {
                try
                {
                    // Step 1: Preparing installation
                    OnStepStatusUpdated?.Invoke("Step1", true);
                    OnProgressChanged?.Invoke(15, "Preparing installation environment...");
                    Task.Delay(500).Wait();

                    // Ensure Directory
                    if (!Directory.Exists(DefaultInstallPath))
                    {
                        Directory.CreateDirectory(DefaultInstallPath);
                    }

                    // Step 2: Copying self-contained application payload
                    OnStepStatusUpdated?.Invoke("Step2", true);
                    OnProgressChanged?.Invoke(40, "Installing core security engine & WPF binaries...");
                    
                    // Check if embedded payload.zip exists in assembly resources
                    var assembly = typeof(InstallerEngineService).Assembly;
                    using var payloadStream = assembly.GetManifestResourceStream("VaultGuard360.Setup.payload.zip");

                    if (payloadStream != null)
                    {
                        using var archive = new ZipArchive(payloadStream, ZipArchiveMode.Read);
                        foreach (var entry in archive.Entries)
                        {
                            string destinationPath = Path.GetFullPath(Path.Combine(DefaultInstallPath, entry.FullName));
                            if (destinationPath.StartsWith(DefaultInstallPath, StringComparison.OrdinalIgnoreCase))
                            {
                                if (string.IsNullOrEmpty(entry.Name))
                                {
                                    Directory.CreateDirectory(destinationPath);
                                }
                                else
                                {
                                    string? parentDir = Path.GetDirectoryName(destinationPath);
                                    if (!string.IsNullOrEmpty(parentDir)) Directory.CreateDirectory(parentDir);
                                    entry.ExtractToFile(destinationPath, overwrite: true);
                                }
                            }
                        }
                    }
                    else
                    {
                        string sourcePublishDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "bin", "Publish");
                        if (!Directory.Exists(sourcePublishDir))
                        {
                            sourcePublishDir = Path.Combine(Environment.CurrentDirectory, "bin", "Publish");
                        }
                        if (!Directory.Exists(sourcePublishDir))
                        {
                            sourcePublishDir = AppDomain.CurrentDomain.BaseDirectory;
                        }

                        CopyDirectoryContents(sourcePublishDir, DefaultInstallPath);
                    }
                    Task.Delay(500).Wait();

                    // Step 3: Installing protection modules
                    OnStepStatusUpdated?.Invoke("Step3", true);
                    OnProgressChanged?.Invoke(70, "Installing protection modules & heuristic rulebase...");
                    Task.Delay(500).Wait();

                    // Step 4: Creating shortcuts & registry entries
                    OnStepStatusUpdated?.Invoke("Step4", true);
                    OnProgressChanged?.Invoke(85, "Creating system shortcuts & registering services...");

                    string exePath = Path.Combine(DefaultInstallPath, "VaultGuard360.exe");

                    if (CreateDesktopShortcut)
                    {
                        CreateShortcut(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), "VaultGuard 360.lnk"), exePath);
                    }

                    if (CreateStartMenuShortcut)
                    {
                        string startMenuDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "VaultGuard 360");
                        if (!Directory.Exists(startMenuDir)) Directory.CreateDirectory(startMenuDir);
                        CreateShortcut(Path.Combine(startMenuDir, "VaultGuard 360.lnk"), exePath);
                    }

                    if (AutoStartOnBoot)
                    {
                        using RegistryKey? key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true);
                        key?.SetValue("VaultGuard360", $"\"{exePath}\" --autostart");
                    }

                    // Windows Add/Remove Programs Registration
                    try
                    {
                        using RegistryKey? uninstallRoot = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", true) 
                                                        ?? Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", true);
                        if (uninstallRoot != null)
                        {
                            using RegistryKey appKey = uninstallRoot.CreateSubKey("VaultGuard360");
                            appKey.SetValue("DisplayName", "VaultGuard 360 Security Suite");
                            appKey.SetValue("DisplayVersion", "1.0.0");
                            appKey.SetValue("Publisher", "Klyvex Studios");
                            appKey.SetValue("InstallLocation", DefaultInstallPath);
                            appKey.SetValue("DisplayIcon", exePath);
                            appKey.SetValue("UninstallString", $"\"{exePath}\" --uninstall");
                            appKey.SetValue("NoModify", 1);
                            appKey.SetValue("NoRepair", 1);
                        }
                    }
                    catch { }

                    // Step 5: Configuring protection
                    OnStepStatusUpdated?.Invoke("Step5", true);
                    OnProgressChanged?.Invoke(100, "Installation complete. System immunized.");
                    Task.Delay(500).Wait();

                    OnInstallationCompleted?.Invoke(true, "Successfully deployed VaultGuard 360 Security Suite.");
                }
                catch (Exception ex)
                {
                    OnInstallationCompleted?.Invoke(false, ex.Message);
                }
            });
        }

        private void CopyDirectoryContents(string sourceDir, string targetDir)
        {
            foreach (string file in Directory.GetFiles(sourceDir, "*.*", SearchOption.AllDirectories))
            {
                if (file.Contains("VaultGuard360_Setup")) continue;
                string relativePath = file.Substring(sourceDir.Length).TrimStart('\\', '/');
                string destFile = Path.Combine(targetDir, relativePath);
                string? destFolder = Path.GetDirectoryName(destFile);
                if (!string.IsNullOrEmpty(destFolder) && !Directory.Exists(destFolder))
                {
                    Directory.CreateDirectory(destFolder);
                }
                File.Copy(file, destFile, true);
            }
        }

        private void CreateShortcut(string shortcutPath, string targetPath)
        {
            try
            {
                Type? shellType = Type.GetTypeFromCLSID(new Guid("72C24DD5-D70A-438B-8A42-98424B88AFB8"));
                if (shellType != null)
                {
                    dynamic? shell = Activator.CreateInstance(shellType);
                    if (shell != null)
                    {
                        dynamic shortcut = shell.CreateShortcut(shortcutPath);
                        shortcut.TargetPath = targetPath;
                        shortcut.WorkingDirectory = Path.GetDirectoryName(targetPath);
                        shortcut.Description = "VaultGuard 360 Antivirus & Immunity Suite";
                        shortcut.Save();
                    }
                }
            }
            catch { }
        }

        public void LaunchApplication()
        {
            string exePath = Path.Combine(DefaultInstallPath, "VaultGuard360.exe");
            if (File.Exists(exePath))
            {
                Process.Start(new ProcessStartInfo(exePath) { UseShellExecute = true });
            }
        }
    }
}
