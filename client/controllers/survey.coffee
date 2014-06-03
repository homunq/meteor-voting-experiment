
            
if (Handlebars?.registerHelper?) 
  #a simple handlebars function that lets you render a page based a reactive var
  Handlebars.registerHelper 'question', (question) ->
    question.getHtml()
      
  Handlebars.registerHelper 'surveyQuestions', ->
    setupSurvey()
    _.values(question)[0] for question in SURVEY.questions