
            
@STEP_RECORD = undefined

Meteor.startup ->
  ##console.log _.keys Meteor
  if Meteor.isClient
    Meteor.autosubscribe ->
      if (Session.get 'router') and router?.current_page() is 'loggedIn'
        step = Session.get 'step'
        if step? and step != STEP_RECORD?.step
          #console.log "New step"
          window.STEP_RECORD = new StepRecord()
        else
          console.log "not making STEP_RECORD", step, STEP_RECORD

    Meteor.autosubscribe ->
      if (Session.get 'router') and router?.current_page() is 'loggedIn'
        stage = Session.get 'stage'
        [step, lastStep] = (Session.get 'stepLastStep') or [0,0]
        console.log "stepLastStep", step, lastStep, stage
        if STEP_RECORD and PROCESS.shouldMoveOn(step, lastStep, stage)
          playSound 'next'
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
        Session.set 'error', error.reason
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
      
  Handlebars.registerHelper 'eid', ->
    Meteor.user()?.eid
    
  Handlebars.registerHelper 'election', ->
    (Session.get 'election') and ELECTION 
    
  Handlebars.registerHelper 'user', ->
    Meteor.user() or {}
    
  Handlebars.registerHelper 'step', ->
    Session.get 'step'
    
  Handlebars.registerHelper 'method', ->
    (Session.get 'method')
    METHOD.name
    
  Handlebars.registerHelper 'winner', ->
    e = (Session.get 'election') and ELECTION
    faction = Session.get 'faction'
    outcome = new Outcome Outcomes.findOne
      _id: e.outcomes[e.stage - 1]
    e.scen().candInfo outcome.winner, faction, outcome.counts, e.scen(), outcome.factionCounts
    
  Handlebars.registerHelper 'losers', ->
    e = (Session.get 'election') and ELECTION
    faction = Session.get 'faction'
    outcome = new Outcome Outcomes.findOne
      _id: e.outcomes[e.stage - 1]
    losers = _.range e.scen().numCands()
    losers.splice outcome.winner, 1
    for loser in losers
      e.scen().candInfo loser, faction, outcome.counts, e.scen(), outcome.factionCounts
    
  Handlebars.registerHelper 'stepCompletedNum', (num) ->
    (Session.get 'stepCompletedNums')?[num] ? 0
    
  Handlebars.registerHelper 'stepWaiting', ->
    stepLastStep = Session.get 'stepLastStep'
    return (stepLastStep[0] is stepLastStep[1])
    
  Handlebars.registerHelper 'isLastStep', ->
    step = Session.get 'step'
    return (step >= PROCESS.steps.length - 2)
    
  Handlebars.registerHelper 'surveyQuestions', ->
    setupSurvey()
    _.values(question)[0] for question in SURVEY.questions
    
  Handlebars.registerHelper 'stage', ->
    console.log 'stage'
    return Session.get 'stage'
    
  Handlebars.registerHelper 'nextStage', ->
    console.log 'helper nextStage'
    return (Session.get 'stage') + 1
    
  Handlebars.registerHelper 'steps', (subTemplate) ->
    steps = []  
    thisStep = Session.get 'step'
    for step, stepNum in PROCESS.steps
      if not step.hide
        steps.push  Spark.labelBranch (subTemplate + stepNum), ->
          Template[subTemplate] _(step).extend
            thisStep: stepNum == thisStep
    new Handlebars.SafeString steps.join ""
    
  Handlebars.registerHelper 'stepPopover', (stepName) ->
    console.log stepName
    new Handlebars.SafeString Template["#{ stepName }_popover"]()
    
  Handlebars.registerHelper 'stepExplanations', ->
    steps = []  
    for step, stepNum in PROCESS.steps
      if not step.hide
        steps.push  Template.oneStepExplanation step
        
    steps.push Template.oneStepExplanation
      num: "Total"
      blurb: "The total time will mostly depend on how quick the other turkers in the experiment are."
      suggestedMins: PROCESS.suggestedMins
      maxMins: PROCESS.maxMins - 60
      payout: "$1.00-$3.16"
    new Handlebars.SafeString steps.join ""
    
    
  Handlebars.registerHelper 'stepName', ->
    console.log 'stepName'
    step = Session.get 'step'
    console.log step
    if step isnt undefined
      return PROCESS.steps[step].name
    "init"
    

  Handlebars.registerHelper 'mapImg', ->
    faction = Session.get 'faction'
    if faction?
      scenario = (Session.get 'scenario') and SCENARIO
      return scenario.factPngs[faction]
    'noFaction'

  Handlebars.registerHelper 'error', ->
    Session.get 'error'
    
  
  Handlebars.registerHelper 'hitPremature', ->
    step = Session.get 'step'
    if step? and not PROCESS.steps[step].hit
      user= Meteor.user()
      return user.workerId
    false
    
  Handlebars.registerHelper 'hitLate', ->
    step = Session.get 'step'
    if step? and PROCESS.steps[step].hit
      user= Meteor.user()
      return not user.workerId
    false
    
  Handlebars.registerHelper 'noRoomForMe', ->
    faction = Session.get 'faction'
    if faction?
      return false
    election = (Session.get 'election') and ELECTION
    ELECTION?.isFull()