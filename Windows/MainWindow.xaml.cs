using System;
using System.Collections.Generic;
using System.Linq;
using System.Management;
using System.Net.Http;
using System.Reflection.Emit;
using System.Runtime.InteropServices;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;


namespace SurveyApp
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        //private readonly string triggerFile = @"C:\ProgramData\SurveyTrigger.txt";
        private string API_URL = "https://script.google.com/macros/s/AKfycbygRIt1-Z2Ppvo8GTGFx28ktI8nhHK1eFkB99cp0LQReSV86gR8YZtnMNhn6xa3dD7d/exec";

        private HttpClient client = new HttpClient();
        List<Question> questions = new List<Question>();
        //Dictionary<string, TextBox> answerInputs = new Dictionary<string, TextBox>();
        Dictionary<string, WrapPanel> answerInputs = new Dictionary<string, WrapPanel>();
        private bool allowClose = false;
        private bool isSubmitting = false;
        private bool isAdminDialogOpen = false;

        public MainWindow()
        {
            InitializeComponent();

            // Make sure window comes to front
            //this.WindowStyle = WindowStyle.None;
            //this.WindowState = WindowState.Maximized;

            this.Left = 0; this.Top = 0;
            this.Width = SystemParameters.VirtualScreenWidth;
            this.Height = SystemParameters.VirtualScreenHeight;
            this.Topmost = true;

            this.Loaded += (s, e) =>
            {
                var windowHelper = new WindowInteropHelper(this);

                AccentPolicy accent = new AccentPolicy();
                accent.AccentState = 3; // Blur behind

                int size = Marshal.SizeOf(accent);
                IntPtr ptr = Marshal.AllocHGlobal(size);
                Marshal.StructureToPtr(accent, ptr, false);

                WindowCompositionAttributeData data = new WindowCompositionAttributeData();
                data.Attribute = 19;
                data.SizeOfData = size;
                data.Data = ptr;

                SetWindowCompositionAttribute(windowHelper.Handle, ref data);

                Marshal.FreeHGlobal(ptr);
            };
        }

        async void LoadQuestions()
        {
            try
            {
                LoadingText.Visibility = Visibility.Visible;
                MainModal.Visibility = Visibility.Collapsed;

                string serial = GetSerialNumber();

                string url =
                    $"{API_URL}?device_serial={Uri.EscapeDataString(serial)}";

                var response = await client.GetStringAsync(url);
                //MessageBox.Show(response);

                var serializer = new JavaScriptSerializer();

                // ✅ THIS IS THE CORRECT LINE (deserialize)
                questions = serializer.Deserialize<List<Question>>(response);

                if (questions == null || questions.Count == 0)
                {
                    allowClose = true;
                    Application.Current.Shutdown();
                    return;
                }

                // ✅ PICK RANDOM QUESTION
                var random = new Random();
                var q = questions[random.Next(questions.Count)];

                // Clear previous (important)
                QuestionsPanel.Children.Clear();

                var text = new TextBlock
                {
                    Text = q.question,
                    FontSize = 22,
                    TextWrapping = TextWrapping.Wrap,
                    Foreground = Brushes.Black,
                    Margin = new Thickness(0, 10, 0, 5)
                };

                var scalePanel = new WrapPanel
                {
                    Orientation = Orientation.Horizontal,
                    Margin = new Thickness(0, 0, 0, 10)
                };

                string[] options = {
                    "Strongly Disagree",
                    "Disagree",
                    "Moderate",
                    "Agree",
                    "Strongly Agree"
                };

                foreach (var option in options)
                {
                    var rb = new RadioButton
                    {
                        Content = option,
                        GroupName = q.id,   
                        Margin = new Thickness(5),
                        Padding = new Thickness(10,6,10,6),
                        FontSize = 14,
                        Cursor = Cursors.Hand
                    };

                    // Style like Selectable buttons
                    rb.Style = (Style)FindResource("RadioButtonCardStyle");

                    rb.Checked += (s, e) =>
                    {
                        scalePanel.ClearValue(WrapPanel.BackgroundProperty);
                    };

                    scalePanel.Children.Add(rb);
                }

                scalePanel.Opacity = 0;
                MainModal.Opacity = 0;
                
                var fade = new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(300));
                MainModal.BeginAnimation(UIElement.OpacityProperty, fade);
                scalePanel.BeginAnimation(UIElement.OpacityProperty, fade);

                QuestionsPanel.Children.Add(text);
                QuestionsPanel.Children.Add(scalePanel);

                answerInputs.Clear();
                answerInputs[q.id] = scalePanel;

                /*
                var input = new TextBox
                {
                    AcceptsReturn = true,
                    TextWrapping = TextWrapping.Wrap,
                    MinHeight = 30,
                    MaxHeight = 150,
                    VerticalScrollBarVisibility = ScrollBarVisibility.Disabled,
                    Margin = new Thickness(0, 0, 0, 10)
                };

                // Auto-resize height based on content
                input.TextChanged += (s, e) =>
                {
                    if (!string.IsNullOrWhiteSpace(input.Text))
                    {
                        input.ClearValue(TextBox.BorderBrushProperty);  
                        input.ClearValue(TextBox.BorderThicknessProperty);
                    }
                    input.Height = Double.NaN;
                    input.Measure(new Size(input.ActualWidth, double.PositiveInfinity));
                    input.Height = input.DesiredSize.Height;
                };

                // Auto focus
                input.Loaded += (s, e) => input.Focus();

                QuestionsPanel.Children.Add(text);
                QuestionsPanel.Children.Add(input);

                answerInputs.Clear();
                answerInputs[q.id] = input;
                */

                // Keep only selected question
                questions = new List<Question> { q };

                LoadingText.Visibility = Visibility.Collapsed;
                MainModal.Visibility = Visibility.Visible;
                SubmitButton.Visibility = Visibility.Visible;
                SubmitButton.IsEnabled = true;

            }
            catch (Exception ex)
            {
                MessageBox.Show("Error loading questions: " + ex.Message);

                // Fail-safe (don’t lock user)
                allowClose = true;
                Application.Current.Shutdown();
            }
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            DoubleAnimation scaleAnim = new DoubleAnimation
            {
                From = 0.8,
                To = 1.0,
                Duration = TimeSpan.FromMilliseconds(200)
            };

            scaleTransform.BeginAnimation(System.Windows.Media.ScaleTransform.ScaleXProperty, scaleAnim);
            scaleTransform.BeginAnimation(System.Windows.Media.ScaleTransform.ScaleYProperty, scaleAnim);
            LoadQuestions();

            this.Activate();
            this.Focus();
            Keyboard.Focus(this);

        }

        private string GetSerialNumber()
        {

            try
            {
                var searcher = new ManagementObjectSearcher("SELECT SerialNumber FROM Win32_BIOS");

                foreach (var obj in searcher.Get())
                {
                    return obj["SerialNumber"].ToString();
                }
            }
            catch { }

            return "UNKNOWN";
        }

        private bool ValidateInputs()
        {
            bool isValid = true;

            foreach (var entry in answerInputs)
            {
                var panel = entry.Value;

                var selected = panel.Children
                    .OfType<RadioButton>()
                    .FirstOrDefault(r => r.IsChecked == true);

                if (selected == null)
                {
                    panel.Background = Brushes.LightPink; // highlight error
                    isValid = false;
                }
                else
                {
                    panel.ClearValue(WrapPanel.BackgroundProperty);
                }

                /*if (string.IsNullOrWhiteSpace(input.Text))
                {
                    // Mark invalid
                    input.BorderBrush = Brushes.Red;
                    input.BorderThickness = new Thickness(2);

                    isValid = false;
                }
                else
                {
                    // Reset style
                    input.ClearValue(TextBox.BorderBrushProperty);
                    input.ClearValue(TextBox.BorderThicknessProperty);
                }
                */
            }

            return isValid;
        }

        private async void Submit_Click(object sender, RoutedEventArgs e)
        {
            if (isSubmitting)
                return; //  prevent multiple clicks

            // VALIDATION FIRST
            if (!ValidateInputs())
            {
                MessageBox.Show("Please answer the question before submitting.",
                                "Required",
                                MessageBoxButton.OK,
                                MessageBoxImage.Warning);
                return;
            }

            isSubmitting = true;
            SubmitButton.IsEnabled = false;
            SubmitButton.Content = "Submitting...";

            var answers = new List<object>();

            foreach (var q in questions)
            {
                var panel = answerInputs[q.id];

                var selected = panel.Children
                    .OfType<RadioButton>()
                    .FirstOrDefault(r => r.IsChecked == true);

                string selectedAnswer = selected?.Content?.ToString() ?? "";

                answers.Add(new
                {
                    question_id = q.id,
                    answer = selectedAnswer
                });
            }

            var payload = new
            {
                device_serial = GetSerialNumber(),
                username = Environment.UserName,
                answers = answers
            };

            var serializer = new JavaScriptSerializer();
            string json = serializer.Serialize(payload);

            var content = new StringContent(json, Encoding.UTF8, "application/json");

            await client.PostAsync(API_URL, content);

            // Prevent further interaction completely
            SubmitButton.Content = "Submitted ✓";

            //MessageBox.Show("Submitted Successfully!");

            allowClose = true;
            this.Close();
        }

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            if (!allowClose)
            {
                e.Cancel = true; // block closing
            }
        }

        protected override void OnDeactivated(EventArgs e)
        {
            base.OnDeactivated(e);
            if (!isAdminDialogOpen)
            {
                this.Topmost = true;
                this.Activate();
            }
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

        private void Window_KeyDown(object sender, KeyEventArgs e)
        {
            // Block normal exits
            if (e.Key == Key.Escape || (e.SystemKey == Key.F4))
            {
                e.Handled = true;
            }

            // ✅ ADMIN OVERRIDE
            if ((Keyboard.Modifiers == (ModifierKeys.Control | ModifierKeys.Shift))
                && e.Key == Key.A)
            {
                isAdminDialogOpen = true;
                this.Topmost = false; // Allow interaction with password box

                var dialog = new AdminPasswordWindow
                {
                    Owner = this
                };

                bool? result = dialog.ShowDialog();

                isAdminDialogOpen = false;
                this.Topmost = true; // Re-enable topmost after input
                this.Activate(); // Bring window back to front

                if (result == true && dialog.IsAuthenticated)
                {
                    allowClose = true;
                    Application.Current.Shutdown();
                }
            }
        }

        private void Grid_MouseDown(object sender, MouseButtonEventArgs e)
        {
            this.Activate(); // Bring window to front if user clicks on it
        }
    }
}

public class Question
{
    public string id { get; set; }
    public string question { get; set; }
}
