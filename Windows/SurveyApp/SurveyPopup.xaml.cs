using System;
using System.Collections.Generic;
using System.Linq;
using System.Management;
using System.Net.Http;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using static SurveyApp.MainWindow;

namespace SurveyApp
{
    /// <summary>
    /// Interaction logic for SurveyPopup.xaml
    /// </summary>
    public partial class SurveyPopup : Window
    {
        private string API_URL = "https://script.google.com/macros/s/AKfycbxGbw1wuKIZ4cTyZMg45T5htLrvdnUQhIMdpYqbQkJilNivRrVEomDt8OUqsqRAA1j2sQ/exec";

        private static HttpClient client = CreateHttpClient();
        private static HttpClient CreateHttpClient()
        {
            return new HttpClient
            {
                Timeout = TimeSpan.FromSeconds(15)
            };
        }

        List<Question> questions = new List<Question>();

        Dictionary<string, WrapPanel> answerInputs =
            new Dictionary<string, WrapPanel>();

        private bool isSubmitting = false;

        private bool isAdminDialogOpen = false;
        private bool allowClose = false;
        public SurveyPopup()
        {
            InitializeComponent();

            this.Left = 0;
            this.Top = 0;

            this.Width = SystemParameters.VirtualScreenWidth;

            this.Height = SystemParameters.VirtualScreenHeight;

            this.WindowStartupLocation = WindowStartupLocation.Manual;

            this.WindowState = WindowState.Normal;

            this.WindowStyle = WindowStyle.None;

            this.ResizeMode = ResizeMode.NoResize;

            this.Topmost = true;

            this.ShowInTaskbar = false;

            this.Loaded += SurveyPopup_Loaded;
        }

        public static void ResetHttpClient()
        {
            client?.Dispose();

            client = CreateHttpClient();
        }

        private async void SurveyPopup_Loaded(object sender, RoutedEventArgs e)
        {
            var windowHelper = new WindowInteropHelper(this);

            AccentPolicy accent = new AccentPolicy();
            accent.AccentState = 3;

            int size = Marshal.SizeOf(accent);

            IntPtr ptr = Marshal.AllocHGlobal(size);

            Marshal.StructureToPtr(accent, ptr, false);

            WindowCompositionAttributeData data =
                new WindowCompositionAttributeData();

            data.Attribute = 19;
            data.SizeOfData = size;
            data.Data = ptr;

            SetWindowCompositionAttribute(windowHelper.Handle, ref data);

            Marshal.FreeHGlobal(ptr);

            await LoadQuestions();
        }

        async Task LoadQuestions()
        {
            ResetHttpClient();
            //MessageBox.Show("LoadQuestions started");

            SubmitButton.Content = "Submit";
            SubmitButton.IsEnabled = true;

            QuestionsPanel.Children.Clear();

            answerInputs.Clear();

            isSubmitting = false;

            try
            {
                LoadingText.Visibility = Visibility.Visible;
                MainModal.Visibility = Visibility.Collapsed;

                string serial = GetSerialNumber();

                var state = StateManager.Load();

                string url =
                    $"{API_URL}" +
                    $"?device_serial={Uri.EscapeDataString(serial)}";

                var response = await client.GetStringAsync(url);
                //MessageBox.Show(response);
                //MessageBox.Show("Questions count: " + questions.Count);

                if (response.Contains("\"status\":\"error\""))
                {
                    this.Hide();
                    return;
                }

                var serializer = new JavaScriptSerializer();

                // ✅ THIS IS THE CORRECT LINE (deserialize)
                questions = serializer.Deserialize<List<Question>>(response);

                if (questions == null)
                {
                    questions = new List<Question>();
                }

                if (questions == null || questions.Count == 0)
                {
                    state.SurveyCompleted = true;

                    StateManager.Save(state);
                    allowClose = true;

                    this.Close();

                    return;
                }

                var q = questions.First();
                string type = q.type ?? "";

                var options = q.options ?? new List<string>();

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

                foreach (var option in options)
                {
                    var rb = new RadioButton
                    {
                        Content = option,
                        GroupName = q.id,
                        Margin = new Thickness(5),
                        Padding = new Thickness(10, 6, 10, 6),
                        FontSize = 14,
                        Cursor = Cursors.Hand
                    };

                    // Style like Selectable buttons
                    rb.Style = (Style)FindResource("RadioButtonCardStyle");

                    // DYNAMIC QUESTION TYPE UI
                    if (type == "scale_10")
                    {
                        rb.Width = 42;
                        rb.Height = 42;
                        rb.FontSize = 13;
                    }
                    else if (type == "agree_4")
                    {
                        rb.MinWidth = 140;
                        rb.Height = 40;
                        rb.FontSize = 14;
                    }
                    else
                    {
                        rb.MinWidth = 100;
                        rb.Height = 40;
                        rb.FontSize = 14;
                    }

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

                LoadingText.Visibility = Visibility.Collapsed;
                MainModal.Visibility = Visibility.Visible;
                SubmitButton.Visibility = Visibility.Visible;
                SubmitButton.IsEnabled = true;

            }
            catch (Exception ex)
            {
                MessageBox.Show("Error loading questions: " + ex.Message);

                // Fail-safe (don’t lock user)
                this.Close();
            }
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
            ResetHttpClient();
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

            try
            {
                var answers = new List<object>();

                if (questions == null || questions.Count == 0)
                {
                    MessageBox.Show("No questions loaded.");
                    return;
                }

                var q = questions.First();

                if (!answerInputs.ContainsKey(q.id))
                {
                    MessageBox.Show("Question input missing.");

                    SubmitButton.IsEnabled = true;
                    SubmitButton.Content = "Submit";

                    isSubmitting = false;

                    return;
                }

                var panel = answerInputs[q.id];

                var selected = panel.Children
                    .OfType<RadioButton>()
                    .FirstOrDefault(r => r.IsChecked == true);

                string selectedAnswer =
                    selected?.Content?.ToString() ?? "";

                answers.Add(new
                {
                    question_id = q.id,
                    answer = selectedAnswer
                });

                var payload = new
                {
                    device_serial = GetSerialNumber(),
                    username = Environment.UserName,
                    answers = answers
                };

                var serializer = new JavaScriptSerializer();

                string json = serializer.Serialize(payload);

                var content = new StringContent(
                    json,
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await client.PostAsync(API_URL, content);

                string responseText =
                    await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                {
                    MessageBox.Show(
                        "Server Error: " + responseText
                    );

                    SubmitButton.IsEnabled = true;

                    SubmitButton.Content = "Submit";

                    isSubmitting = false;

                    return;
                }

                var state = StateManager.Load();

                state.LastAnsweredDate =
                    DateTime.Now.ToString("yyyy-MM-dd");

                state.AnsweredToday = true;

                StateManager.Save(state);

                SubmitButton.Content = "Submitted ✓";

                allowClose = true;

                this.Close();
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Submit failed:\n\n" + ex.Message
                );

                SubmitButton.IsEnabled = true;

                SubmitButton.Content = "Submit";

                isSubmitting = false;
            }
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

        protected override void OnDeactivated(EventArgs e)
        {
            base.OnDeactivated(e);
            if (!isAdminDialogOpen)
            {
                this.Topmost = true;
                this.Activate();
            }
        }

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

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            if (!allowClose)
            {
                e.Cancel = true;
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
    public string type { get; set; }
    public List<string> options { get; set; }
}
