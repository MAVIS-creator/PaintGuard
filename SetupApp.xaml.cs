using System;
using System.IO;
using System.Windows;
using System.Windows.Threading;

namespace VaultGuard360.Setup
{
    public partial class SetupApp : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            DispatcherUnhandledException += App_DispatcherUnhandledException;
            AppDomain.CurrentDomain.UnhandledException += (s, args) =>
            {
                var ex = args.ExceptionObject as Exception;
                string logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "setup_crash.log");
                File.WriteAllText(logPath, $"[{DateTime.Now}] DOMAIN CRASH:\n{ex}\n");
            };

            try
            {
                base.OnStartup(e);
                var window = new InstallerWindow();
                window.Show();
            }
            catch (Exception ex)
            {
                string logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "setup_crash.log");
                File.WriteAllText(logPath, $"[{DateTime.Now}] STARTUP CRASH:\n{ex}\n");
                MessageBox.Show($"Startup Error:\n\n{ex.Message}\n\nInner: {ex.InnerException?.Message}",
                    "VaultGuard 360 Setup Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void App_DispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
        {
            string logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "setup_crash.log");
            File.WriteAllText(logPath, $"[{DateTime.Now}] DISPATCHER CRASH:\n{e.Exception}\n");
            MessageBox.Show($"Error:\n\n{e.Exception.Message}\n\nInner: {e.Exception.InnerException?.Message}",
                "VaultGuard 360 Setup Error", MessageBoxButton.OK, MessageBoxImage.Error);
            e.Handled = true;
        }
    }
}
