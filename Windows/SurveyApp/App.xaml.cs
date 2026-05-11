using System;
using System.Threading;
using System.Windows;

namespace SurveyApp
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        private static Mutex mutex;

        protected override void OnStartup(StartupEventArgs e)
        {
            bool created;

            mutex = new Mutex(true, "SurveyAppMutex", out created);

            if (!created)
            {
                Current.Shutdown();
                return;
            }

            base.OnStartup(e);

            AppDomain.CurrentDomain.UnhandledException += (s, ex) =>
            {
                MessageBox.Show(
                    ex.ExceptionObject.ToString(),
                    "Unhandled Error"
                );
            };

            DispatcherUnhandledException += (s, ex) =>
            {
                MessageBox.Show(
                    ex.Exception.ToString(),
                    "UI Error"
                );

                ex.Handled = true;
            };
        }

        protected override void OnExit(ExitEventArgs e)
        {
            mutex?.ReleaseMutex();

            mutex?.Dispose();

            base.OnExit(e);
        }
    }
}
