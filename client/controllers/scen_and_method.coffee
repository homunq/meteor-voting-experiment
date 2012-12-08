if (Handlebars?) 

  Handlebars.registerHelper 'meth_subtemplate', (sub, data) ->
    template =  Template["#{ (Session.get 'method')?.name }_#{ sub }"]
    console.log "meth_subtemplate", template, "#{ (Session.get 'method')?.name }_#{ sub }"
    if template
      new Handlebars.SafeString template(data)
    else
      new Handlebars.SafeString "<!--#{ (Session.get 'method')?.name }_#{ sub }-->"
      
  Handlebars.registerHelper 'gradeOf', (cmj) ->
    
    medianInt = Math.round((cmj * 0.99) + 0.02)
    leftover = cmj - medianInt
    grade = Methods.CMJ.grades[medianInt]
    if leftover is 0.5
      return grade + "++"
      #return "#{ Methods.CMJ.grades[medianInt + 1] }-/#{ Methods.CMJ.grades[medianInt] }+"
    if leftover is -0.5
      return grade + "--"
    if leftover > 0
      return grade + "+"
    if leftover < 0
      return grade + "-"
    return grade
     
      
  Handlebars.registerHelper 'scenarioName', ->
    e = Session.get 'election'
    e.scenario
    
  Handlebars.registerHelper 'scen', ->
    (Session.get 'scenario')
    
  Handlebars.registerHelper 'scenMyPayoffs', ->
    scenario = Session.get 'scenario'
    if scenario
      scenario.payoffsForFaction Session.get 'faction'
    
  Handlebars.registerHelper 'scenOtherPayoffs', ->
    scenario = Session.get 'scenario'
    if scenario
      scenario.payoffsExceptFaction Session.get 'faction'
    
  Handlebars.registerHelper 'scenCandInfo', ->
    scenario = Session.get 'scenario'
    if scenario
      result = scenario.candInfos Session.get 'faction'
    console.log "scenCandInfo", Session.get 'faction', (Session.get 'scenario'), result
    result
    
  Handlebars.registerHelper 'scenNumVoters', ->
    scenario = Session.get 'scenario'
    if scenario
      scenario.numVoters()
    
  Handlebars.registerHelper 'candRanks', ->
    scenario = Session.get 'scenario'
    if scenario
      numCands = scenario.numCands()
      for rank in [1..numCands]
        rank: rank
        ord: ''+ rank + (if rank <= 3 then ['st','nd','rd'][rank-1] else 'th')
    
  