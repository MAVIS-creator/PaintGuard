using System;
using System.ComponentModel;
using System.Net.Http;
using System.Runtime.CompilerServices;
using System.Text;
using System.Threading.Tasks;
using VaultGuard360.Services;

namespace VaultGuard360.ViewModels
{
    public class SettingsViewModel : INotifyPropertyChanged
    {
        public UsbWatcherService UsbService => UsbWatcherService.Instance;
        public EngineService EngineService => EngineService.Instance;

        public bool IsUsbVaccineEnabled
        {
            get => UsbService.IsAutoVaccineEnabled;
            set { UsbService.IsAutoVaccineEnabled = value; OnPropertyChanged(); }
        }

        public bool IsAutoRunHardened
        {
            get => UsbService.IsAutoRunHardened;
            set { UsbService.IsAutoRunHardened = value; OnPropertyChanged(); }
        }

        public string BearerToken => EngineService.Instance.BearerToken;
        public int ApiPort => EngineService.Instance.ApiPort;

        // Support & Feedback Form Fields
        private string _contactName = string.Empty;
        public string ContactName
        {
            get => _contactName;
            set { _contactName = value; OnPropertyChanged(); }
        }

        private string _contactEmail = string.Empty;
        public string ContactEmail
        {
            get => _contactEmail;
            set { _contactEmail = value; OnPropertyChanged(); }
        }

        private string _contactSubject = "VaultGuard 360 Support Inquiry";
        public string ContactSubject
        {
            get => _contactSubject;
            set { _contactSubject = value; OnPropertyChanged(); }
        }

        private string _contactMessage = string.Empty;
        public string ContactMessage
        {
            get => _contactMessage;
            set { _contactMessage = value; OnPropertyChanged(); }
        }

        private string _supportStatus = string.Empty;
        public string SupportStatus
        {
            get => _supportStatus;
            set { _supportStatus = value; OnPropertyChanged(); }
        }

        private bool _isSending = false;
        public bool IsSending
        {
            get => _isSending;
            set { _isSending = value; OnPropertyChanged(); }
        }

        public async Task SendSupportMessageAsync()
        {
            if (string.IsNullOrWhiteSpace(ContactEmail) || string.IsNullOrWhiteSpace(ContactMessage))
            {
                SupportStatus = "Please provide your email address and message.";
                return;
            }

            IsSending = true;
            SupportStatus = "Sending message to admin@highqsolidacademy.com...";

            try
            {
                using var client = new HttpClient();
                client.Timeout = TimeSpan.FromSeconds(10);
                
                var jsonPayload = $"{{\"name\":\"{ContactName}\",\"email\":\"{ContactEmail}\",\"subject\":\"{ContactSubject}\",\"message\":\"{ContactMessage}\"}}";
                var content = new StringContent(jsonPayload, Encoding.UTF8, "application/json");
                
                var response = await client.PostAsync("https://formsubmit.co/ajax/admin@highqsolidacademy.com", content);
                if (response.IsSuccessStatusCode)
                {
                    SupportStatus = "Message sent successfully to High Q Solid Academy Support (admin@highqsolidacademy.com).";
                    NotificationService.Instance.AddNotification("Support Ticket", "Sent support inquiry to admin@highqsolidacademy.com", false);
                    ContactMessage = string.Empty;
                }
                else
                {
                    OpenMailClientFallback();
                }
            }
            catch
            {
                OpenMailClientFallback();
            }
            finally
            {
                IsSending = false;
            }
        }

        private void OpenMailClientFallback()
        {
            try
            {
                string mailtoUri = $"mailto:admin@highqsolidacademy.com?subject={Uri.EscapeDataString(ContactSubject)}&body={Uri.EscapeDataString($"From: {ContactName} ({ContactEmail})\n\n{ContactMessage}")}";
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(mailtoUri) { UseShellExecute = true });
                SupportStatus = "Opened default mail client with message pre-filled to admin@highqsolidacademy.com.";
            }
            catch (Exception ex)
            {
                SupportStatus = $"Direct support email: admin@highqsolidacademy.com ({ex.Message})";
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        }
    }
}
