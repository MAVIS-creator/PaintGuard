// ==============================================================================
// VaultGuard 360 - Custom WPF Installer (Pure C# - No XAML)
// Created by Klyvex Studios
// ==============================================================================
using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Shapes;
using System.Windows.Threading;
using VaultGuard360.Setup.Services;

namespace VaultGuard360.Setup
{
    public class SetupProgram
    {
        [STAThread]
        public static void Main()
        {
            try
            {
                var app = new Application();
                app.DispatcherUnhandledException += (s, e) =>
                {
                    MessageBox.Show($"Installation Error: {e.Exception.Message}", "VaultGuard 360 Setup Error", MessageBoxButton.OK, MessageBoxImage.Error);
                    e.Handled = true;
                };
                var window = new InstallerMainWindow();
                app.Run(window);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Fatal Installation Error: {ex.Message}", "VaultGuard 360 Setup", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }

    // =========================================================================
    // Color Palette (Stitch Dark Theme)
    // =========================================================================
    public static class Theme
    {
        public static readonly SolidColorBrush Background      = B("#0B1326");
        public static readonly SolidColorBrush Surface         = B("#171F33");
        public static readonly SolidColorBrush SurfaceHigh     = B("#222A3D");
        public static readonly SolidColorBrush SurfaceVariant  = B("#2D3449");
        public static readonly SolidColorBrush SurfaceLowest   = B("#060E20");
        public static readonly SolidColorBrush Primary         = B("#B4C5FF");
        public static readonly SolidColorBrush PrimaryContainer= B("#2563EB");
        public static readonly SolidColorBrush Secondary       = B("#68DBA9");
        public static readonly SolidColorBrush SecondaryContainer = B("#25A475");
        public static readonly SolidColorBrush Tertiary        = B("#FFB77D");
        public static readonly SolidColorBrush Error           = B("#FFB4AB");
        public static readonly SolidColorBrush Outline         = B("#434655");
        public static readonly SolidColorBrush TextMain        = B("#DAE2FD");
        public static readonly SolidColorBrush TextMuted       = B("#C3C6D7");
        public static readonly SolidColorBrush White           = B("#FFFFFF");
        public static readonly SolidColorBrush Transparent     = new SolidColorBrush(Colors.Transparent);

        private static SolidColorBrush B(string hex)
        {
            var b = new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex));
            b.Freeze();
            return b;
        }
    }

    // =========================================================================
    // Main Installer Window (Built entirely in C#)
    // =========================================================================
    public class InstallerMainWindow : Window
    {
        // Welcome View
        private Grid _welcomeView = null!;
        private TextBox _installPathBox = null!;
        private CheckBox _desktopShortcutCheck = null!;
        private CheckBox _startMenuCheck = null!;
        private CheckBox _autoStartCheck = null!;

        // Progress View
        private Grid _progressView = null!;
        private TextBlock _installingTitle = null!;
        private TextBlock _percentText = null!;
        private ProgressBar _progressBar = null!;
        private TextBlock _statusText = null!;
        private Button _launchButton = null!;

        // Step badges & statuses
        private TextBlock[] _stepBadges = null!;
        private TextBlock[] _stepStatuses = null!;

        public InstallerMainWindow()
        {
            Title = "VaultGuard 360 - Setup";
            Width = 940;
            Height = 620;
            MinWidth = 800;
            MinHeight = 520;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            WindowStyle = WindowStyle.None;
            AllowsTransparency = true;
            Background = Brushes.Transparent;

            Content = BuildLayout();
        }

        // =====================================================================
        // Build the entire UI tree
        // =====================================================================
        private UIElement BuildLayout()
        {
            var outerBorder = new Border
            {
                Background = Theme.Background,
                BorderBrush = Theme.Outline,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(12),
                ClipToBounds = true
            };

            var rootGrid = new Grid();
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(40, GridUnitType.Pixel) });
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

            // Custom Title Bar
            var titleBar = BuildTitleBar();
            Grid.SetRow(titleBar, 0);
            rootGrid.Children.Add(titleBar);

