
            
if (Handlebars?) 
  #a simple handlebars function that lets you render a page based a reactive var
  Handlebars.registerHelper 'question', (question) ->
    question.getHtml()
      