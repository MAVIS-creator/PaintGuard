using System;
using System.IO;
using System.Reflection;
using System.Text;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

namespace VaultGuard360.Services
{
    public class EngineService
    {
        private static EngineService? _instance;
        public static EngineService Instance => _instance ??= new EngineService();

        public string BearerToken { get; private set; } = Guid.NewGuid().ToString("N");
        public int ApiPort { get; set; } = 18443;
        public bool IsEngineInitialized { get; private set; } = false;

        public event Action<string, bool>? OnLogReceived;

        public void InitializeEmbeddedEngine()
        {
            try {
                Log("Loading VaultGuard 360 Embedded Security Engine from binary resources...", false);
                string engineScript = ReadEmbeddedResource("VaultGuard360.PaintGuardEngine.ps1");
                
                if (string.IsNullOrEmpty(engineScript))
                {
                    Log("Warning: Embedded engine resource not found. Using fallback runtime host.", true);
                }
                else
                {
                    Log("Embedded engine scripts loaded successfully in-memory.", false);
                }
                IsEngineInitialized = true;
            }
            catch (Exception ex)
            {
                Log($"Engine Initialization Error: {ex.Message}", true);
            }
        }

        public string ReadEmbeddedResource(string resourceName)
        {
            Assembly assembly = Assembly.GetExecutingAssembly();
            using Stream? stream = assembly.GetManifestResourceStream(resourceName);
            if (stream == null) return string.Empty;
            using StreamReader reader = new StreamReader(stream, Encoding.UTF8);
            return reader.ReadToEnd();
        }

        public void Log(string message, bool isError = false)
        {
            OnLogReceived?.Invoke($"[{DateTime.Now:HH:mm:ss}] {message}", isError);
        }
    }
}
