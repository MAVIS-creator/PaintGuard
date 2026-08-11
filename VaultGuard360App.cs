using System;
using System.Drawing;
using System.IO;
using System.Net;
using System.Text;
using System.Diagnostics;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;
using System.Reflection;
using System.Runtime.InteropServices;

[assembly: AssemblyTitle("VaultGuard 360 Antivirus Suite")]
[assembly: AssemblyDescription("VaultGuard 360 Security Control Center - Created by Klyvex Studios")]
[assembly: AssemblyCompany("Klyvex Studios")]
[assembly: AssemblyProduct("VaultGuard 360")]
[assembly: AssemblyCopyright("Copyright © 2026 Klyvex Studios. All rights reserved.")]

namespace VaultGuard360
{
    public class Program
    {
        [STAThread]
        public static void Main(string[] args)
        {
            // Must set IE11 browser emulation BEFORE any WebBrowser control is instantiated
            MainWindow.SetBrowserFeatureControl();

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            
            bool isAutoStart = args != null && Array.Exists(args, a => a.Equals("--autostart", StringComparison.OrdinalIgnoreCase));
            
            bool createdNew;
            using (Mutex mutex = new Mutex(true, "Global\\VaultGuard_SingleInstance_Mutex", out createdNew))
            {
                if (!createdNew)
                {
                    MessageBox.Show("VaultGuard 360 is already running in your system tray.", "VaultGuard 360 - Klyvex Studios", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }
                
                Application.Run(new MainWindow(isAutoStart));
            }
        }
    }

    public class MainWindow : Form
    {
        private WebBrowser webBrowser;
        private NotifyIcon trayIcon;
        private ContextMenuStrip trayMenu;
        private ToolStripMenuItem autoStartMenuItem;
        private Process engineProcess;
        private string bearerToken;
        private int enginePort;
        private System.Windows.Forms.Timer alertPollingTimer;
        private DateTime lastAlertCheck = DateTime.UtcNow;
        private bool isExiting = false;
        private Label titleLabel;
        private Panel headerPanel;

        private const string REG_RUN_KEY = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string APP_NAME = "VaultGuard360";

        public MainWindow(bool startMinimized)
        {
            InitializeComponent();
            SetupTray();
            StartBackendEngine();
            
            if (startMinimized)
            {
                this.WindowState = FormWindowState.Minimized;
                this.Hide();
                this.ShowInTaskbar = false;
                trayIcon.ShowBalloonTip(3000, "VaultGuard 360", "Security Engine active in background. Created by Klyvex Studios.", ToolTipIcon.Info);
            }
        }

        private void InitializeComponent()
        {
            this.Text = "VaultGuard 360 Antivirus - Created by Klyvex Studios";
            this.Size = new Size(1280, 800);
            this.MinimumSize = new Size(960, 600);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Color.FromArgb(15, 23, 42); // Dark #0f172a
            this.ForeColor = Color.White;

            // Load App Icon if available
            string iconPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "icon.ico");
            if (File.Exists(iconPath))
            {
                try { this.Icon = new Icon(iconPath); } catch {}
            }

            // Custom Title Bar Header
            headerPanel = new Panel
            {
                Dock = DockStyle.Top,
                Height = 36,
                BackColor = Color.FromArgb(11, 19, 38)
            };

            titleLabel = new Label
            {
                Text = "🛡️  VaultGuard 360  |  Klyvex Studios Security Suite",
                ForeColor = Color.FromArgb(218, 226, 253),
                Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
                Location = new Point(12, 8),
                AutoSize = true
            };
            headerPanel.Controls.Add(titleLabel);

            // Web Browser Host Control
            webBrowser = new WebBrowser
            {
                Dock = DockStyle.Fill,
                ScriptErrorsSuppressed = true,
                IsWebBrowserContextMenuEnabled = false,
                AllowWebBrowserDrop = false
            };
            
            // Fix IE Emulation mode to latest available Edge/IE11 engine
            SetBrowserFeatureControl();

            this.Controls.Add(webBrowser);
            this.Controls.Add(headerPanel);

            this.FormClosing += MainWindow_FormClosing;
        }

        private void SetupTray()
        {
            trayMenu = new ContextMenuStrip();
            trayMenu.Items.Add("Open Dashboard", null, (s, e) => RestoreWindow());
            trayMenu.Items.Add("Quick System Scan", null, (s, e) => { RestoreWindow(); TriggerQuickScan(); });
            trayMenu.Items.Add(new ToolStripSeparator());
            
            autoStartMenuItem = new ToolStripMenuItem("Run Automatically at Startup", null, (s, e) => ToggleAutoStart());
            autoStartMenuItem.Checked = IsAutoStartEnabled();
            trayMenu.Items.Add(autoStartMenuItem);

            trayMenu.Items.Add("About VaultGuard 360", null, (s, e) => ShowAbout());
            trayMenu.Items.Add("Check for Updates...", null, (s, e) => CheckForUpdates(true));
            trayMenu.Items.Add(new ToolStripSeparator());
            trayMenu.Items.Add("Exit Application", null, (s, e) => ExitApp());

            string iconPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "icon.ico");
            Icon appIcon = SystemIcons.Shield;
            if (File.Exists(iconPath))
            {
                try { appIcon = new Icon(iconPath); } catch {}
            }

