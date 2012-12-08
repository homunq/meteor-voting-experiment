
if (Handlebars?) 

  Handlebars.registerHelper 'meth_subtemplate', (sub) ->
    new Handlebars.SafeString Template["#{ (Session.get 'method')?.name }_#{ sub }"]()
    
  Handlebars.registerHelper 'dmeth_subtemplate', (sub) ->
    new Handlebars.SafeString "#{ (Session.get 'method')?.name }_#{ method }" + ': ' + Template["#{ (Session.get 'method').name }_#{ sub }"]()
    
  Handlebars.registerHelper 'meth_blurb', ->
    new Handlebars.SafeString Template["#{ (Session.get "method")?.name }_blurb"]()
    
  Handlebars.registerHelper 'meth_ballotLine', (candInfos) ->
    new Handlebars.SafeString Template["#{ (Session.get "method")?.name }_ballotLine"](candInfos)
    
  Handlebars.registerHelper 'meth_resultHead', ->
    new Handlebars.SafeString Template["#{ (Session.get "method")?.name }_resultHead"]()
    
  Handlebars.registerHelper 'meth_resultLine', (candResult) ->
    new Handlebars.SafeString Template["#{ (Session.get "method")?.name }_resultLine"](candResult)
    
  Handlebars.registerHelper 'scenarioName', ->
    e = Session.get 'election'
    e.scenario
    
  Handlebars.registerHelper 'scen', ->
    (Session.get 'scenario')
    
  Handlebars.registerHelper 'scenMyPayoffs', ->
    (Session.get 'scenario').payoffsForFaction Session.get 'faction'
    
  Handlebars.registerHelper 'scenOtherPayoffs', ->
    (Session.get 'scenario').payoffsExceptFaction Session.get 'faction'
    
  Handlebars.registerHelper 'scenCandInfo', ->
    result = (Session.get 'scenario').candInfos Session.get 'faction'
    console.log "scenCandInfo", Session.get 'faction', (Session.get 'scenario'), result
    result
    
  Handlebars.registerHelper 'scenNumVoters', ->
    (Session.get 'scenario').numVoters()
    
  