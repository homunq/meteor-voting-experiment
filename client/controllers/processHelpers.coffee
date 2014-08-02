
@SCENARIO ?= undefined
@ELECTION ?= undefined

global = @

global.STEP_RECORD = undefined

Meteor.startup ->
  ##debug _.keys Meteor
  if Meteor.isClient
    Meteor.autosubscribe ->
      #setup STEP_RECORD
      if (Session.get 'router') and ROUTER?.current_page.get() is 'loggedIn'
        step = Session.get 'step'
        if step?
          if step != STEP_RECORD?.step
            #debug "New step"
            global.STEP_RECORD = new StepRecord()
            
            
          #Move on if needed
    Meteor.autosubscribe ->
      stage = Session.get 'stage'
      
      [step, lastStep] = (Session.get 'stepLastStep') or [0,-1]
      if (Session.get 'router') and ROUTER?.current_page.get() is 'loggedIn'
          #is again separate autosubscribe?
        if STEP_RECORD?
          debug "stepLastStep", step, lastStep, stage #, Elections.findOne({})
          if STEP_RECORD and PROCESS.shouldMoveOn(step, lastStep, stage)
            debug "so let's move on"
            playSound 'next'
            STEP_RECORD.moveOn(yes)
          if step is 0
            nextStep()
        else
          debug "not moving on; no STEP_RECORD"
      
@nextStep = ->
  beforeFinish = PROCESS.step(STEP_RECORD.step).beforeFinish
  debug "beforeFinish", beforeFinish
  if beforeFinish
    beforeFinish (error, result) ->
      #debug "beforeFinish done", error, result
      if !error
        #debug "NextStep"
        STEP_RECORD.finish()
      else
        debug "Error in process:", error
        Session.set 'error', error.details
  else
    #debug "NextStep direct"
    STEP_RECORD.finish()
    Session.set 'error', undefined
  
@SUBMITTING = false  
@amazonSubmit = ->
  
  getUser().serverSubmittable (err, valid) ->
    if valid
      Session.set 'legitCheck', valid
  if not SUBMITTING
    global.SUBMITTING = true
    Deps.autorun ->
      legitCheck = Session.get 'legitCheck'
      if legitCheck
        $('#legitCheck').val(legitCheck)
        $('#amazonSubmit').submit()
        window.location = $('#amazonSubmit').attr('action')
    
      