            // Main Content Area
            var contentGrid = new Grid();
            Grid.SetRow(contentGrid, 1);

            _welcomeView = BuildWelcomeView();
            contentGrid.Children.Add(_welcomeView);

            _progressView = BuildProgressView();
            _progressView.Visibility = Visibility.Collapsed;
            contentGrid.Children.Add(_progressView);

            rootGrid.Children.Add(contentGrid);
            outerBorder.Child = rootGrid;
            return outerBorder;
        }

        private Grid BuildTitleBar()
        {
            var grid = new Grid { Background = Theme.SurfaceLowest, Height = 40 };
            grid.MouseLeftButtonDown += (s, e) => { if (e.LeftButton == System.Windows.Input.MouseButtonState.Pressed) DragMove(); };

            var stackLeft = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(16, 0, 0, 0) };
            stackLeft.Children.Add(new TextBlock { Text = "🛡️", FontSize = 16, Margin = new Thickness(0, 0, 8, 0), VerticalAlignment = VerticalAlignment.Center });
            stackLeft.Children.Add(new TextBlock { Text = "VaultGuard 360 - Setup", FontSize = 13, FontWeight = FontWeights.Medium, Foreground = Theme.TextMain, VerticalAlignment = VerticalAlignment.Center });
            grid.Children.Add(stackLeft);

