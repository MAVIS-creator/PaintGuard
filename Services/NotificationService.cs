using System;
using System.Collections.ObjectModel;

namespace VaultGuard360.Services
{
    public class NotificationItem
    {
        public string Title { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public DateTime Timestamp { get; set; } = DateTime.Now;
        public bool IsAlert { get; set; } = false;
        public string TimeAgo => Timestamp.ToString("HH:mm:ss");
    }

    public class NotificationService
    {
        private static NotificationService? _instance;
        public static NotificationService Instance => _instance ??= new NotificationService();

        public ObservableCollection<NotificationItem> Notifications { get; } = new ObservableCollection<NotificationItem>();
        public event Action<NotificationItem>? OnNewNotificationAdded;

        public NotificationService()
        {
            AddNotification("System Immunized", "VaultGuard 360 Real-Time Engine Active. Created by Klyvex Studios.", false);
        }

        public void AddNotification(string title, string message, bool isAlert = false)
        {
            var item = new NotificationItem { Title = title, Message = message, IsAlert = isAlert };
            Notifications.Insert(0, item);
            OnNewNotificationAdded?.Invoke(item);
        }
    }
}
