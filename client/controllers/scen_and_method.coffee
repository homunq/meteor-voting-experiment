global = @
if (Handlebars?.registerHelper?) 

  Handlebars.registerHelper 'meth_subtemplate', (sub, data) ->
    m = Session.get('method')
    if m
      template =  Template["#{ METHOD?.name }_#{ sub }"]
      debug "meth_subtemplate", "#{ METHOD?.name }_#{ sub }"
      if template
        return new Handlebars.SafeString template(data)
    new Handlebars.SafeString "<!--method name-->"
      
  Handlebars.registerHelper 'methName', ->
    debug "methName", (Session.get 'method')
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
    debug "candNames", scen?.candNames
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
    
  scenCandInfo = ->
    scenario = ((Session.get 'scenario') and SCENARIO)
    if scenario
      result = scenario.candInfos Session.get 'faction'
    debug "scenCandInfo", Session.get 'faction', (((Session.get 'scenario') and SCENARIO)), result
    result
    
  Handlebars.registerHelper 'scenCandInfo', scenCandInfo
  
  Handlebars.registerHelper 'ballotCandInfo', ->
    candInfo = scenCandInfo()
    processCandInfo = Methods[ELECTION?.method]?.processCandInfo
    if processCandInfo
      return processCandInfo candInfo
    candInfo
  
    
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
    
  Handlebars.registerHelper 'legalScores', ->
    Methods.score.scores.slice().reverse()
    
  Handlebars.registerHelper 'SODAvote', (num) ->
    result = ->
      vote = Session.get('vote') or []
      if not vote[num]
        return Template.SODA_neither()
      if (_.reduce vote, ((a,b)->a+b),0) is 1
        return Template.SODA_delegate()
      return Template.SODA_approve()
    new Handlebars.SafeString Spark.labelBranch ("SODAvote"+num), result
      
  
@carousel = ->
  Meteor.setTimeout (-> $(".carousel").carousel
    pause: "hover"
    interval: 10000
  ), 20000
