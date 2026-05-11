using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace SurveyApp
{
    public static class StateManager
    {
        private static readonly string Folder =
            Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "SurveyApp");

        private static readonly string FilePath =
            Path.Combine(Folder, "state.json");

        public static SurveyState Load()
        {
            try
            {
                if (!Directory.Exists(Folder))
                    Directory.CreateDirectory(Folder);

                if (!File.Exists(FilePath))
                {
                    return new SurveyState();
                }

                string json = File.ReadAllText(FilePath);

                var serializer = new JavaScriptSerializer();

                return serializer.Deserialize<SurveyState>(json);
            }
            catch
            {
                return new SurveyState();
            }
        }

        public static void Save(SurveyState state)
        {
            if (!Directory.Exists(Folder))
                Directory.CreateDirectory(Folder);

            var serializer = new JavaScriptSerializer();

            string json = serializer.Serialize(state);

            File.WriteAllText(FilePath, json);
        }
    }
}
