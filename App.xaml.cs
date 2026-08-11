using System.Windows;
using VaultGuard360.Services;

namespace VaultGuard360
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            EngineService.Instance.InitializeEmbeddedEngine();
        }
    }
}
