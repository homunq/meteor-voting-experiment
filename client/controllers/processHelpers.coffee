
            
@STEP_RECORD = undefined

Meteor.startup ->
  ##console.log _.keys Meteor
  if Meteor.is_client
    Meteor.autosubscribe ->
      step = Session.get "step"
      if step? and step != STEP_RECORD?.step
        #console.log "New step"
        window.STEP_RECORD = new StepRecord()
      else
        console.log "not making STEP_RECORD", step, STEP_RECORD

    Meteor.autosubscribe ->
      user = Meteor.user()
      step = user?.step
      stage = Session.get "stage"
      lastStep = user?.lastStep
      if STEP_RECORD and ((step < PROCESS.firstForStages[stage]) or (lastStep is step and PROCESS.step(step).stage < stage))
        playSound "next"
        STEP_RECORD.moveOn(yes)
      
nextStep = ->
  beforeFinish = PROCESS.step(STEP_RECORD.step).beforeFinish
  #console.log "beforeFinish", beforeFinish
  if beforeFinish
    beforeFinish (error, result) ->
      #console.log "beforeFinish done", error, result
      if !error
        #console.log "NextStep"
        STEP_RECORD.finish()
      else
        #console.log error
        Session.set "error", error.reason
  else
    #console.log "NextStep direct"
    STEP_RECORD.finish()

if (Handlebars?) 
  #a simple handlebars function that lets you render a page based a reactive var
  Handlebars.registerHelper 'renderWith', (name, text) ->
    if Template[name]
      new Handlebars.SafeString Template[name]
        text: text
    else
      new Handlebars.SafeString "<!--missing #{ name } template-->"
      
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
    
  Handlebars.registerHelper 'winner', ->
    e = Session.get 'election'
    faction = Session.get 'faction'
    outcome = new Outcome Outcomes.findOne
      _id: e.outcomes[e.stage - 1]
    e.scen().candInfo outcome.winner, faction, outcome.counts[outcome.winner]
    
  Handlebars.registerHelper 'losers', ->
    e = Session.get 'election'
    faction = Session.get 'faction'
    outcome = new Outcome Outcomes.findOne
      _id: e.outcomes[e.stage - 1]
    losers = _.range e.scen().numCands()
    losers.splice outcome.winner, 1
    ((e.scen().candInfo loser, faction, outcome.counts[loser]) for loser in losers)
    
  Handlebars.registerHelper 'stepCompletedNum', ->
    Session.get 'stepCompletedNum'
    
  Handlebars.registerHelper 'stepWaiting', ->
    step = Session.get "step"
    lastStep = Session.get "lastStep"
    return (step is lastStep)
    
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
    
  Handlebars.registerHelper 'surveyQuestions', ->
    setupSurvey()
    _.values(question)[0] for question in SURVEY.questions
    
  Handlebars.registerHelper 'stage', ->
    console.log 'stage'
    return Session.get 'stage'
    
  Handlebars.registerHelper 'nextStage', ->
    console.log 'helper nextStage'
    return (Session.get 'stage') + 1
    
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
      
