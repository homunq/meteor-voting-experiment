
if (Handlebars?) 
  Handlebars.registerHelper "eid", ->
    Meteor.user()?.eid
    
  Handlebars.registerHelper "election", ->
    Session.get 'election'
    
  Handlebars.registerHelper "user", ->
    Meteor.user()?._id
    
  Handlebars.registerHelper 'step', ->
    Session.get 'step'
    
  Handlebars.registerHelper 'method', ->
    (Session.get "method").name
    
  Handlebars.registerHelper 'meth_subtemplate', (sub) ->
    new Handlebars.SafeString Template["#{ (Session.get 'method').name }_#{ sub }"]()
    
  Handlebars.registerHelper 'dmeth_subtemplate', (sub) ->
    new Handlebars.SafeString "#{ (Session.get 'method').name }_#{ method }" + ': ' + Template["#{ (Session.get 'method').name }_#{ sub }"]()
    
  Handlebars.registerHelper 'meth_blurb', ->
    new Handlebars.SafeString Template["#{ (Session.get "method").name }_blurb"]()
    
  Handlebars.registerHelper 'meth_ballotLine', (candInfo) ->
    new Handlebars.SafeString Template["#{ (Session.get "method").name }_ballotLine"](candInfo)
    
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
    result = (Session.get 'scenario').candInfo Session.get 'faction'
    console.log "scenCandInfo", Session.get 'faction', (Session.get 'scenario'), result
    result
    
    
  Handlebars.registerHelper 'stage', ->
    console.log 'stage'
    return Session.get 'stage'
    
  Handlebars.registerHelper "steps", ->
    steps = []  
    thisStep = Session.get 'step'
    for step, stepNum in PROCESS.steps
      steps.push  Template.oneStep _(
        thisStep: stepNum == thisStep
      ).extend step
    new Handlebars.SafeString steps.join ""
    
  Handlebars.registerHelper 'stepPopover', (stepName) ->
    console.log stepName
    new Handlebars.SafeString Template["#{ stepName }_popover"]()
    
  Handlebars.registerHelper "stepExplanations", ->
    steps = []  
    for step, stepNum in PROCESS.steps
      steps.push  Template.oneStepExplanation step
        
    steps.push Template.oneStepExplanation
      num: "Total"
      blurb: "The total time will mostly depend on how quick the other turkers in the experiment are."
      suggestedMins: PROCESS.suggestedMins
      maxMins: PROCESS.maxMins - 60
    new Handlebars.SafeString steps.join ""
    
    
  Handlebars.registerHelper 'stepName', ->
    console.log 'stepName'
    step = Session.get "step"
    console.log step
    if step isnt undefined
      return PROCESS.steps[step].name
    "init"
    

  Handlebars.registerHelper 'mapImg', ->
    faction = Session.get 'faction'
    if faction?
      scenario = Session.get 'scenario'
      return scenario.factPngs[faction]
    'noFaction'

  Handlebars.registerHelper 'error', ->
    Session.get 'error'
      
