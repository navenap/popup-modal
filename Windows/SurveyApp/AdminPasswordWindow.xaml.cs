using System.Windows;
using System.Windows.Controls;

namespace SurveyApp
{
    /// <summary>
    /// Interaction logic for AdminPasswordWindow.xaml
    /// </summary>
    public partial class AdminPasswordWindow : Window
    {
        public bool IsAuthenticated { get; private set; } = false;

        public AdminPasswordWindow()
        {
            InitializeComponent();
            PasswordBox.Focus();
        }

        private void ShowPassword_Checked(object sender, RoutedEventArgs e)
        {
            VisibleText.Text = PasswordBox.Password;
            VisibleText.Visibility = Visibility.Visible;
            PasswordBox.Visibility = Visibility.Collapsed;
        }

        private void ShowPassword_Unchecked(object sender, RoutedEventArgs e)
        {
            PasswordBox.Password = VisibleText.Text;
            PasswordBox.Visibility = Visibility.Visible;
            VisibleText.Visibility = Visibility.Collapsed;
        }

        private void Submit_Click(object sender, RoutedEventArgs e)
        {
            string password = PasswordBox.Visibility == Visibility.Visible
                ? PasswordBox.Password
                : VisibleText.Text;

            if (password == "_+inTERnal") // change this!
            {
                IsAuthenticated = true;
                DialogResult = true;
            }
            else
            {
                MessageBox.Show("Invalid password");
            }
        }
    }
}
