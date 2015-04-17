# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :project do
    title "Factory proj"
    github_site "https://github.com/callmemc/altbreaks"
    application_site "http://publicservice.berkeley.edu/alternativebreaks"
    short_description "short description"
    long_description "We want an interactive map to show all the trips, so that if you hover over a trip location, a pop-up is displayed with the trip information. We also want trip pages. And we want an internal forum where people from trips can communicate with each other and with people from other trips."
    problem "Solve communication issues internally within and between different break groups, as well as externally in creating a beautiful site that will increase our reputation and attract more applicants."
    client { FactoryGirl.create(:client) }
    organizations { [FactoryGirl.create(:organization)] }
    questions { {'question_1' => true, 'question_2' => true, 'question_3' => true} }
    project_type "Design"
    sector "Technology"
    approved nil
  end
end