            var stackRight = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 8, 0) };

            var minBtn = new Button
            {
                Content = "—",
                Width = 36, Height = 28,
                Background = Brushes.Transparent,
                Foreground = Theme.TextMuted,
                BorderThickness = new Thickness(0),
                FontSize = 14,
                Cursor = System.Windows.Input.Cursors.Hand
            };
            minBtn.Click += (s, e) => WindowState = WindowState.Minimized;

            var closeBtn = new Button
            {
                Content = "✕",
                Width = 36, Height = 28,
                Background = Brushes.Transparent,
                Foreground = Theme.TextMuted,
                BorderThickness = new Thickness(0),
                FontSize = 13,
                Cursor = System.Windows.Input.Cursors.Hand
            };
            closeBtn.Click += (s, e) => Close();

            stackRight.Children.Add(minBtn);
            stackRight.Children.Add(closeBtn);
            grid.Children.Add(stackRight);

            return grid;
        }

        // =====================================================================
        // WELCOME VIEW
        // =====================================================================
        private Grid BuildWelcomeView()
        {
            var grid = new Grid();
            var stack = new StackPanel
            {
                VerticalAlignment = VerticalAlignment.Center,
                HorizontalAlignment = HorizontalAlignment.Center,
                Width = 600
            };

            // --- Logo Header ---
            var logoRow = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 0, 0, 28) };
            logoRow.Children.Add(new TextBlock { Text = "🛡️", FontSize = 44, Margin = new Thickness(0, 0, 14, 0), VerticalAlignment = VerticalAlignment.Center });
            var titleStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            titleStack.Children.Add(new TextBlock { Text = "VaultGuard 360", FontSize = 32, FontWeight = FontWeights.Bold, Foreground = Theme.Primary });
            titleStack.Children.Add(new TextBlock { Text = "High-Security Antivirus & Immunity Suite", FontSize = 13, Foreground = Theme.TextMuted });
            logoRow.Children.Add(titleStack);
            stack.Children.Add(logoRow);

            // --- Glowing Shield Graphic ---
            var shieldBorder = new Border
            {
                Width = 200, Height = 160,
                Background = Theme.Surface,
                BorderBrush = Theme.Outline,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(10),
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(0, 0, 0, 28)
            };
            var shieldGrid = new Grid { VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center };
            var glowEllipse = new Ellipse
            {
                Width = 110, Height = 110,
                Stroke = Theme.Primary,
                StrokeThickness = 3,
                Effect = new DropShadowEffect { Color = (Color)ColorConverter.ConvertFromString("#2563EB"), BlurRadius = 30, ShadowDepth = 0, Opacity = 0.8 }
            };
            shieldGrid.Children.Add(glowEllipse);
            shieldGrid.Children.Add(new TextBlock { Text = "🛡️", FontSize = 52, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center });
            shieldBorder.Child = shieldGrid;
            stack.Children.Add(shieldBorder);

            // --- Tagline ---
            stack.Children.Add(new TextBlock
            {
                Text = "Your system deserves serious protection.",
                FontSize = 15, Foreground = Theme.TextMuted,
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(0, 0, 0, 24)
            });

            // --- INSTALL NOW Button ---
            var installBtn = MakeButton("⚡  INSTALL NOW", Theme.PrimaryContainer, Theme.White, 15, new Thickness(36, 14, 36, 14));
            installBtn.HorizontalAlignment = HorizontalAlignment.Center;
            installBtn.Margin = new Thickness(0, 0, 0, 20);
            installBtn.Click += InstallNow_Click;
            stack.Children.Add(installBtn);

            // --- Advanced Options ---
            var expander = new Expander
            {
                Header = "Advanced Installation Options",
                Foreground = Theme.TextMuted,
                FontSize = 12,
                HorizontalAlignment = HorizontalAlignment.Center,
                Width = 520
            };
            var optsBorder = new Border
            {
                Background = Theme.SurfaceVariant,
                BorderBrush = Theme.Outline,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(14),
                Margin = new Thickness(0, 10, 0, 0)
            };
            var optsStack = new StackPanel();
            optsStack.Children.Add(new TextBlock { Text = "Installation Location:", Foreground = Theme.TextMain, FontSize = 12, FontWeight = FontWeights.Bold, Margin = new Thickness(0, 0, 0, 6) });
            _installPathBox = new TextBox
            {
                Text = @"C:\Program Files\VaultGuard 360",
                Background = Theme.SurfaceLowest,
                Foreground = Theme.TextMain,
                BorderBrush = Theme.Outline,
                Padding = new Thickness(8),
                FontFamily = new FontFamily("Consolas"),
                FontSize = 12,
                Margin = new Thickness(0, 0, 0, 12)
            };
            optsStack.Children.Add(_installPathBox);
            _desktopShortcutCheck = new CheckBox { Content = "Create Desktop Shortcut", IsChecked = true, Foreground = Theme.TextMain, Margin = new Thickness(0, 0, 0, 6) };
            _startMenuCheck = new CheckBox { Content = "Create Start Menu Shortcut", IsChecked = true, Foreground = Theme.TextMain, Margin = new Thickness(0, 0, 0, 6) };
            _autoStartCheck = new CheckBox { Content = "Run VaultGuard 360 automatically when Windows starts", IsChecked = true, Foreground = Theme.TextMain };
            optsStack.Children.Add(_desktopShortcutCheck);
            optsStack.Children.Add(_startMenuCheck);
            optsStack.Children.Add(_autoStartCheck);
            optsBorder.Child = optsStack;
            expander.Content = optsBorder;
            stack.Children.Add(expander);

            // --- Attribution ---
            stack.Children.Add(new TextBlock
            {
                Text = "Created by Klyvex Studios  •  v1.0.0",
                FontSize = 11, Foreground = Theme.TextMuted,
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(0, 24, 0, 0)
            });

            grid.Children.Add(stack);
            return grid;
        }

        // =====================================================================
        // PROGRESS VIEW
        // =====================================================================
        private Grid BuildProgressView()
        {
            var grid = new Grid { Margin = new Thickness(30) };
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(6, GridUnitType.Star) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(20, GridUnitType.Pixel) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(4, GridUnitType.Star) });

            // --- LEFT: Progress Panel ---
            var leftBorder = MakeCard();
            var leftStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };

            var headerRow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 20) };
            headerRow.Children.Add(new TextBlock { Text = "🛡️", FontSize = 26, Margin = new Thickness(0, 0, 10, 0) });
            headerRow.Children.Add(new TextBlock { Text = "VaultGuard 360", FontSize = 22, FontWeight = FontWeights.Bold, Foreground = Theme.Primary, VerticalAlignment = VerticalAlignment.Center });
            leftStack.Children.Add(headerRow);

            _installingTitle = new TextBlock { Text = "Installing System Protection...", FontSize = 20, FontWeight = FontWeights.Bold, Foreground = Theme.TextMain, Margin = new Thickness(0, 0, 0, 6) };
            leftStack.Children.Add(_installingTitle);
            leftStack.Children.Add(new TextBlock { Text = "Securing your digital environment. Do not restart your computer.", FontSize = 12, Foreground = Theme.TextMuted, Margin = new Thickness(0, 0, 0, 30) });

            // Progress percentage row
            var pctRow = new DockPanel { Margin = new Thickness(0, 0, 0, 8) };
            pctRow.Children.Add(new TextBlock { Text = "Overall Progress", FontSize = 13, Foreground = Theme.TextMain });
            _percentText = new TextBlock { Text = "0%", FontSize = 24, FontWeight = FontWeights.Bold, Foreground = Theme.Primary, HorizontalAlignment = HorizontalAlignment.Right };
            DockPanel.SetDock(_percentText, Dock.Right);
            pctRow.Children.Add(_percentText);
            leftStack.Children.Add(pctRow);

            // Progress bar
            _progressBar = new ProgressBar
            {
                Value = 0, Maximum = 100, Height = 14,
                Background = Theme.SurfaceHigh,
                Foreground = Theme.PrimaryContainer,
                BorderThickness = new Thickness(0),
                Margin = new Thickness(0, 0, 0, 12)
            };
            leftStack.Children.Add(_progressBar);

            _statusText = new TextBlock { Text = "Preparing deployment sequence...", FontFamily = new FontFamily("Consolas"), FontSize = 11, Foreground = Theme.TextMuted };
            leftStack.Children.Add(_statusText);

            leftBorder.Child = leftStack;
            Grid.SetColumn(leftBorder, 0);
            grid.Children.Add(leftBorder);

            // --- RIGHT: Deployment Sequence ---
            var rightBorder = MakeCard();
            var rightStack = new StackPanel();
            rightStack.Children.Add(new TextBlock
            {
                Text = "DEPLOYMENT SEQUENCE",
                FontFamily = new FontFamily("Consolas"),
                FontSize = 11, FontWeight = FontWeights.Bold,
                Foreground = Theme.TextMuted,
                Margin = new Thickness(0, 0, 0, 18)
            });

            string[] stepNames = { "Preparing installation", "Installing core engine", "Installing protection modules", "Creating system services", "Configuring protection" };
            _stepBadges = new TextBlock[5];
            _stepStatuses = new TextBlock[5];

            for (int i = 0; i < 5; i++)
            {
                var stepRow = new DockPanel { Margin = new Thickness(0, 0, 0, 16) };
                _stepBadges[i] = new TextBlock { Text = "○", FontSize = 14, Foreground = Theme.TextMuted, Margin = new Thickness(0, 0, 10, 0), VerticalAlignment = VerticalAlignment.Top };
                stepRow.Children.Add(_stepBadges[i]);
                var stepInfo = new StackPanel();
                stepInfo.Children.Add(new TextBlock { Text = stepNames[i], FontSize = 12, FontWeight = FontWeights.Bold, Foreground = Theme.TextMain });
                _stepStatuses[i] = new TextBlock { Text = "PENDING", FontFamily = new FontFamily("Consolas"), FontSize = 10, Foreground = Theme.TextMuted };
                stepInfo.Children.Add(_stepStatuses[i]);
                stepRow.Children.Add(stepInfo);
                rightStack.Children.Add(stepRow);
            }

            // Launch button (hidden until complete)
            _launchButton = MakeButton("🚀  LAUNCH VAULTGUARD 360", Theme.PrimaryContainer, Theme.White, 13, new Thickness(14, 12, 14, 12));
            _launchButton.Visibility = Visibility.Collapsed;
            _launchButton.HorizontalAlignment = HorizontalAlignment.Stretch;
            _launchButton.Margin = new Thickness(0, 10, 0, 0);
            _launchButton.Click += (s, e) =>
            {
                InstallerEngineService.Instance.LaunchApplication();
                Close();
            };
            rightStack.Children.Add(_launchButton);

            rightBorder.Child = rightStack;
            Grid.SetColumn(rightBorder, 2);
            grid.Children.Add(rightBorder);

            return grid;
        }

        // =====================================================================
        // Helpers
        // =====================================================================
        private Border MakeCard()
        {
            return new Border
            {
                Background = Theme.Surface,
                BorderBrush = Theme.Outline,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(10),
                Padding = new Thickness(24),
                Effect = new DropShadowEffect { BlurRadius = 20, Color = Colors.Black, Opacity = 0.4, ShadowDepth = 4 }
            };
        }

        private Button MakeButton(string text, SolidColorBrush bg, SolidColorBrush fg, double fontSize, Thickness padding)
        {
            var btn = new Button
            {
                Content = text,
                FontSize = fontSize,
                FontWeight = FontWeights.Bold,
                Foreground = fg,
                Padding = padding,
                Cursor = System.Windows.Input.Cursors.Hand,
                BorderThickness = new Thickness(0)
            };
            // Custom template for rounded corners
            var template = new ControlTemplate(typeof(Button));
            var borderFactory = new FrameworkElementFactory(typeof(Border));
            borderFactory.SetValue(Border.BackgroundProperty, bg);
            borderFactory.SetValue(Border.CornerRadiusProperty, new CornerRadius(6));
            borderFactory.SetValue(Border.PaddingProperty, padding);
            var contentFactory = new FrameworkElementFactory(typeof(ContentPresenter));
            contentFactory.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
            contentFactory.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
            borderFactory.AppendChild(contentFactory);
            template.VisualTree = borderFactory;
            btn.Template = template;
            return btn;
        }

        private void UpdateStep(int index, bool done)
        {
            _stepBadges[index].Text = done ? "✓" : "●";
            _stepBadges[index].Foreground = done ? Theme.Secondary : Theme.Primary;
            _stepStatuses[index].Text = done ? "SUCCESS" : "IN PROGRESS";
            _stepStatuses[index].Foreground = done ? Theme.Secondary : Theme.Primary;
        }

        // =====================================================================
        // Event Handlers
        // =====================================================================
        private async void InstallNow_Click(object sender, RoutedEventArgs e)
        {
            var engine = InstallerEngineService.Instance;
            engine.DefaultInstallPath = _installPathBox.Text;
            engine.CreateDesktopShortcut = _desktopShortcutCheck.IsChecked == true;
            engine.CreateStartMenuShortcut = _startMenuCheck.IsChecked == true;
            engine.AutoStartOnBoot = _autoStartCheck.IsChecked == true;

            _welcomeView.Visibility = Visibility.Collapsed;
            _progressView.Visibility = Visibility.Visible;

            engine.OnProgressChanged += (pct, msg) => Dispatcher.Invoke(() =>
            {
                _progressBar.Value = pct;
                _percentText.Text = $"{pct}%";
                _statusText.Text = msg;
            });

            engine.OnStepStatusUpdated += (stepId, done) => Dispatcher.Invoke(() =>
            {
                int idx = int.Parse(stepId.Replace("Step", "")) - 1;
                UpdateStep(idx, done);
            });

            engine.OnInstallationCompleted += (ok, msg) => Dispatcher.Invoke(() =>
            {
                if (ok)
                {
                    _installingTitle.Text = "Installation Complete!";
                    _statusText.Text = "VaultGuard 360 is ready. Your system is now protected.";
                    _launchButton.Visibility = Visibility.Visible;
                }
                else
                {
                    _installingTitle.Text = "Installation Failed";
                    _statusText.Text = $"Error: {msg}";
                }
            });

            await engine.StartInstallationAsync();
        }
    }
}