            trayIcon = new NotifyIcon
            {
                Text = "VaultGuard 360 - Klyvex Studios",
                Icon = appIcon,
                ContextMenuStrip = trayMenu,
                Visible = true
            };

            trayIcon.DoubleClick += (s, e) => RestoreWindow();
            
            // Auto-check for updates silently on startup
            CheckForUpdates(false);
        }

        private void CheckForUpdates(bool showPromptIfLatest)
        {
            Thread updateThread = new Thread(() =>
            {
                try
                {
                    ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072; // TLS 1.2
                    HttpWebRequest req = (HttpWebRequest)WebRequest.Create("https://api.github.com/repos/MAVIS-creator/PaintGuard/releases/latest");
                    req.UserAgent = "VaultGuard360-AppHost/1.0.0";
                    req.Timeout = 4000;
                    using (HttpWebResponse resp = (HttpWebResponse)req.GetResponse())
                    {
                        using (StreamReader sr = new StreamReader(resp.GetResponseStream()))
                        {
                            string json = sr.ReadToEnd();
                            int tagIdx = json.IndexOf("\"tag_name\":");
                            if (tagIdx != -1)
                            {
                                int start = json.IndexOf("\"", tagIdx + 11) + 1;
                                int end = json.IndexOf("\"", start);
                                string latestTag = json.Substring(start, end - start);
                                
                                if (!latestTag.Equals("v1.0.0", StringComparison.OrdinalIgnoreCase))
                                {
                                    this.Invoke((Action)(() =>
                                    {
                                        trayIcon.ShowBalloonTip(5000, "VaultGuard 360 Update Available", "Version " + latestTag + " is ready on GitHub. Created by Klyvex Studios.", ToolTipIcon.Info);
                                        ShowAnimatedUpdateNotification("VaultGuard 360 Update Available", "A newer version (" + latestTag + ") is available on GitHub Releases.");
                                    }));
                                }
                                else if (showPromptIfLatest)
                                {
                                    this.Invoke((Action)(() =>
                                    {
                                        MessageBox.Show("You are running the latest version of VaultGuard 360 (v1.0.0).", "VaultGuard 360 Auto-Update", MessageBoxButtons.OK, MessageBoxIcon.Information);
                                    }));
                                }
                            }
                        }
                    }
                }
                catch
                {
                    if (showPromptIfLatest)
                    {
                        this.Invoke((Action)(() =>
                        {
                            MessageBox.Show("Could not check for updates right now. Please check your internet connection.", "VaultGuard 360 Update", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                        }));
                    }
                }
            });
            updateThread.IsBackground = true;
            updateThread.Start();
        }

        public void ShowAnimatedUpdateNotification(string title, string message)
        {
            ThreatPopupForm popup = new ThreatPopupForm(title, message, () => {
                try { Process.Start("https://github.com/MAVIS-creator/PaintGuard/releases"); } catch {}
            });
            popup.Show();
        }

        private void StartBackendEngine()
        {
            try {
                // Generate cryptographically secure bearer token
                byte[] tokenBytes = new byte[32];
                using (var rng = System.Security.Cryptography.RandomNumberGenerator.Create())
                {
                    rng.GetBytes(tokenBytes);
                }
                bearerToken = Convert.ToBase64String(tokenBytes).Replace("+", "").Replace("/", "").Replace("=", "");

                // Find open TCP port
                var listener = new System.Net.Sockets.TcpListener(IPAddress.Loopback, 0);
                listener.Start();
                enginePort = ((IPEndPoint)listener.LocalEndpoint).Port;
                listener.Stop();

                string engineScript = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "PaintGuardEngine.ps1");
                if (!File.Exists(engineScript))
                {
                    MessageBox.Show("PaintGuardEngine.ps1 was not found in application directory.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = string.Format("-NoProfile -ExecutionPolicy Bypass -File \"{0}\" -Port {1} -BearerToken \"{2}\"", engineScript, enginePort, bearerToken),
                    WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory,
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    WindowStyle = ProcessWindowStyle.Hidden
                };

                engineProcess = Process.Start(psi);

                // Wait for Engine readiness async
                Thread pollThread = new Thread(() =>
                {
                    bool ready = false;
                    for (int i = 0; i < 20; i++)
                    {
                        Thread.Sleep(300);
                        try
                        {
                            HttpWebRequest req = (HttpWebRequest)WebRequest.Create("http://127.0.0.1:" + enginePort + "/api/status");
                            req.Headers.Add("Authorization", "Bearer " + bearerToken);
                            req.Timeout = 1000;
                            using (HttpWebResponse resp = (HttpWebResponse)req.GetResponse())
                            {
                                if (resp.StatusCode == HttpStatusCode.OK)
                                {
                                    ready = true;
                                    break;
                                }
                            }
                        }
                        catch {}
                    }

                    if (ready)
                    {
                        this.Invoke((Action)(() =>
                        {
                            string url = "http://127.0.0.1:" + enginePort + "/?token=" + bearerToken;
                            webBrowser.Navigate(url);
                            StartAlertMonitoring();
                        }));
                    }
                    else
                    {
                        this.Invoke((Action)(() =>
                        {
                            MessageBox.Show("Engine failed to initialize on port " + enginePort, "VaultGuard Engine Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        }));
                    }
                });
                pollThread.IsBackground = true;
                pollThread.Start();

            } catch (Exception ex) {
                MessageBox.Show("Failed to launch VaultGuard Engine: " + ex.Message, "Startup Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void StartAlertMonitoring()
        {
            alertPollingTimer = new System.Windows.Forms.Timer();
            alertPollingTimer.Interval = 3000; // Check every 3s
            alertPollingTimer.Tick += (s, e) => CheckEngineThreatAlerts();
            alertPollingTimer.Start();
        }

        private void CheckEngineThreatAlerts()
        {
            try
            {
                HttpWebRequest req = (HttpWebRequest)WebRequest.Create("http://127.0.0.1:" + enginePort + "/api/status");
                req.Headers.Add("Authorization", "Bearer " + bearerToken);
                req.Timeout = 1500;
                using (HttpWebResponse resp = (HttpWebResponse)req.GetResponse())
                {
                    using (StreamReader sr = new StreamReader(resp.GetResponseStream()))
                    {
                        string json = sr.ReadToEnd();
                        if (json.Contains("\"QuarantineCount\":") && !json.Contains("\"QuarantineCount\":0"))
                        {
                            // Trigger animated virus alert toast popup
                            ShowAnimatedVirusNotification("Threat Detected & Quarantined", "VaultGuard 360 real-time engine isolated a malicious file into the Quarantine Vault.");
                        }
                    }
                }
            }
            catch {}
        }

        public void ShowAnimatedVirusNotification(string title, string message)
        {
            // Trigger Desktop Tray Balloon Notification
            trayIcon.ShowBalloonTip(5000, title, message, ToolTipIcon.Warning);

            // Launch Animated Custom Popup Toast Form
            ThreatPopupForm popup = new ThreatPopupForm(title, message, () => {
                RestoreWindow();
                webBrowser.Navigate("http://127.0.0.1:" + enginePort + "/?token=" + bearerToken + "#quarantine");
            });
            popup.Show();
        }

        private void RestoreWindow()
        {
            this.Show();
            this.WindowState = FormWindowState.Normal;
            this.ShowInTaskbar = true;
            this.Activate();
        }

        private void TriggerQuickScan()
        {
            if (webBrowser.Document != null)
            {
                webBrowser.Document.InvokeScript("runOneClickRemediation", new object[] { "C:\\" });
            }
        }

        private bool IsAutoStartEnabled()
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(REG_RUN_KEY, false))
                {
                    if (key != null)
                    {
                        object val = key.GetValue(APP_NAME);
                        return val != null;
                    }
                }
            }
            catch {}
            return false;
        }

        private void ToggleAutoStart()
        {
            try
            {
                bool newState = !IsAutoStartEnabled();
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(REG_RUN_KEY, true))
                {
                    if (key != null)
                    {
                        if (newState)
                        {
                            string exePath = Application.ExecutablePath;
                            key.SetValue(APP_NAME, "\"" + exePath + "\" --autostart");
                            MessageBox.Show("VaultGuard 360 will now start automatically when Windows boots.", "Auto-Start Enabled", MessageBoxButtons.OK, MessageBoxIcon.Information);
                        }
                        else
                        {
                            key.DeleteValue(APP_NAME, false);
                            MessageBox.Show("Auto-Start disabled.", "Auto-Start", MessageBoxButtons.OK, MessageBoxIcon.Information);
                        }
                    }
                }
                autoStartMenuItem.Checked = newState;
            }
            catch (Exception ex)
            {
                MessageBox.Show("Could not update registry auto-start: " + ex.Message, "Registry Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void ShowAbout()
        {
            MessageBox.Show(
                "VaultGuard 360 Antivirus & Removable Media Vaccine Suite\n\n" +
                "Version: 1.0.0 Premium Edition\n" +
                "Created by: Klyvex Studios\n" +
                "Engine: PowerShell Real-Time Heuristic Scanner\n" +
                "Architecture: Native .NET Desktop Host with Chromium/Edge Engine\n\n" +
                "© 2026 Klyvex Studios. All rights reserved.",
                "About VaultGuard 360",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
        }

        private void ExitApp()
        {
            isExiting = true;
            if (alertPollingTimer != null) alertPollingTimer.Stop();
            if (trayIcon != null)
            {
                trayIcon.Visible = false;
                trayIcon.Dispose();
            }
            if (engineProcess != null && !engineProcess.HasExited)
            {
                try { engineProcess.Kill(); } catch {}
            }
            Application.Exit();
        }

        private void MainWindow_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (!isExiting && e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;
                this.Hide();
                this.ShowInTaskbar = false;
                trayIcon.ShowBalloonTip(2000, "VaultGuard 360 Active", "App minimized to system tray. Right-click icon to open or exit.", ToolTipIcon.Info);
            }
        }

        public static void SetBrowserFeatureControl()
        {
            try
            {
                var fileName = Path.GetFileName(Process.GetCurrentProcess().MainModule.FileName);
                string[] subKeys = new string[] {
                    @"Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION",
                    @"Software\Wow6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION"
                };

                foreach (string subKey in subKeys)
                {
                    using (var key = Registry.CurrentUser.CreateSubKey(subKey))
                    {
                        if (key != null)
                        {
                            key.SetValue(fileName, 11001, RegistryValueKind.DWord); // 11001 = IE11 Mode
                            key.SetValue("VaultGuard360.exe", 11001, RegistryValueKind.DWord);
                        }
                    }
                }
            }
            catch {}
        }
    }

    // Animated Toast Notification Popup Window
    public class ThreatPopupForm : Form
    {
        private System.Windows.Forms.Timer animTimer;
        private int targetY;
        private Action onClickAction;

        public ThreatPopupForm(string title, string message, Action onClick)
        {
            this.onClickAction = onClick;
            this.FormBorderStyle = FormBorderStyle.None;
            this.ShowInTaskbar = false;
            this.TopMost = true;
            this.Size = new Size(360, 110);
            this.BackColor = Color.FromArgb(30, 41, 59); // Card dark background

            Rectangle workingArea = Screen.PrimaryScreen.WorkingArea;
            int startX = workingArea.Right - this.Width - 20;
            int startY = workingArea.Bottom;
            targetY = workingArea.Bottom - this.Height - 20;

            this.Location = new Point(startX, startY);

            // Container Panel with glowing border
            Panel mainPanel = new Panel
            {
                Dock = DockStyle.Fill,
                BorderStyle = BorderStyle.FixedSingle,
                BackColor = Color.FromArgb(15, 23, 42)
            };

            Label titleLbl = new Label
            {
                Text = "🚨  " + title,
                Font = new Font("Segoe UI", 10f, FontStyle.Bold),
                ForeColor = Color.FromArgb(239, 68, 68), // Danger red
                Location = new Point(14, 12),
                AutoSize = true
            };

            Label msgLbl = new Label
            {
                Text = message,
                Font = new Font("Segoe UI", 8.5f),
                ForeColor = Color.FromArgb(203, 213, 225),
                Location = new Point(14, 38),
                Size = new Size(330, 36)
            };

            Button btnAction = new Button
            {
                Text = "View Quarantine",
                Font = new Font("Segoe UI", 8f, FontStyle.Bold),
                ForeColor = Color.White,
                BackColor = Color.FromArgb(37, 99, 235),
                FlatStyle = FlatStyle.Flat,
                Size = new Size(120, 24),
                Location = new Point(224, 76),
                Cursor = Cursors.Hand
            };
            btnAction.FlatAppearance.BorderSize = 0;
            btnAction.Click += (s, e) => { if (onClickAction != null) onClickAction(); this.Close(); };

            mainPanel.Controls.Add(titleLbl);
            mainPanel.Controls.Add(msgLbl);
            mainPanel.Controls.Add(btnAction);
            this.Controls.Add(mainPanel);

            // Slide Up Animation
            animTimer = new System.Windows.Forms.Timer();
            animTimer.Interval = 15;
            animTimer.Tick += (s, e) =>
            {
                if (this.Top > targetY)
                {
                    this.Top = Math.Max(targetY, this.Top - 8);
                }
                else
                {
                    animTimer.Stop();
                    // Auto-close after 8 seconds
                    var closeTimer = new System.Windows.Forms.Timer { Interval = 8000 };
                    closeTimer.Tick += (cs, ce) => { closeTimer.Stop(); this.Close(); };
                    closeTimer.Start();
                }
            };
            animTimer.Start();
        }
    }
}
