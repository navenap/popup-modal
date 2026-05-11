using Microsoft.Win32;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management;
using System.Net.Http;
using System.Reflection.Emit;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using Forms = System.Windows.Forms;


namespace SurveyApp
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        private Forms.NotifyIcon trayIcon;
        private DispatcherTimer syncTimer;
        private SurveyPopup activePopup;

        public MainWindow()
        {
            InitializeComponent();
            //MessageBox.Show("MainWindow constructor");
            RegisterStartup();

            syncTimer = new DispatcherTimer();

            syncTimer.Interval = TimeSpan.FromHours(1);

            syncTimer.Tick += async (s, e) =>
            {
                await CheckPendingSurvey();
            };

            syncTimer.Start();

            trayIcon = new Forms.NotifyIcon();

            trayIcon.Icon = System.Drawing.SystemIcons.Information;

            trayIcon.Visible = true;

            trayIcon.Text = "Survey Agent Running";

            trayIcon.ContextMenuStrip =
                new Forms.ContextMenuStrip();

            trayIcon.ContextMenuStrip.Items.Add(
                "Exit",
                null,
                (s, e) =>
                {
                    Application.Current.Shutdown();
                });

            trayIcon.DoubleClick += async (s, e) =>
            {
                await CheckPendingSurvey();
            };
        }

        private void RegisterStartup()
        {
            RegistryKey rk = Registry.CurrentUser.OpenSubKey(
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
                true);

            rk.SetValue(
                "SurveyApp",
                System.Reflection.Assembly.GetExecutingAssembly().Location);
        }

        private void StartUnlockMonitoring()
        {
            //MessageBox.Show("Unlock monitoring started");
            SystemEvents.SessionSwitch += SystemEvents_SessionSwitch;
            SurveyPopup.ResetHttpClient();
        }

        private void SystemEvents_SessionSwitch(object sender, SessionSwitchEventArgs e)
        {
            //MessageBox.Show("Session Event: " + e.Reason);

            if (e.Reason == SessionSwitchReason.SessionUnlock)
            {
                Dispatcher.Invoke(async() =>
                {
                    await Task.Delay(5000); // Wait for 5 seconds after unlock to ensure system is ready
                    await CheckPendingSurvey();
                });
            }
        }

        private async Task CheckPendingSurvey()
        {
            //MessageBox.Show("CheckPendingSurvey running");
            try
            {
                var state = StateManager.Load();

                if(state.SurveyCompleted)
                    return;
             
                string today = DateTime.Now.ToString("yyyy-MM-dd");

                // Already answered today
                if (state.LastAnsweredDate == today &&
                    state.AnsweredToday)
                {
                    return;
                }

                bool hasinternet = await HasInternet();

                if (!hasinternet)
                {
                    return;
                }

                if (activePopup == null || !activePopup.IsLoaded)
                {
                    activePopup = new SurveyPopup();

                    activePopup.Show();

                    activePopup.Closed += (s, e) =>
                    {
                        activePopup = null;
                    };

                    activePopup.WindowState = WindowState.Normal;

                    activePopup.Topmost = true;

                    activePopup.Activate();

                    activePopup.Focus();
                }
                else
                {
                    activePopup.Topmost = true;

                    activePopup.Activate();

                    activePopup.Focus();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.ToString());
            }
        }

        private async Task<bool> HasInternet()
        {
            try
            {
                using (var client = new HttpClient())
                {
                    client.Timeout = TimeSpan.FromSeconds(5);

                    var response = await client.GetAsync("https://www.google.com");

                    return response.IsSuccessStatusCode;
                }
            }
            catch
            {
                return false;
            }
        }

        private async void Window_Loaded(object sender, RoutedEventArgs e)
        {
            //MessageBox.Show("Window_Loaded fired");

            StartUnlockMonitoring();

            await CheckPendingSurvey();
            this.Close();

        }

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            trayIcon.Visible = false;

            base.OnClosing(e);
        }

        

        [StructLayout(LayoutKind.Sequential)]
        public struct WindowCompositionAttributeData
        {
            public int Attribute;
            public IntPtr Data;
            public int SizeOfData;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct AccentPolicy
        {
            public int AccentState;
            public int AccentFlags;
            public int GradientColor;
            public int AnimationId;
        }

        [DllImport("user32.dll")]
        public static extern int SetWindowCompositionAttribute(
            IntPtr hwnd,
            ref WindowCompositionAttributeData data
        );

        
    }
}

