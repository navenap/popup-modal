using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SurveyApp
{
    public class SurveyState
    {
        public bool SurveyCompleted { get; set; }
        public string LastAnsweredDate { get; set; }
        public bool AnsweredToday { get; set; }
    }
}
