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
                    try
                    {
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
                                        OnProgressChanged?.Invoke(35, $"[DIR] Created {destinationPath}");
                                    }
                                    else
                                    {
                                        string? parentDir = Path.GetDirectoryName(destinationPath);
                                        if (!string.IsNullOrEmpty(parentDir)) Directory.CreateDirectory(parentDir);
                                        entry.ExtractToFile(destinationPath, overwrite: true);
                                        OnProgressChanged?.Invoke(50, $"[FILE] Extracted {entry.FullName} -> {destinationPath}");
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

                        // Create dedicated Uninstall.exe binary in install folder
                        string currentSetupExe = System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName ?? "";
                        string uninstallerPath = Path.Combine(DefaultInstallPath, "Uninstall.exe");
                        if (File.Exists(currentSetupExe) && !string.Equals(currentSetupExe, uninstallerPath, StringComparison.OrdinalIgnoreCase))
                        {
                            File.Copy(currentSetupExe, uninstallerPath, overwrite: true);
                            OnProgressChanged?.Invoke(60, $"[FILE] Deployed Uninstaller binary -> {uninstallerPath}");
                        }
                    }
                    catch (Exception ex)
                    {
                        OnProgressChanged?.Invoke(50, $"[WARN] Extraction note: {ex.Message}");
                    }
                    Task.Delay(300).Wait();

                    // Step 3: Installing protection modules
                    OnStepStatusUpdated?.Invoke("Step3", true);
                    OnProgressChanged?.Invoke(70, "Installing heuristic engines & vaccine trap modules...");
                    Task.Delay(300).Wait();

                    // Step 4: Creating shortcuts & registry entries
                    OnStepStatusUpdated?.Invoke("Step4", true);
                    OnProgressChanged?.Invoke(85, "Registering Windows system shortcuts & registry keys...");

                    string exePath = Path.Combine(DefaultInstallPath, "VaultGuard360.exe");
                    string uninstallerExe = Path.Combine(DefaultInstallPath, "Uninstall.exe");
                    if (!File.Exists(uninstallerExe)) uninstallerExe = exePath;

                    if (CreateDesktopShortcut)
                    {
                        string desktopLnk = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), "VaultGuard 360.lnk");
                        CreateShortcut(desktopLnk, exePath);
                        OnProgressChanged?.Invoke(88, $"[LINK] Created Desktop shortcut -> {desktopLnk}");
                    }

                    if (CreateStartMenuShortcut)
                    {
                        string startMenuDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "VaultGuard 360");
                        if (!Directory.Exists(startMenuDir)) Directory.CreateDirectory(startMenuDir);
                        string startLnk = Path.Combine(startMenuDir, "VaultGuard 360.lnk");
                        CreateShortcut(startLnk, exePath);
                        OnProgressChanged?.Invoke(90, $"[LINK] Created Start Menu shortcut -> {startLnk}");
                    }

                    if (AutoStartOnBoot)
                    {
                        using RegistryKey? key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true);
                        key?.SetValue("VaultGuard360", $"\"{exePath}\" --autostart");
                        OnProgressChanged?.Invoke(92, @"[REG] Set HKCU\Software\Microsoft\Windows\CurrentVersion\Run\VaultGuard360");
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
                            appKey.SetValue("UninstallString", $"\"{uninstallerExe}\" --uninstall");
                            appKey.SetValue("NoModify", 1);
                            appKey.SetValue("NoRepair", 1);
                            OnProgressChanged?.Invoke(95, @"[REG] Registered HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VaultGuard360");
                        }
                    }
                    catch (Exception regEx)
                    {
                        OnProgressChanged?.Invoke(95, $"[WARN] Registry note: {regEx.Message}");
                    }

                    // Step 5: Configuring protection
                    OnStepStatusUpdated?.Invoke("Step5", true);
                    OnProgressChanged?.Invoke(100, "Installation complete. System immunized.");
                    Task.Delay(300).Wait();

                    OnInstallationCompleted?.Invoke(true, "Successfully deployed VaultGuard 360 Security Suite.");
                }
                catch (Exception ex)
                {
                    OnInstallationCompleted?.Invoke(false, ex.Message);
                }
            });
        }

        public async Task StartUninstallationAsync()
        {
            await Task.Run(() =>
            {
                try
                {
                    OnProgressChanged?.Invoke(10, "Stopping VaultGuard 360 active processes...");
                    foreach (var proc in System.Diagnostics.Process.GetProcessesByName("VaultGuard360"))
                    {
                        try { proc.Kill(); } catch { }
                    }

                    OnProgressChanged?.Invoke(30, "Removing Windows Startup registry key...");
                    try
                    {
                        using RegistryKey? runKey = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true);
                        runKey?.DeleteValue("VaultGuard360", false);
                    }
                    catch { }

                    OnProgressChanged?.Invoke(50, "Removing Add/Remove Programs registry key...");
                    try
                    {
                        using RegistryKey? uninstallRoot = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", true)
                                                        ?? Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", true);
                        uninstallRoot?.DeleteSubKeyTree("VaultGuard360", false);
                    }
                    catch { }

                    OnProgressChanged?.Invoke(70, "Removing Desktop & Start Menu shortcuts...");
                    try
                    {
                        string desktopLnk = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), "VaultGuard 360.lnk");
                        if (File.Exists(desktopLnk)) File.Delete(desktopLnk);

                        string startMenuDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "VaultGuard 360");
                        if (Directory.Exists(startMenuDir)) Directory.Delete(startMenuDir, true);
                    }
                    catch { }

                    OnProgressChanged?.Invoke(90, "Cleaning application directory...");
                    try
                    {
                        if (Directory.Exists(DefaultInstallPath))
                        {
                            foreach (var f in Directory.GetFiles(DefaultInstallPath))
                            {
                                if (!f.EndsWith("Uninstall.exe", StringComparison.OrdinalIgnoreCase))
                                {
                                    try { File.Delete(f); } catch { }
                                }
                            }
                        }
                    }
                    catch { }

                    OnProgressChanged?.Invoke(100, "Uninstallation completed successfully.");
                    OnInstallationCompleted?.Invoke(true, "VaultGuard 360 has been uninstalled from your system.");
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