if (Handlebars?) 
  #a simple handlebars function that lets you render a page based a reactive var
  Handlebars.registerHelper 'renderWith', (name, text) ->
    if Template[name]
      new Handlebars.SafeString "<!--" + name + "-->" + Template[name]
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
    debug "getting winner"
    e = (Session.get 'election') and ELECTION
    if not e
      debug "No election for outcome!!!"
      return {}
    faction = Session.get 'faction'
    outcome = Outcomes.findOne
      election: e._id
      stage: e.stage - 1
    if not outcome
      debug "No outcome!!!"
      return {}
    debug "Outcome", outcome
    outcome = new Outcome outcome
    e.scen().candInfo outcome.winner, faction, outcome, e.scen()
    
  Handlebars.registerHelper 'tied', ->
    debug "getting tied"
    e = (Session.get 'election') and ELECTION
    if not e
      debug "No election for outcome!!!"
      return {}
    outcome = Outcomes.findOne
      election: e._id
      stage: e.stage - 1
    if not outcome
      debug "No outcome!!!"
      return {}
    return outcome.ties
    
  Handlebars.registerHelper 'userVoted', ->
    debug "getting userVoted"
    e = (Session.get 'election') and ELECTION
    if not e
      debug "No election for outcome!!!"
      return {}
    outcome = Outcomes.findOne
      election: e._id
      stage: e.stage - 1
    return Meteor.user()._id in (outcome?.voters or [])
    
  Handlebars.registerHelper 'losers', ->
    debug "getting losers"
    e = (Session.get 'election') and ELECTION
    if not e
      debug "No election for outcome!!!"
      return []
    faction = Session.get 'faction'
    outcome = Outcomes.findOne
      election: e._id
      stage: e.stage - 1
    if not outcome
      debug "No outcome!!!"
      return []
    outcome = new Outcome outcome
    debug "Outcome", outcome
    losers = _.range e.scen().numCands()
    losers.splice outcome.winner, 1
    for loser in losers
      e.scen().candInfo loser, faction, outcome, e.scen()
    
  Handlebars.registerHelper 'stepCompletedNum', (num) ->
    (Session.get 'stepCompletedNums')?[num] ? 0
    
    
  Handlebars.registerHelper 'stepIncompleteNum', ->
    completed = ((Session.get 'stepCompletedNums')?[Session.get('step')] ? 0)
    scenario = ((Session.get 'scenario') and SCENARIO)
    if scenario
      total = scenario.numVoters()
    else total = 999
    return total - completed
    
  Handlebars.registerHelper 'plural', (num, plural, singular) ->
    if num is 1
      return singular or ''
    else
      return ((_.isString plural) and plural) or 's'
    
    
  Handlebars.registerHelper 'stepWaiting', ->
    stepLastStep = (Session.get 'stepLastStep') or [0,-1]
    return (stepLastStep[0] is stepLastStep[1])
    
  Handlebars.registerHelper 'isLastStep', ->
    step = Session.get 'step'
    return (step >= PROCESS.steps.length - 2)
    
    
  Handlebars.registerHelper 'stage', ->
    debug 'stage'
    return Session.get 'stage'
    
  Handlebars.registerHelper 'nextStage', ->
    debug 'helper nextStage'
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
    debug stepName
    new Handlebars.SafeString Template["#{ stepName }_popover"]()
    
  Handlebars.registerHelper 'stepExplanations', ->
    steps = []  
    for step, stepNum in PROCESS.steps
      if not step.hide
        steps.push Spark.labelBranch ("stepExplanations" + stepNum), ->
          Template.oneStepExplanation step
        
    steps.push Spark.labelBranch ("stepExplanationsTotal"), ->
      Template.oneStepExplanation
        num: "Total"
        blurb: "The total time will mostly depend on how quick the other turkers in the experiment are. \
(15 minutes are allowed on step 2 for the experiment to fill, but that is usually much quicker.)"
        suggestedMins: PROCESS.suggestedMins
        maxMins: PROCESS.maxMins - 12
        payout: new Handlebars.SafeString Template.fullPay() #"{{baseRate}}-{{maxPay}}"
    new Handlebars.SafeString steps.join ""
    
    
  Handlebars.registerHelper 'stepName', ->
    debug 'stepName'
    step = Session.get 'step'
    debug step
    if step?
      return PROCESS.steps[step].name
    "init"
    

  Handlebars.registerHelper 'mapImg', ->
    faction = Session.get 'faction'
    if faction?
      scenario = (Session.get 'scenario') and SCENARIO
      return scenario?.factPngs[faction]
    'noFaction'

  Handlebars.registerHelper 'error', ->
    Session.get 'error'
    
  
  Handlebars.registerHelper 'hitPremature', ->
    step = Session.get 'step'
    if step? and not PROCESS.steps[step].hit
      user= Meteor.user()
      return user?.workerId
    false
    
  Handlebars.registerHelper 'hitLate', ->
    step = Session.get 'step'
    if step? and PROCESS.steps[step].hit
      user= Meteor.user()
      return not user?.workerId
    false
    
  Handlebars.registerHelper 'noRoomForMe', ->
    faction = Session.get 'faction'
    if faction?
      return false
    election = (Session.get 'election') and ELECTION
    ELECTION?.isFull()
    
  Handlebars.registerHelper 'currentPageIsnt', (page) ->
    currentPage = ROUTER.current_page.get()
    currentPage isnt page
    
