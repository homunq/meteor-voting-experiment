if (Handlebars?) 

  Handlebars.registerHelper 'meth_subtemplate', (sub, data) ->
    template =  Template["#{ ((Session.get 'method') and METHOD)?.name }_#{ sub }"]
    slog "meth_subtemplate", "#{ ((Session.get 'method') and METHOD)?.name }_#{ sub }"
    if template
      new Handlebars.SafeString template(data)
    else
      new Handlebars.SafeString "<!--#{ ((Session.get 'method') and METHOD)?.name }_#{ sub }-->"
      
  Handlebars.registerHelper 'methName', ->
    slog "methName", (Session.get 'method')
    return Methods[(Session.get 'method')]?.longName
    
  Handlebars.registerHelper 'gradeOf', (gmj) ->
    
    medianInt = Math.round((gmj * 0.99) + 0.02)
    leftover = gmj - medianInt
    grade = Methods.GMJ.grades[medianInt]
    if leftover is 0.5
      return grade + "++"
      #return "#{ Methods.GMJ.grades[medianInt + 1] }-/#{ Methods.GMJ.grades[medianInt] }+"
    if leftover is -0.5
      return grade + "--"
    if leftover > 0
      return grade + "+"
    if leftover < 0
      return grade + "-"
    return grade
     
      
  Handlebars.registerHelper 'scenarioName', ->
    e = (Session.get 'election') and ELECTION
    e.scenario
    
  Handlebars.registerHelper 'scen', ->
    scen = (Session.get 'scenario') and SCENARIO
    slog "candNames", scen.candNames
    if scen
      return scen
    {}
    
  Handlebars.registerHelper 'factions', ->
    ((Session.get 'scenario') and SCENARIO)?.factionsAttrs Meteor.user()?.faction
    
  Handlebars.registerHelper 'scenMyPayoffs', ->
    scenario = ((Session.get 'scenario') and SCENARIO)
    if scenario
      scenario.payoffsForFaction Session.get 'faction'
    
  Handlebars.registerHelper 'scenOtherPayoffs', ->
    scenario = ((Session.get 'scenario') and SCENARIO)
    if scenario
      scenario.payoffsExceptFaction Session.get 'faction'
    
  Handlebars.registerHelper 'scenCandInfo', ->
    scenario = ((Session.get 'scenario') and SCENARIO)
    if scenario
      result = scenario.candInfos Session.get 'faction'
    slog "scenCandInfo", Session.get 'faction', (((Session.get 'scenario') and SCENARIO)), result
    result
    
  Handlebars.registerHelper 'scenNumVoters', ->
    scenario = ((Session.get 'scenario') and SCENARIO)
    if scenario
      scenario.numVoters()
      
  Handlebars.registerHelper 'scenSlides', ->
    scenario = ((Session.get 'scenario') and SCENARIO)
    if scenario
      scenario.slides Session.get 'faction'
    
  Handlebars.registerHelper 'candRanks', ->
    scenario = ((Session.get 'scenario') and SCENARIO)
    if scenario
      numCands = scenario.numCands()
      for rank in [1..numCands]
        rank: rank
        ord: ''+ rank + (if rank <= 3 then ['st','nd','rd'][rank-1] else 'th')
    
  
@carousel = ->
  Meteor.setTimeout (-> $(".carousel").carousel
    pause: "hover"
    interval: 10000
  ), 0
