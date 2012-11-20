
if (Handlebars?) 
  Handlebars.registerHelper "eid", ->
    Meteor.user()?.eid
    
  Handlebars.registerHelper "election", ->
    Session.get 'election'
    
  Handlebars.registerHelper "user", ->
    Meteor.user()?._id
    
  Handlebars.registerHelper 'rounder', ->
    e = Session.get 'election'
    if e?.round is 0
      return 'signup'
    else if e?.round > 0
      return 'election'
    'handshake'
    
  Handlebars.registerHelper 'round', ->
    e = Session.get 'election'
    e?.round
    
  Handlebars.registerHelper 'method', ->
    e = Session.get 'election'
    e?.method
    
  Handlebars.registerHelper 'meth_subtemplate', (sub) ->
    e = Session.get 'election'
    new Handlebars.SafeString Template["#{ e?.method }_#{ sub }"]()
    
  Handlebars.registerHelper 'dmeth_subtemplate', (sub) ->
    e = Session.get 'election'
    new Handlebars.SafeString '#{ e?.method }_#{ sub }' + ': ' + Template["#{ e?.method }_#{ sub }"]()
    
  Handlebars.registerHelper 'scenarioName', ->
    e = Session.get 'election'
    e.scenario
    
  Handlebars.registerHelper 'scen', ->
    e = Session.get 'election'
    e.scen()
    
  Handlebars.registerHelper 'scenMyPayoffs', ->
    e = Session.get 'election'
    e.scen().payoffsForFaction Meteor.user()?.faction
    
  Handlebars.registerHelper 'scenOtherPayoffs', ->
    e = Session.get 'election'
    e.scen().payoffsExceptFaction Meteor.user()?.faction
    
    
  Handlebars.registerHelper 'stage', ->
    console.log 'stage'
    e = Session.get 'election'
    if e?.round?
      steps = Meteor.user().steps
      if steps?.length >= e.round
        return steps[e.round]
    "init"
    
  Handlebars.registerHelper "steps", ->
    steps = []  
    thisStep = Meteor.user().step
    for step, stepNum in PROCESS.steps
      steps.push  Template.oneStep _(
        thisStep: stepNum == thisStep
      ).extend step
    new Handlebars.SafeString steps.join ""
    
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
    step = Meteor.user()?.step
    console.log step
    if step isnt undefined
      return PROCESS.steps[step].name
    "init"
    

  Handlebars.registerHelper 'mapImg', ->
    faction = Meteor.user()?.faction
    election = Session.get 'election'
    if faction?
      return election.scen().factPngs[faction]
    'noFaction'

      
